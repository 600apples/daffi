const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = @import("../misc.zig").Mutex;

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
        allocator: Allocator,
        mutex: Mutex = .{},
        last_id: u16 = 0,

        const Self = @This();

        /// Outstanding requests beyond this many are refused: each one holds
        /// memory until its reply arrives or a peer disconnects.
        pub const max_routes: usize = 1 << 20;

        const Key = struct {
            /// The peer the request was forwarded to; null when this node
            /// answers it itself (Service).
            responder: ?*ConnT,
            id: u16,
        };

        const Route = struct {
            requester: *ConnT,
            uuid: u16,
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

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            var it = self.map.iterator();
            while (it.next()) |entry| freeEntry(entry.key_ptr.*, entry.value_ptr.*);
            self.map.deinit(self.allocator);
        }

        fn freeEntry(key: Key, route: Route) void {
            route.requester.release();
            if (key.responder) |r| r.release();
        }

        /// Record a request that `requester` sent with `uuid`, to be answered
        /// by `responder` (null: by this node).  Returns the id the request
        /// carries from here on, never 0.
        pub fn add(self: *Self, requester: *ConnT, uuid: u16, responder: ?*ConnT) !u16 {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.map.count() >= max_routes) return error.TooManyPendingRequests;
            var tries: u32 = 0;
            while (tries < std.math.maxInt(u16)) : (tries += 1) {
                self.last_id +%= 1;
                if (self.last_id == 0) self.last_id = 1;
                const gop = try self.map.getOrPut(self.allocator, .{ .responder = responder, .id = self.last_id });
                if (gop.found_existing) continue;
                requester.retain();
                if (responder) |r| r.retain();
                gop.value_ptr.* = .{ .requester = requester, .uuid = uuid };
                return self.last_id;
            }
            return error.TooManyPendingRequests;
        }

        /// The route of the reply with `id` from `from` (null: from this
        /// node), which is then forgotten.  Null if there is none.
        pub fn take(self: *Self, from: ?*ConnT, id: u16) ?Reply {
            self.mutex.lock();
            defer self.mutex.unlock();
            const kv = self.map.fetchRemove(.{ .responder = from, .id = id }) orelse return null;
            if (from) |r| r.release();
            // The requester's reference moves to the caller.
            return .{ .requester = kv.value.requester, .uuid = kv.value.uuid };
        }

        /// Forget the route with `id` from `from`, if any.
        pub fn remove(self: *Self, from: ?*ConnT, id: u16) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            const kv = self.map.fetchRemove(.{ .responder = from, .id = id }) orelse return;
            freeEntry(kv.key, kv.value);
        }

        /// `conn` is gone: drop every route that starts or ends at it.
        pub fn dropConnection(self: *Self, conn: *ConnT) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            var doomed: std.ArrayList(Key) = .empty;
            defer doomed.deinit(self.allocator);
            var it = self.map.iterator();
            while (it.next()) |entry| {
                if (!involves(entry.key_ptr.*, entry.value_ptr.*, conn)) continue;
                doomed.append(self.allocator, entry.key_ptr.*) catch return self.dropOneByOne(conn);
            }
            for (doomed.items) |key| {
                const kv = self.map.fetchRemove(key).?;
                freeEntry(kv.key, kv.value);
            }
        }

        fn involves(key: Key, route: Route, conn: *ConnT) bool {
            return route.requester == conn or key.responder == conn;
        }

        /// `dropConnection` without memory to list the routes first.
        fn dropOneByOne(self: *Self, conn: *ConnT) void {
            while (true) {
                var it = self.map.iterator();
                const key = while (it.next()) |entry| {
                    if (involves(entry.key_ptr.*, entry.value_ptr.*, conn)) break entry.key_ptr.*;
                } else return;
                const kv = self.map.fetchRemove(key).?;
                freeEntry(kv.key, kv.value);
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
    fn retain(self: *TestConn) void {
        self.refs += 1;
    }
    fn release(self: *TestConn) void {
        self.refs -= 1;
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
}
