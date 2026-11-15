const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = @import("../misc.zig").Mutex;
const log = std.log.scoped(.store);

/// Whether generation `a` was issued before `b`.  Generations wrap at u16 and
/// are compared by distance; 0 (a peer that predates generations) is neither
/// older nor newer than anything.
pub fn generationOlder(a: u16, b: u16) bool {
    if (a == 0 or b == 0) return false;
    return @as(i16, @bitCast(a -% b)) < 0;
}

/// Maps peer names to the connection they are reachable through.
///
/// Every Channel holds one *reference* on its connection (`retain()` when the
/// channel is created or re-pointed, `release()` when it is removed).  Without
/// that, a reader thread finishing and destroying its connection left a
/// dangling `conn` pointer in the map that router threads would then write to.
///
/// A channel's method set is only ever replaced whole, under `mutex`
/// (`upsert`), so a reader holding `mutex` never sees one being rebuilt.
pub fn ChannelsMapper(comptime ConnectionT: type) type {
    return struct {
        channels: Channels,
        /// The names each connection serves, so a disconnect finds its
        /// channels without scanning all of them.
        by_conn: ByConn = .empty,
        allocator: Allocator,
        mutex: Mutex = .{},

        const Self = @This();

        // std.StringArrayHashMap removed in 0.16; use the unmanaged equivalent.
        pub const Channels = std.array_hash_map.String(Channel);
        const ByConn = std.AutoHashMapUnmanaged(*ConnectionT, std.ArrayList([]const u8));
        const Uuid = []const u8;

        pub const Channel = struct {
            conn: *ConnectionT,
            methods: *std.BufSet,
            connection_name: []const u8,
            /// The registration the router gave this name; 0 when unknown.
            generation: u16 = 0,
            /// Where `connection_name` sits in `by_conn.get(conn)`.
            conn_slot: usize = 0,

            pub fn containsMethod(self: *Channel, method_name: []const u8) bool {
                return self.methods.contains(method_name);
            }

            pub fn joinedMethods(self: *Channel, allocator: Allocator, sep: u8) ![]const u8 {
                var methods = std.array_list.Managed(u8).init(allocator);
                var iterator = self.methods.iterator();
                var count: usize = 0;
                while (iterator.next()) |key| : (count += 1) {
                    if (count != 0) try methods.append(sep);
                    try methods.appendSlice(key.*);
                }
                return try methods.toOwnedSlice();
            }
        };

        pub const Put = enum {
            created,
            /// The name moved to another connection.
            repointed,
            /// Same connection; methods (and generation) replaced.
            updated,
            /// The update carried an older generation than the channel's and
            /// was ignored.
            stale,
        };

        pub const Removal = enum { removed, missing, stale };

        /// A channel taken off a connection.  `name` is null when it could
        /// not be copied.
        pub const Removed = struct {
            name: ?[]const u8,
            generation: u16,
        };

        pub fn init(allocator: Allocator) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .channels = .{},
                .allocator = allocator,
            };
            return self;
        }

        /// Free all channels and the mapper itself.
        /// Must be called when the connection owning this mapper is torn down.
        /// No other thread must access this mapper concurrently after this call.
        pub fn deinit(self: *Self) void {
            self.freeAllLocked();
            self.allocator.destroy(self);
        }

        fn freeAllLocked(self: *Self) void {
            for (self.channels.values()) |*chan| {
                freeMethodSet(self.allocator, chan.methods);
                self.allocator.free(chan.connection_name);
                chan.conn.release();
            }
            self.channels.clearAndFree(self.allocator);
            var it = self.by_conn.valueIterator();
            while (it.next()) |names| names.deinit(self.allocator);
            self.by_conn.clearAndFree(self.allocator);
        }

        fn newMethodSet(allocator: Allocator, methods: ?[]const []const u8) !*std.BufSet {
            const set = try allocator.create(std.BufSet);
            set.* = std.BufSet.init(allocator);
            errdefer freeMethodSet(allocator, set);
            if (methods) |names| {
                for (names) |m| try set.insert(m);
            }
            return set;
        }

        fn freeMethodSet(allocator: Allocator, set: *std.BufSet) void {
            set.deinit();
            allocator.destroy(set);
        }

        pub fn ChannelsCount(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.channels.count();
        }

        /// Returns a live slice into the map's backing array without locking.
        /// Caller is responsible for ensuring no concurrent mutations occur while
        /// the slice is in use (typically by holding its own handler-level mutex).
        pub fn allChannels(self: *Self) []Channel {
            return self.channels.values();
        }

        pub fn getChannel(self: *Self, chan_uuid: Uuid) !Channel {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.channels.get(chan_uuid) orelse error.ChannelNotFound;
        }

        /// The connection serving `name`, for identity comparison only (no
        /// reference is taken).
        pub fn connOf(self: *Self, name: Uuid) ?*ConnectionT {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan = self.channels.getPtr(name) orelse return null;
            return chan.conn;
        }

        /// Look up *name* and return its connection with an extra reference
        /// held; the caller must `release()` it.  Use this instead of
        /// `getChannel(..).conn` whenever the connection is used after the map
        /// lock is dropped.
        pub fn retainConn(self: *Self, name: Uuid) !*ConnectionT {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan = self.channels.getPtr(name) orelse return error.ChannelNotFound;
            chan.conn.retain();
            return chan.conn;
        }

        /// Lock-protected ``contains`` query.  Used by the server-side
        /// handshake handlers to detect duplicate ``app_name`` registrations
        /// before mutating the map.
        pub fn hasChannel(self: *Self, chan_uuid: Uuid) bool {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.channels.contains(chan_uuid);
        }

        /// Look up *chan_uuid*, verify it exposes *method*, and return an owned
        /// duplicate of its connection_name.  Holding the mutex across both the
        /// lookup and the dupe is essential — the returned slice is propagated
        /// all the way up through the message pipeline (and into
        /// ``Py_BuildValue("s#")`` for CFFI), and freeing the Channel
        /// concurrently would otherwise yield a classic use-after-free
        /// (surfacing as a random UTF-8 decode error when the freed bytes get
        /// reused by another allocation before ``s#`` reads them).  Caller owns
        /// the returned slice and must free it with *dupe_allocator*.
        pub fn findReceiverDupe(
            self: *Self,
            dupe_allocator: Allocator,
            chan_uuid: Uuid,
            method: []const u8,
        ) ![]const u8 {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan = self.channels.getPtr(chan_uuid) orelse return error.ChannelNotFound;
            if (!chan.containsMethod(method)) return error.ChannelNotFound;
            return try dupe_allocator.dupe(u8, chan.connection_name);
        }

        /// Round-robin over the channels exposing `method` (except `skip`):
        /// the first one at or after `cursor.*`, else the first one at all.
        /// One pass; returns an owned copy of its name and moves `cursor`
        /// past it.
        pub fn findRoundRobinDupe(
            self: *Self,
            dupe_allocator: Allocator,
            method: []const u8,
            skip: []const u8,
            cursor: *usize,
        ) ![]const u8 {
            self.mutex.lock();
            defer self.mutex.unlock();
            const all = self.channels.values();
            var first: ?usize = null;
            const pick = for (all, 0..) |*c, i| {
                if (!c.containsMethod(method)) continue;
                if (std.mem.eql(u8, c.connection_name, skip)) continue;
                if (i >= cursor.*) break i;
                if (first == null) first = i;
            } else first orelse return error.ChannelNotFound;
            cursor.* = pick + 1;
            return try dupe_allocator.dupe(u8, all[pick].connection_name);
        }

        pub fn getOrCreateChannel(self: *Self, conn: *ConnectionT, chan_uuid: Uuid) !*Channel {
            self.mutex.lock();
            defer self.mutex.unlock();
            const result = try self.putLocked(conn, chan_uuid, null, null);
            return result.chan;
        }

        /// Register `name` on `conn` with exactly `methods`.  The new set is
        /// built before the lock is taken and swapped in under it.  A null
        /// `generation` keeps the channel's own; an older one than the
        /// channel's leaves the channel alone (`.stale`).
        pub fn upsert(self: *Self, conn: *ConnectionT, name: Uuid, methods: ?[]const []const u8, generation: ?u16) !Put {
            const set = try newMethodSet(self.allocator, methods);
            var replaced: ?*std.BufSet = null;
            defer if (replaced) |old| freeMethodSet(self.allocator, old);
            self.mutex.lock();
            defer self.mutex.unlock();
            if (generation) |g| {
                if (self.channels.getPtr(name)) |chan| {
                    if (generationOlder(g, chan.generation)) {
                        replaced = set;
                        return .stale;
                    }
                }
            }
            const result = self.putLocked(conn, name, set, generation) catch |err| {
                replaced = set;
                return err;
            };
            replaced = result.old_set;
            return result.put;
        }

        /// Record a newer generation for `name`, if it is registered.
        pub fn noteGeneration(self: *Self, name: Uuid, generation: u16) void {
            if (generation == 0) return;
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan = self.channels.getPtr(name) orelse return;
            if (chan.generation == 0 or generationOlder(chan.generation, generation)) chan.generation = generation;
        }

        const PutResult = struct {
            put: Put,
            chan: *Channel,
            old_set: ?*std.BufSet = null,
        };

        /// `set` null keeps an existing channel's methods (a new one gets an
        /// empty set).  On success the map owns `set`; on error the caller
        /// still does.
        fn putLocked(self: *Self, conn: *ConnectionT, name: Uuid, set: ?*std.BufSet, generation: ?u16) !PutResult {
            if (self.channels.getPtr(name)) |chan| {
                var result: PutResult = .{ .put = .updated, .chan = chan };
                if (chan.conn != conn) {
                    // It might be different if the client reconnected.
                    const slot = try self.linkLocked(conn, chan.connection_name);
                    self.unlinkLocked(chan.conn, chan.conn_slot);
                    conn.retain();
                    chan.conn.release();
                    chan.conn = conn;
                    chan.conn_slot = slot;
                    result.put = .repointed;
                }
                if (set) |s| {
                    result.old_set = chan.methods;
                    chan.methods = s;
                }
                if (generation) |g| chan.generation = g;
                log.debug("channel updated: {s}  total={d}", .{ name, self.channels.count() });
                return result;
            }
            const gop = try self.channels.getOrPut(self.allocator, name);
            const name_dup = self.allocator.dupe(u8, name) catch |err| {
                _ = self.channels.swapRemove(name);
                return err;
            };
            gop.key_ptr.* = name_dup;
            const methods = set orelse newMethodSet(self.allocator, null) catch |err| {
                _ = self.channels.swapRemove(name);
                self.allocator.free(name_dup);
                return err;
            };
            const slot = self.linkLocked(conn, name_dup) catch |err| {
                if (set == null) freeMethodSet(self.allocator, methods);
                _ = self.channels.swapRemove(name);
                self.allocator.free(name_dup);
                return err;
            };
            gop.value_ptr.* = .{ .conn = conn, .methods = methods, .connection_name = name_dup, .generation = generation orelse 0, .conn_slot = slot };
            conn.retain();
            log.debug("channel created: {s}  total={d}", .{ name, self.channels.count() });
            return .{ .put = .created, .chan = gop.value_ptr };
        }

        fn linkLocked(self: *Self, conn: *ConnectionT, name: []const u8) !usize {
            const gop = try self.by_conn.getOrPut(self.allocator, conn);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            gop.value_ptr.append(self.allocator, name) catch |err| {
                if (gop.value_ptr.items.len == 0) {
                    gop.value_ptr.deinit(self.allocator);
                    _ = self.by_conn.remove(conn);
                }
                return err;
            };
            return gop.value_ptr.items.len - 1;
        }

        fn unlinkLocked(self: *Self, conn: *ConnectionT, slot: usize) void {
            const names = self.by_conn.getPtr(conn) orelse return;
            if (slot >= names.items.len) return;
            _ = names.swapRemove(slot);
            if (slot < names.items.len) {
                if (self.channels.getPtr(names.items[slot])) |moved| moved.conn_slot = slot;
            }
            if (names.items.len == 0) {
                names.deinit(self.allocator);
                _ = self.by_conn.remove(conn);
            }
        }

        /// A channel served by `conn`.  Thread-safe; the pointer is only valid
        /// while no other thread mutates the map.
        pub fn getChannelByConnection(self: *Self, conn: *ConnectionT) ?*Channel {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.getChannelByConnectionLocked(conn);
        }

        fn getChannelByConnectionLocked(self: *Self, conn: *ConnectionT) ?*Channel {
            const names = self.by_conn.getPtr(conn) orelse return null;
            if (names.items.len == 0) return null;
            return self.channels.getPtr(names.items[names.items.len - 1]);
        }

        /// Remove one channel served by `conn`, returning a copy of its name
        /// (made with `name_allocator`) and its generation; null once `conn`
        /// serves none.
        pub fn removeOneByConnection(self: *Self, conn: *ConnectionT, name_allocator: Allocator) ?Removed {
            self.mutex.lock();
            defer self.mutex.unlock();
            const names = self.by_conn.getPtr(conn) orelse return null;
            const chan = self.channels.getPtr(names.items[names.items.len - 1]) orelse {
                log.err("connection index names a missing channel: {s}", .{names.items[names.items.len - 1]});
                self.unlinkLocked(conn, names.items.len - 1);
                return .{ .name = null, .generation = 0 };
            };
            const removed: Removed = .{ .name = name_allocator.dupe(u8, chan.connection_name) catch null, .generation = chan.generation };
            self.destroyChannelLocked(chan);
            return removed;
        }

        /// Remove a channel by its connection pointer, freeing all owned resources.
        pub fn destroyChannelByConnection(self: *Self, conn: *ConnectionT) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.getChannelByConnectionLocked(conn)) |chan| {
                self.destroyChannelLocked(chan);
            }
        }

        pub fn destroyChannel(self: *Self, chan: *Channel) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.destroyChannelLocked(chan);
        }

        /// Atomically find and remove the channel for *name*, returning its
        /// connection so the caller can close the underlying socket.
        /// Ownership of the channel's reference moves to the caller, who must
        /// `release()` the returned connection when finished with it.
        /// Returns null if no channel with that name exists.
        ///
        /// Used by ``onHandshake`` to evict a stale/zombie slot before
        /// registering a reconnecting peer (last-connection-wins semantics).
        /// The caller must close the returned connection AFTER releasing any
        /// handler-level mutex that the socket's reader thread may need when
        /// it wakes up and calls ``diconnectionHandler``.
        ///
        /// A channel that is already served by `keep` is left alone: a peer
        /// re-sending its handshake on the same connection (to advertise new
        /// callbacks) must not have its own socket closed under it.
        pub fn evictChannel(self: *Self, name: Uuid, keep: *ConnectionT) ?*ConnectionT {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan = self.channels.getPtr(name) orelse return null;
            const conn = chan.conn;
            if (conn == keep) return null;
            conn.retain(); // for the caller; the channel's own reference is dropped below
            self.destroyChannelLocked(chan);
            return conn;
        }

        /// Remove a channel by name (used when a "disconnected" event arrives).
        /// A `generation` older than the channel's means the event is about a
        /// registration that was since replaced: the channel stays.
        pub fn destroyChannelByName(self: *Self, name: []const u8, generation: u16) Removal {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan = self.channels.getPtr(name) orelse return .missing;
            if (generationOlder(generation, chan.generation)) return .stale;
            self.destroyChannelLocked(chan);
            return .removed;
        }

        /// Remove and free a channel.  Caller MUST hold self.mutex.
        ///
        /// `chan` points into the map, so everything needed is read out of it
        /// before the swapRemove (which may move another entry into its slot).
        fn destroyChannelLocked(self: *Self, chan: *Channel) void {
            const conn_name = chan.connection_name;
            const conn = chan.conn;
            const methods = chan.methods;
            log.debug("channel destroy: {s}  remaining={d}", .{ conn_name, self.channels.count() - 1 });
            self.unlinkLocked(conn, chan.conn_slot);
            if (!self.channels.swapRemove(conn_name)) {
                // This should never happen — it means the channel was already
                // removed (double-free).  Log and skip the free to avoid UB.
                log.err("channel double-destroy detected for: {s}  map_count={d}", .{ conn_name, self.channels.count() });
                return;
            }
            freeMethodSet(self.allocator, methods);
            self.allocator.free(conn_name);
            conn.release();
        }

        pub fn clearAllChannels(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            log.debug("clearAllChannels: removing {d} channels", .{self.channels.count()});
            self.freeAllLocked();
        }
    };
}

