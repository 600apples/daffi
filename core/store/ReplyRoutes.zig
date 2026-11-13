const std = @import("std");
const Allocator = std.mem.Allocator;
const misc = @import("../misc.zig");
const Mutex = misc.Mutex;

/// Routes older than this are dropped by `sweep`.  A caller may wait forever
/// for its reply, so `add` sweeps only under pressure: once the map holds
/// `sweep_threshold` routes, or a responder has run out of ids.
pub var max_route_age_ms: i64 = 10 * 60 * 1000;
pub var sweep_threshold: usize = 1 << 16;
const sweep_interval_ms: i64 = 30 * 1000;

/// Where the reply to each outstanding request must go.
///
/// A request gets an id of this node's own when it arrives, and carries that
/// id instead of its sender's uuid from then on; the reply carries it back.
/// Two requests in flight can then never be confused, whatever their
/// senders' names and uuids: e.g. one from a peer whose connection was taken
/// over by a reconnect under the same name, whose counter starts again.
///
/// The reply is written to the connection the request came in on, with the
/// sender's uuid restored.  A Router keys ids by the peer it forwarded the
/// request to, and takes a reply only from that peer: nobody else can
/// answer in its place.
///
/// Both connections are retained while a route exists.
pub fn ReplyRoutes(comptime ConnT: type) type {
    return struct {
        map: Map = .empty,
        /// The routes each connection takes part in, so that dropping a
        /// connection does not scan the map.  A connection's set is kept
        /// (possibly empty) until `dropConnection`.
        by_conn: ByConn = .empty,
        /// Ids outstanding per responder (keyed by its address; 0 for this
        /// node), kept until `dropConnection` like `by_conn`.
        pending: Pending = .empty,
        allocator: Allocator,
        mutex: Mutex = .{},
        last_id: u16 = 0,
        last_sweep_ms: i64 = std.math.minInt(i64),

        const Self = @This();

        /// Outstanding requests beyond this many are refused: each one holds
        /// memory until its reply arrives or a peer disconnects.
        pub const max_routes: usize = 1 << 20;
        /// Ids tried per `add`: a responder that holds most of its ids must
        /// not make each new request probe all of them under the lock.
        const max_probes: u32 = 4096;

        const Key = struct {
            /// The peer the request was forwarded to; null when this node
            /// answers it itself (Service).
            responder: ?*ConnT,
            id: u16,
        };

        const Route = struct {
            requester: *ConnT,
            uuid: u16,
            created_ms: i64,
        };

        /// Where a reply goes, and the uuid it must carry there.  The caller
        /// owns a reference to `requester` and must `release` it.
        pub const Reply = struct {
            requester: *ConnT,
            uuid: u16,
        };

        const KeyContext = struct {
            pub fn hash(_: KeyContext, key: Key) u64 {
                var h = std.hash.Wyhash.init(key.id);
                const addr: usize = if (key.responder) |r| @intFromPtr(r) else 0;
                h.update(std.mem.asBytes(&addr));
                return h.final();
            }
            pub fn eql(_: KeyContext, a: Key, b: Key) bool {
                return a.id == b.id and a.responder == b.responder;
            }
        };

        const Map = std.HashMapUnmanaged(Key, Route, KeyContext, std.hash_map.default_max_load_percentage);
        const KeySet = std.HashMapUnmanaged(Key, void, KeyContext, std.hash_map.default_max_load_percentage);
        const ByConn = std.AutoHashMapUnmanaged(*ConnT, KeySet);
        const Pending = std.AutoHashMapUnmanaged(usize, u32);

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            var it = self.map.iterator();
            while (it.next()) |entry| freeEntry(entry.key_ptr.*, entry.value_ptr.*);
            self.map.deinit(self.allocator);
            var sets = self.by_conn.valueIterator();
            while (sets.next()) |set| set.deinit(self.allocator);
            self.by_conn.deinit(self.allocator);
            self.pending.deinit(self.allocator);
        }

        fn freeEntry(key: Key, route: Route) void {
            route.requester.release();
            if (key.responder) |r| r.release();
        }

        fn responderKey(responder: ?*ConnT) usize {
            return if (responder) |r| @intFromPtr(r) else 0;
        }

        /// Record a request that `requester` sent with `uuid`, to be answered
        /// by `responder` (null: by this node).  Returns the id the request
        /// carries from here on, never 0.  A responder whose connection is
        /// closing is refused with `error.ResponderGone`.
        pub fn add(self: *Self, requester: *ConnT, uuid: u16, responder: ?*ConnT) !u16 {
            self.mutex.lock();
            defer self.mutex.unlock();
            // `dropConnection` runs after the connection is marked closed, so
            // a route added past this check is still dropped with it.
            if (responder) |r| {
                if (r.isSuspended()) return error.ResponderGone;
            }
            const now = misc.monotonicMs();
            const rkey = responderKey(responder);
            var ids = self.pending.get(rkey) orelse 0;
            if ((self.map.count() >= sweep_threshold or ids >= std.math.maxInt(u16)) and now -| self.last_sweep_ms >= sweep_interval_ms) {
                self.last_sweep_ms = now;
                _ = self.sweepLocked(now);
                ids = self.pending.get(rkey) orelse 0;
            }
            if (self.map.count() >= max_routes) return error.TooManyPendingRequests;
            if (ids >= std.math.maxInt(u16)) return error.TooManyPendingRequests;

            var probes: u32 = 0;
            const id = while (probes < max_probes) : (probes += 1) {
                self.last_id +%= 1;
                if (self.last_id == 0) self.last_id = 1;
                if (!self.map.contains(.{ .responder = responder, .id = self.last_id })) break self.last_id;
            } else return error.TooManyPendingRequests;
            const key: Key = .{ .responder = responder, .id = id };

            try self.map.ensureUnusedCapacity(self.allocator, 1);
            const held = try self.pending.getOrPut(self.allocator, rkey);
            if (!held.found_existing) held.value_ptr.* = 0;
            try self.indexLocked(requester, key);
            errdefer self.unindexLocked(requester, key);
            if (responder) |r| {
                if (r != requester) try self.indexLocked(r, key);
            }
            self.pending.getPtr(rkey).?.* += 1;
            self.map.putAssumeCapacityNoClobber(key, .{ .requester = requester, .uuid = uuid, .created_ms = now });
            requester.retain();
            if (responder) |r| r.retain();
            return id;
        }

        fn indexLocked(self: *Self, conn: *ConnT, key: Key) !void {
            const gop = try self.by_conn.getOrPut(self.allocator, conn);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.put(self.allocator, key, {});
        }

        fn unindexLocked(self: *Self, conn: *ConnT, key: Key) void {
            const set = self.by_conn.getPtr(conn) orelse return;
            _ = set.remove(key);
        }

        /// Undo everything but the map entry and its references.
        fn forgetLocked(self: *Self, key: Key, route: Route) void {
            self.unindexLocked(route.requester, key);
            if (key.responder) |r| {
                if (r != route.requester) self.unindexLocked(r, key);
            }
            if (self.pending.getPtr(responderKey(key.responder))) |n| n.* -|= 1;
        }

        /// The route of the reply with `id` from `from` (null: from this
        /// node), which is then forgotten.  Null if there is none.
        pub fn take(self: *Self, from: ?*ConnT, id: u16) ?Reply {
            self.mutex.lock();
            defer self.mutex.unlock();
            const kv = self.map.fetchRemove(.{ .responder = from, .id = id }) orelse return null;
            self.forgetLocked(kv.key, kv.value);
            if (from) |r| r.release();
            // The requester's reference moves to the caller.
            return .{ .requester = kv.value.requester, .uuid = kv.value.uuid };
        }

        /// Forget the route with `id` from `from`, if any.
        pub fn remove(self: *Self, from: ?*ConnT, id: u16) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            const kv = self.map.fetchRemove(.{ .responder = from, .id = id }) orelse return;
            self.forgetLocked(kv.key, kv.value);
            freeEntry(kv.key, kv.value);
        }

        /// `conn` is gone: drop every route that starts or ends at it.  The
        /// caller marks `conn` closed first, so `add` refuses it from then on.
        pub fn dropConnection(self: *Self, conn: *ConnT) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            _ = self.pending.remove(@intFromPtr(conn));
            const entry = self.by_conn.fetchRemove(conn) orelse return;
            var set = entry.value;
            defer set.deinit(self.allocator);
            var it = set.keyIterator();
            while (it.next()) |key| {
                const kv = self.map.fetchRemove(key.*) orelse continue;
                const other = if (kv.value.requester == conn) key.responder else kv.value.requester;
                if (other) |o| {
                    if (o != conn) self.unindexLocked(o, key.*);
                }
                if (self.pending.getPtr(responderKey(key.responder))) |n| n.* -|= 1;
                freeEntry(kv.key, kv.value);
            }
        }

        /// Drop the routes created more than `max_route_age_ms` before
        /// `now_ms` (`misc.monotonicMs`); their callers have long given up.
        /// Returns how many were dropped.
        pub fn sweep(self: *Self, now_ms: i64) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.last_sweep_ms = now_ms;
            return self.sweepLocked(now_ms);
        }

        fn sweepLocked(self: *Self, now_ms: i64) usize {
            const cutoff = now_ms -| max_route_age_ms;
            var dropped: usize = 0;
            // The map must not change while it is iterated: collect a batch,
            // drop it, rescan.
            var batch: [256]Key = undefined;
            while (true) {
                var n: usize = 0;
                var it = self.map.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.created_ms >= cutoff) continue;
                    batch[n] = entry.key_ptr.*;
                    n += 1;
                    if (n == batch.len) break;
                }
                for (batch[0..n]) |key| {
                    const kv = self.map.fetchRemove(key).?;
                    self.forgetLocked(kv.key, kv.value);
                    freeEntry(kv.key, kv.value);
                }
                dropped += n;
                if (n < batch.len) return dropped;
            }
        }

        pub fn count(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.map.count();
        }
    };
}

