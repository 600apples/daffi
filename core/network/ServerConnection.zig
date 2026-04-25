//! Listening TCP server connection.  Accepts inbound TCP connections and
//! optionally wraps them in TLS using a shared SSL_CTX.

const std = @import("std");
const net = @import("posix_net.zig");
const tls_impl = @import("tls.zig");
const Allocator = std.mem.Allocator;
const HandlerMode = @import("../handlers.zig").HandlerMode;
const OperationTable = @import("../network.zig").OperationTable;
const connection = @import("../network/connection.zig");
const AcceptedConnection = connection.AcceptedConnection;
const NetAddress = connection.NetAddress;

const ServerConnection = @This();

pub const op_table = OperationTable{
    .read = read,
    .readNoBuffer = readNoBuffer,
    .write = write,
    .accept = accept,
    .close = close,
    .destroy = destroy,
    .getAddr = getAddr,
};

listener: net.Server,
allocator: Allocator,
/// Non-null when this server is in TLS mode.  Shared across all accepted
/// connections; freed by close().
ssl_ctx: ?*tls_impl.SslCtx = null,

pub const Config = struct {
    host: ?[]const u8,
    port: u16,
    tls: bool = false,
    /// PEM file containing the server certificate (required when tls = true).
    cert_file: []const u8 = "",
    /// PEM file containing the server private key (required when tls = true).
    key_file: []const u8 = "",
    mode: HandlerMode,
};

pub fn init(allocator: Allocator, config: Config) !*ServerConnection {
    const host = config.host orelse "0.0.0.0";
    const options = net.ListenOptions{ .kernel_backlog = 512 };

    var listener: anyerror!net.Server = undefined;
    if (net.getAddressList(allocator, host, config.port)) |addrlist| {
        defer addrlist.deinit();
        listener = error.ConnectionRefused;
        for (addrlist.addrs) |*addr| {
            const l = addr.listen(options);
            if (!std.meta.isError(l)) {
                listener = l;
                break;
            }
        }
    } else |_| {
        // host is a Unix socket path — remove any stale socket file first
        var path_buf: [256]u8 = undefined;
        if (host.len >= path_buf.len) return error.NameTooLong;
        @memcpy(path_buf[0..host.len], host);
        path_buf[host.len] = 0;
        _ = std.c.unlink(@ptrCast(&path_buf));
        var addr = try net.Address.initUnix(host);
        listener = addr.listen(options);
    }

    const l = try listener;
    const self = try allocator.create(ServerConnection);
    self.* = ServerConnection{ .listener = l, .allocator = allocator };

    if (config.tls and config.cert_file.len > 0 and config.key_file.len > 0) {
        tls_impl.init();
        // Build null-terminated copies for the C API (only needed during init).
        var cert_buf: [512]u8 = undefined;
        var key_buf: [512]u8 = undefined;
        if (config.cert_file.len >= cert_buf.len or config.key_file.len >= key_buf.len) {
            self.listener.deinit();
            allocator.destroy(self);
            return error.PathTooLong;
        }
        @memcpy(cert_buf[0..config.cert_file.len], config.cert_file);
        cert_buf[config.cert_file.len] = 0;
        @memcpy(key_buf[0..config.key_file.len], config.key_file);
        key_buf[config.key_file.len] = 0;
        self.ssl_ctx = tls_impl.serverCtx(@ptrCast(&cert_buf), @ptrCast(&key_buf)) catch |err| {
            self.listener.deinit();
            allocator.destroy(self);
            return err;
        };
    }

    return self;
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

/// Accept one inbound TCP connection.  If the server was started with TLS,
/// the returned AcceptedConnection carries the shared ssl_ctx pointer so the
/// caller can perform the TLS handshake on the new connection.
pub fn accept(ctx: *anyopaque) !AcceptedConnection {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    const conn = try self.listener.accept();
    var na = NetAddress{};
    const len = @min(na.bytes.len, conn.address.bytes.len);
    @memcpy(na.bytes[0..len], conn.address.bytes[0..len]);
    return AcceptedConnection{
        .fd = conn.stream.handle,
        .address = na,
        .ssl_ctx = @ptrCast(self.ssl_ctx),
    };
}

/// Close the listening socket and, if TLS is active, free the shared SSL_CTX.
pub fn close(ctx: *anyopaque) void {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl_ctx) |sc| {
        tls_impl.freeCtx(sc);
        self.ssl_ctx = null;
    }
    self.listener.deinit();
}

pub fn destroy(ctx: *anyopaque) void {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}

pub fn getAddr(ctx: *anyopaque) ?NetAddress {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    var na = NetAddress{};
    const len = @min(na.bytes.len, self.listener.listen_address.bytes.len);
    @memcpy(na.bytes[0..len], self.listener.listen_address.bytes[0..len]);
    return na;
}