const Dummy = struct {
    refs: u32 = 1,
    pub fn retain(self: *@This()) void {
        self.refs += 1;
    }
    pub fn release(self: *@This()) void {
        self.refs -= 1;
    }
};

test "getOrCreateChannel frees the name if the map cannot grow" {
    const Mapper = ChannelsMapper(Dummy);
    for (0..5) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
        var mapper = Mapper{ .channels = .{}, .allocator = failing.allocator() };
        defer mapper.freeAllLocked();
        var dummy = Dummy{};
        try std.testing.expectError(error.OutOfMemory, mapper.getOrCreateChannel(&dummy, "peer"));
        try std.testing.expectEqual(@as(u32, 1), dummy.refs);
        try std.testing.expectEqual(@as(usize, 0), mapper.channels.count());
        try std.testing.expectEqual(@as(usize, 0), mapper.by_conn.count());
    }
}

test "ChannelsMapper finds a connection's channels through its index" {
    const Mapper = ChannelsMapper(Dummy);
    const mapper = try Mapper.init(std.testing.allocator);
    defer mapper.deinit();
    var a = Dummy{};
    var b = Dummy{};
    for ([_][]const u8{ "a1", "a2", "a3" }) |n| _ = try mapper.getOrCreateChannel(&a, n);
    _ = try mapper.getOrCreateChannel(&b, "b1");
    // Lookup first: an existing name is not copied again.
    _ = try mapper.getOrCreateChannel(&a, "a2");
    try std.testing.expectEqual(@as(u32, 4), a.refs);

    // Moving a name re-files it under its new connection.
    try std.testing.expectEqual(Mapper.Put.repointed, try mapper.upsert(&b, "a1", &.{"m"}, 7));
    try std.testing.expectEqual(@as(u32, 3), a.refs);
    try std.testing.expectEqual(Mapper.Removal.removed, mapper.destroyChannelByName("a3", 0));

    var seen: usize = 0;
    while (mapper.removeOneByConnection(&b, std.testing.allocator)) |r| : (seen += 1) {
        defer std.testing.allocator.free(r.name.?);
        try std.testing.expect(std.mem.eql(u8, r.name.?, "b1") or (std.mem.eql(u8, r.name.?, "a1") and r.generation == 7));
    }
    try std.testing.expectEqual(@as(usize, 2), seen);
    try std.testing.expectEqual(@as(u32, 1), b.refs);
    const left = mapper.removeOneByConnection(&a, std.testing.allocator).?;
    defer std.testing.allocator.free(left.name.?);
    try std.testing.expectEqualStrings("a2", left.name.?);
    try std.testing.expectEqual(@as(?Mapper.Removed, null), mapper.removeOneByConnection(&a, std.testing.allocator));
    try std.testing.expectEqual(@as(u32, 1), a.refs);
    try std.testing.expectEqual(@as(usize, 0), mapper.by_conn.count());
}

