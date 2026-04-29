const std = @import("std");
const network = @import("../network.zig");
const Allocator = std.mem.Allocator;
const Mutex = @import("../misc.zig").Mutex;
const log = std.log.scoped(.store);

pub fn ChannelsMapper(comptime ConnectionT: type) type {
    return struct {
        channels: Channels,
        allocator: Allocator,
        mutex: Mutex = .{},

        const Self = @This();

        // std.StringArrayHashMap removed in 0.16; use the unmanaged equivalent.
        pub const Channels = std.array_hash_map.String(Channel);
        const Uuid = []const u8;

        pub const Channel = struct {
            conn: *ConnectionT,
            methods: *std.BufSet,
            connection_name: []const u8,

            pub fn init(allocator: Allocator, conn: *ConnectionT, conn_name: []const u8) !Channel {
                const methods = try allocator.create(std.BufSet);
                methods.* = std.BufSet.init(allocator);
                return .{ .conn = conn, .methods = methods, .connection_name = conn_name };
            }

            /// Free the methods BufSet (internals + the struct pointer) and the
            /// connection_name string.
            pub fn deinit(self: *Channel, allocator: Allocator) void {
                self.methods.deinit();
                allocator.destroy(self.methods);
                allocator.free(self.connection_name);
            }

            pub fn addMethod(self: *Channel, method_name: []const u8) !void {
                try self.methods.insert(method_name);
            }

            pub fn containsMethod(self: *Channel, method_name: []const u8) bool {
                return self.methods.contains(method_name);
            }

            /// Clear all method entries without freeing the BufSet struct itself.
            /// Used when a handshake update replaces the method list in-place.
            pub fn clear(self: *Channel) void {
                self.methods.hash_map.clearAndFree();
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
            for (self.channels.values()) |*chan| {
                chan.methods.deinit();
                self.allocator.destroy(chan.methods);
                self.allocator.free(chan.connection_name);
            }
            self.channels.clearAndFree(self.allocator);
            self.allocator.destroy(self);
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

        pub fn getOrCreateChannel(self: *Self, conn: *ConnectionT, chan_uuid: Uuid) !*Channel {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan_uuid_dup = try self.allocator.dupe(u8, chan_uuid);
            const result = try self.channels.getOrPut(self.allocator, chan_uuid_dup);
            const chan = result.value_ptr;
            if (!result.found_existing) {
                chan.* = try Channel.init(self.allocator, conn, chan_uuid_dup);
                log.debug("channel created: {s}  total={d}", .{ chan_uuid, self.channels.count() });
            } else {
                // just update connection. It might be different if client reconnected.
                chan.conn = conn;
                self.allocator.free(chan_uuid_dup);
                log.debug("channel updated (conn ptr): {s}  total={d}", .{ chan_uuid, self.channels.count() });
            }
            return chan;
        }

        /// Find the channel associated with a specific connection pointer.
        /// Thread-safe; acquires the mutex internally.
        pub fn getChannelByConnection(self: *Self, conn: *ConnectionT) ?*Channel {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.getChannelByConnectionLocked(conn);
        }

        fn getChannelByConnectionLocked(self: *Self, conn: *ConnectionT) ?*Channel {
            for (self.channels.values()) |*chan| {
                if (chan.conn == conn) return chan;
            }
            return null;
        }

        /// Remove a channel by its connection pointer, freeing all owned resources.
        /// Thread-safe; acquires the mutex only once (avoids double-lock vs
        /// calling getChannelByConnection + destroyChannel separately).
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
        /// connection pointer so the caller can close the underlying socket.
        /// Returns null if no channel with that name exists.
        ///
        /// Used by ``onHandshake`` to evict a stale/zombie slot before
        /// registering a reconnecting peer (last-connection-wins semantics).
        /// The caller must close the returned connection AFTER releasing any
        /// handler-level mutex that the socket's reader thread may need when
        /// it wakes up and calls ``diconnectionHandler``.
        pub fn evictChannel(self: *Self, name: Uuid) ?*ConnectionT {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan = self.channels.getPtr(name) orelse return null;
            const conn = chan.conn;
            self.destroyChannelLocked(chan);
            return conn;
        }

        /// Remove a channel by name (used when a "disconnected" event arrives).
        /// Safe to call if the name is not present.
        pub fn destroyChannelByName(self: *Self, name: []const u8) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan = self.channels.getPtr(name) orelse return;
            self.destroyChannelLocked(chan);
        }

        /// Remove and free a channel.  Caller MUST hold self.mutex.
        ///
        /// Resources are freed in this order so that pointers remain valid at
        /// each step:
        ///   1. methods internals + *BufSet struct (while chan pointer is valid)
        ///   2. swapRemove by connection_name (may move another entry into chan's
        ///      slot, invalidating the chan pointer)
        ///   3. free the connection_name string (no longer needed as map key)
        fn destroyChannelLocked(self: *Self, chan: *Channel) void {
            const conn_name = chan.connection_name;
            log.debug("channel destroy: {s}  remaining={d}", .{ conn_name, self.channels.count() - 1 });
            chan.methods.deinit();
            self.allocator.destroy(chan.methods);
            if (!self.channels.swapRemove(conn_name)) {
                // This should never happen — it means the channel was already
                // removed (double-free).  Log and skip the free to avoid UB.
                log.err("channel double-destroy detected for: {s}  map_count={d}", .{ conn_name, self.channels.count() });
                return;
            }
            self.allocator.free(conn_name);
        }

        pub fn clearAllChannels(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            log.debug("clearAllChannels: removing {d} channels", .{self.channels.count()});
            for (self.channels.values()) |*chan| {
                chan.methods.deinit();
                self.allocator.destroy(chan.methods);
                self.allocator.free(chan.connection_name);
            }
            self.channels.clearAndFree(self.allocator);
        }
    };
}
