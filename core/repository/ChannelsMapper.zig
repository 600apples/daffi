const std = @import("std");
const network = @import("../network.zig");
const Allocator = std.mem.Allocator;
const Mutex = @import("../misc.zig").Mutex;

const expect = std.testing.expect;

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

            pub fn deinit(self: *Channel, allocator: Allocator) void {
                self.methods.deinit();
                allocator.free(self.connection_name);
            }

            pub fn addMethod(self: *Channel, method_name: []const u8) !void {
                try self.methods.insert(method_name);
            }

            pub fn containsMethod(self: *Channel, method_name: []const u8) bool {
                return self.methods.contains(method_name);
            }

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

        pub fn ChannelsCount(self: *Self) usize {
            return self.channels.count();
        }

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

        pub fn getChannelByConnection(self: *Self, conn: *ConnectionT) ?*Channel {
            for (self.channels.values()) |*chan| {
                if (chan.conn == conn) return chan;
            }
            return null;
        }

        pub fn destroyChannel(self: *Self, chan: *Channel) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            const conn_name = chan.connection_name;
            defer self.allocator.free(conn_name);
            std.debug.assert(self.channels.swapRemove(conn_name));
        }

        pub fn destroyChannelByConnection(self: *Self, conn: *ConnectionT) void {
            if (self.getChannelByConnection(conn)) |chan| self.destroyChannel(chan);
        }

        pub fn clearAllChannels(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            for (self.channels.values()) |*chan| {
                chan.clear();
            }
            self.channels.clearAndFree(self.allocator);
        }
    };
}

test "test ChannelsMapper" {
    const alloc = std.testing.allocator;
    const mapper = try ChannelsMapper.init(alloc);
    defer mapper.deinit();
    try expect(!mapper.containsMethod("chan1", "method1"));
    try mapper.addMethod("chan1", "method1");
    try expect(mapper.containsMethod("chan1", "method1"));
    try expect(!mapper.containsMethod("chan2", "method1"));
    try mapper.addMethod("chan2", "method1");
    try expect(mapper.containsMethod("chan2", "method1"));

    try mapper.addMethod("chan2", "method2");
    try mapper.addMethod("chan2", "method3");
    try mapper.addMethod("chan2", "method4");
    try mapper.addMethod("chan2", "method5");

    try expect(mapper.containsMethod("chan2", "method2"));
    try expect(mapper.containsMethod("chan2", "method3"));
    try expect(mapper.containsMethod("chan2", "method4"));
    try expect(mapper.containsMethod("chan2", "method5"));
}