const TestConn = struct {
    refs: usize = 1,
    suspended: bool = false,
    fn retain(self: *TestConn) void {
        self.refs += 1;
    }
    fn release(self: *TestConn) void {
        self.refs -= 1;
    }
    fn isSuspended(self: *const TestConn) bool {
        return self.suspended;
    }
};

test "ReplyRoutes tells apart requests that share a sender uuid" {
    var routes = ReplyRoutes(TestConn).init(std.testing.allocator);
    defer routes.deinit();
    var old: TestConn = .{};
    var new: TestConn = .{};

    // A reconnected peer reuses the uuid of its previous connection.
    const old_id = try routes.add(&old, 7, null);
    const new_id = try routes.add(&new, 7, null);
    try std.testing.expect(old_id != new_id);
    try std.testing.expectEqual(@as(usize, 2), old.refs);

    const reply = routes.take(null, new_id).?;
    defer reply.requester.release();
    try std.testing.expectEqual(&new, reply.requester);
    try std.testing.expectEqual(@as(u16, 7), reply.uuid);
    try std.testing.expectEqual(@as(?ReplyRoutes(TestConn).Reply, null), routes.take(null, new_id));
    try std.testing.expectEqual(@as(usize, 1), routes.count());
}

test "ReplyRoutes takes a forwarded reply only from the peer it went to" {
    var routes = ReplyRoutes(TestConn).init(std.testing.allocator);
    defer routes.deinit();
    var requester: TestConn = .{};
    var worker: TestConn = .{};
    var forger: TestConn = .{};

    const id = try routes.add(&requester, 1, &worker);
    try std.testing.expectEqual(@as(?ReplyRoutes(TestConn).Reply, null), routes.take(&forger, id));
    try std.testing.expectEqual(@as(?ReplyRoutes(TestConn).Reply, null), routes.take(null, id));
    const reply = routes.take(&worker, id).?;
    reply.requester.release();
    try std.testing.expectEqual(&requester, reply.requester);
    try std.testing.expectEqual(@as(usize, 1), worker.refs);
    try std.testing.expectEqual(@as(usize, 1), requester.refs);
}

