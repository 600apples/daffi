const std = @import("std");
const network = @import("../network.zig");
const Allocator = std.mem.Allocator;
const Mutex = @import("../misc.zig").Mutex;

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

        pub fn getOrCreateChannel(self: *Self, conn: *ConnectionT, chan_uuid: Uuid) !*Channel {
            self.mutex.lock();
            defer self.mutex.unlock();
            const chan_uuid_dup = try self.allocator.dupe(u8, chan_uuid);
            const result = try self.channels.getOrPut(self.allocator, chan_uuid_dup);
            const chan = result.value_ptr;
            if (!result.found_existing) {
                chan.* = try Channel.init(self.allocator, conn, chan_uuid_dup);
            } else {
                // just update connection. It might be different if client reconnected.
                chan.conn = conn;
                self.allocator.free(chan_uuid_dup);
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
            chan.methods.deinit();
            self.allocator.destroy(chan.methods);
            const conn_name = chan.connection_name;
            std.debug.assert(self.channels.swapRemove(conn_name));
            self.allocator.free(conn_name);
        }

        pub fn clearAllChannels(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            for (self.channels.values()) |*chan| {
                chan.methods.deinit();
                self.allocator.destroy(chan.methods);
                self.allocator.free(chan.connection_name);
            }
            self.channels.clearAndFree(self.allocator);
        }
    };
}