test "ChannelsMapper ignores updates and removals from an older generation" {
    const Mapper = ChannelsMapper(Dummy);
    const mapper = try Mapper.init(std.testing.allocator);
    defer mapper.deinit();
    var old = Dummy{};
    var new = Dummy{};
    _ = try mapper.upsert(&old, "w", &.{"f"}, 1);
    _ = try mapper.upsert(&new, "w", &.{"g"}, 2);
    try std.testing.expectEqual(Mapper.Put.stale, try mapper.upsert(&old, "w", &.{"f"}, 1));
    try std.testing.expectEqual(Mapper.Removal.stale, mapper.destroyChannelByName("w", 1));
    try std.testing.expect(mapper.hasChannel("w"));
    mapper.noteGeneration("w", 1);
    try std.testing.expectEqual(@as(u16, 2), (try mapper.getChannel("w")).generation);
    // Wraps: 65535 is older than 2.
    try std.testing.expect(generationOlder(65535, 2));
    try std.testing.expectEqual(Mapper.Removal.removed, mapper.destroyChannelByName("w", 2));
    try std.testing.expectEqual(Mapper.Removal.missing, mapper.destroyChannelByName("w", 0));
}

test "ChannelsMapper round-robin visits each matching channel in turn" {
    const Mapper = ChannelsMapper(Dummy);
    const mapper = try Mapper.init(std.testing.allocator);
    defer mapper.deinit();
    var c = Dummy{};
    _ = try mapper.upsert(&c, "me", &.{"f"}, null);
    _ = try mapper.upsert(&c, "w1", &.{"f"}, null);
    _ = try mapper.upsert(&c, "x", &.{"g"}, null);
    _ = try mapper.upsert(&c, "w2", &.{ "f", "g" }, null);
    var cursor: usize = 0;
    var got: [4][]const u8 = undefined;
    for (&got) |*g| g.* = try mapper.findRoundRobinDupe(std.testing.allocator, "f", "me", &cursor);
    defer for (got) |g| std.testing.allocator.free(g);
    try std.testing.expectEqualStrings("w1", got[0]);
    try std.testing.expectEqualStrings("w2", got[1]);
    try std.testing.expectEqualStrings("w1", got[2]);
    try std.testing.expectEqualStrings("w2", got[3]);
    try std.testing.expectError(error.ChannelNotFound, mapper.findRoundRobinDupe(std.testing.allocator, "nope", "me", &cursor));
}

test "a method set replaced by upsert is never seen half rebuilt under the lock" {
    const Mapper = ChannelsMapper(Dummy);
    const mapper = try Mapper.init(std.heap.c_allocator);
    defer mapper.deinit();
    var conn = Dummy{ .refs = 1 << 20 };
    _ = try mapper.upsert(&conn, "w", &.{"m0"}, null);

    const Writer = struct {
        fn run(m: *Mapper, c: *Dummy, stop: *std.atomic.Value(bool)) void {
            const lists = [_][]const []const u8{ &.{ "m0", "a", "b", "c", "d", "e" }, &.{"m0"} };
            var i: usize = 0;
            while (!stop.load(.acquire)) : (i += 1) {
                _ = m.upsert(c, "w", lists[i % 2], null) catch return;
            }
        }
    };
    var stop = std.atomic.Value(bool).init(false);
    const writer = try std.Thread.spawn(.{}, Writer.run, .{ mapper, &conn, &stop });
    defer writer.join();
    defer stop.store(true, .release);
    for (0..200_000) |_| {
        mapper.mutex.lock();
        defer mapper.mutex.unlock();
        try std.testing.expect(mapper.channels.getPtr("w").?.containsMethod("m0"));
    }
}