test "ReplyRoutes never hands out 0 or an id still in use" {
    var routes = ReplyRoutes(TestConn).init(std.testing.allocator);
    defer routes.deinit();
    var a: TestConn = .{};

    const first = try routes.add(&a, 1, null);
    routes.last_id = std.math.maxInt(u16) - 1;
    try std.testing.expectEqual(std.math.maxInt(u16), try routes.add(&a, 2, null));
    // Wraps past 0, and past the id `first` still holds.
    const next = try routes.add(&a, 3, null);
    try std.testing.expect(next != 0 and next != first);
}

test "ReplyRoutes drops every route of a closed connection" {
    var routes = ReplyRoutes(TestConn).init(std.testing.allocator);
    defer routes.deinit();
    var a: TestConn = .{};
    var b: TestConn = .{};
    var worker: TestConn = .{};

    _ = try routes.add(&a, 1, &worker);
    _ = try routes.add(&a, 2, &worker);
    _ = try routes.add(&b, 1, &worker);
    const kept = try routes.add(&b, 2, null);
    routes.dropConnection(&worker);
    try std.testing.expectEqual(@as(usize, 1), routes.count());
    try std.testing.expectEqual(@as(usize, 1), worker.refs);
    try std.testing.expectEqual(@as(usize, 1), a.refs);
    routes.remove(null, kept);
    try std.testing.expectEqual(@as(usize, 1), b.refs);
    try std.testing.expectEqual(@as(usize, 0), routes.count());
    // The requester's index no longer names the dropped routes.
    routes.dropConnection(&a);
    routes.dropConnection(&b);
    try std.testing.expectEqual(@as(usize, 0), routes.by_conn.count());
}

