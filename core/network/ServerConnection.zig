const std = @import("std");
const net = std.net;
const StreamServer = net.Server;
const Allocator = std.mem.Allocator;
const Bundle = std.crypto.Certificate.Bundle;
const HandlerMode = @import("../handlers.zig").HandlerMode;
const OperationTable = @import("../network.zig").OperationTable;

const ServerConnection = @This();

pub const op_table = OperationTable{
    .read = read,
    .readNoBuffer = readNoBuffer,
    .write = write,
    .accept = accept,
    .close = close,
    .getAddr = getAddr,
};

listener: net.Server,
addr: net.Address,
allocator: Allocator,

pub const Config = struct {
    host: ?[]const u8,
    port: u16,
    tls: bool = false,
    ca_bundle: ?Bundle = null,
    mode: HandlerMode,
    password: []const u8,
};

pub fn init(allocator: Allocator, config: Config) !*ServerConnection {
    const host = config.host orelse "0.0.0.0";
    // 512 parallel connections for now.
    // If more than this many connections pool in the kernel, clients will start
    // seeing "Connection refused".
    const options: net.ListenOptions = .{ .kernel_backlog = 512 };
     var listener: anyerror!net.Server = undefined;
    if (net.getAddressList(allocator, host, config.port)) |addrlist| {
        defer addrlist.deinit();
        for (addrlist.addrs) |addr| {
            listener = addr.listen(options);
            if (!std.meta.isError(listener)) break;
        }
    } else |_| {
        const path = try std.fs.realpathAlloc(allocator, host);
        defer allocator.free(path);
        std.fs.deleteFileAbsolute(path) catch {};
        const addr = try net.Address.initUnix(path);
        listener = addr.listen(options);
    }
    if (listener) |l| {
        const self = try allocator.create(ServerConnection);
        self.* = ServerConnection{
            .listener = l,
            .addr = l.listen_address,
            .allocator = allocator,
        };
        return self;
    } else |err| return err;
}

pub fn read(_: *anyopaque, _: []u8) !usize {
    @panic("server connection does not support read");
}

pub fn readNoBuffer(_: *anyopaque) !?[]const u8 {
    @panic("server connection does not support readNoBuffer");
}

pub fn write(_: *anyopaque, _: []const u8) !void {
    @panic("server connection does not support write");
}

pub fn accept(ctx: *anyopaque) !StreamServer.Connection {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    return try self.listener.accept();
}

pub fn close(ctx: *anyopaque) void {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    // if (self.listener.sockfd != null) {
        // Prevent double close (might be by signal and by user action)
        self.listener.deinit();
        self.allocator.destroy(self);
    // }
}

pub fn getAddr(ctx: *anyopaque) ?net.Address {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    return self.addr;
}