test "ReplyRoutes refuses a responder whose connection is closing" {
    var routes = ReplyRoutes(TestConn).init(std.testing.allocator);
    defer routes.deinit();
    var requester: TestConn = .{};
    var worker: TestConn = .{};

    worker.suspended = true;
    routes.dropConnection(&worker);
    try std.testing.expectError(error.ResponderGone, routes.add(&requester, 1, &worker));
    try std.testing.expectEqual(@as(usize, 0), routes.count());
    try std.testing.expectEqual(@as(usize, 1), worker.refs);
    try std.testing.expectEqual(@as(usize, 1), requester.refs);
}

test "ReplyRoutes sweeps routes older than the maximum age" {
    var routes = ReplyRoutes(TestConn).init(std.testing.allocator);
    defer routes.deinit();
    var requester: TestConn = .{};
    var worker: TestConn = .{};

    for (0..600) |i| _ = try routes.add(&requester, @intCast(i + 1), &worker);
    const now = misc.monotonicMs();
    try std.testing.expectEqual(@as(usize, 0), routes.sweep(now));
    try std.testing.expectEqual(@as(usize, 600), routes.sweep(now + max_route_age_ms + 1));
    try std.testing.expectEqual(@as(usize, 0), routes.count());
    try std.testing.expectEqual(@as(usize, 1), worker.refs);
    try std.testing.expectEqual(@as(usize, 1), requester.refs);
    try std.testing.expectEqual(@as(u32, 0), routes.pending.get(@intFromPtr(&worker)).?);
}

test "ReplyRoutes refuses a responder with every id taken without probing" {
    var routes = ReplyRoutes(TestConn).init(std.heap.c_allocator);
    defer routes.deinit();
    var requester: TestConn = .{};
    var hung: TestConn = .{};
    var other: TestConn = .{};

    for (0..std.math.maxInt(u16)) |_| _ = try routes.add(&requester, 1, &hung);
    const last = routes.last_id;
    try std.testing.expectError(error.TooManyPendingRequests, routes.add(&requester, 1, &hung));
    try std.testing.expectEqual(last, routes.last_id);
    // Other responders are not affected.
    _ = try routes.add(&requester, 1, &other);

    // With most ids still held, an add gives up after a bounded probe.
    routes.remove(&hung, last);
    routes.last_id = last;
    try std.testing.expectError(error.TooManyPendingRequests, routes.add(&requester, 1, &hung));
    routes.dropConnection(&hung);
    try std.testing.expectEqual(@as(usize, 1), routes.count());
    try std.testing.expectEqual(@as(usize, 1), hung.refs);
}
