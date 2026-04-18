//! Plain-TCP and TLS client connection, used for both outbound client
//! connections and inbound connections accepted by the server.

const std = @import("std");
const posix = std.posix;
const net = @import("posix_net.zig");
const tls_impl = @import("tls.zig");
const Allocator = std.mem.Allocator;
const OperationTable = @import("../network.zig").OperationTable;
const AcceptedConnection = @import("../network/connection.zig").AcceptedConnection;

const ClientConnection = @This();

pub const op_table = OperationTable{
    .read = read,
    .readNoBuffer = readNoBuffer,
    .write = write,
    .accept = accept,
    .close = close,
    .destroy = destroy,
    .getAddr = getAddr,
};

stream: net.Stream,
addr: ?net.Address,
allocator: Allocator,
/// Non-null when this connection uses TLS (holds the per-connection SSL*).
ssl: ?*tls_impl.SslConn = null,
/// Non-null when this connection owns its SSL_CTX (client-initiated TLS).
/// Null for server-accepted TLS connections — the ServerConnection owns the ctx.
ssl_ctx: ?*tls_impl.SslCtx = null,

pub const Config = struct {
    host: []const u8,
    port: u16,
    tls: bool = false,
    /// PEM file path for a CA bundle used to verify the server certificate.
    /// Empty string disables peer verification.
    ca_file: []const u8 = "",
    password: []const u8 = "",
};

const zero_timeout = std.mem.toBytes(posix.timeval{ .tv_sec = 0, .tv_usec = 0 });

/// Initiate an outbound TCP (or Unix-socket) connection.
/// If config.tls is true, a TLS client handshake is performed after the TCP connect.
pub fn init(allocator: Allocator, config: Config) !*ClientConnection {
    const stream = net.tcpConnectToHost(allocator, config.host, config.port) catch blk: {
        break :blk try net.connectUnixSocket(config.host);
    };

    const self = try allocator.create(ClientConnection);
    self.* = ClientConnection{
        .stream = stream,
        .addr = null,
        .allocator = allocator,
    };

    if (config.tls) {
        tls_impl.init();
        // Build a null-terminated copy of ca_file for the C API.
        var ca_buf: [512]u8 = undefined;
        if (config.ca_file.len >= ca_buf.len) {
            self.stream.close();
            allocator.destroy(self);
            return error.PathTooLong;
        }
        @memcpy(ca_buf[0..config.ca_file.len], config.ca_file);
        ca_buf[config.ca_file.len] = 0;
        const ssl_ctx = tls_impl.clientCtx(@ptrCast(&ca_buf)) catch |err| {
            self.stream.close();
            allocator.destroy(self);
            return err;
        };
        self.ssl_ctx = ssl_ctx;
        self.ssl = tls_impl.clientHandshake(ssl_ctx, @intCast(stream.handle)) catch |err| {
            tls_impl.freeCtx(ssl_ctx);
            self.stream.close();
            allocator.destroy(self);
            return err;
        };
    }

    try self.writeTimeout(1000);
    return self;
}

/// Create a plain (non-TLS) ClientConnection from an already-accepted TCP fd.
pub fn initFromAccepted(allocator: Allocator, fd: posix.socket_t) !*ClientConnection {
    const stream = net.Stream{ .handle = fd };
    const self = try allocator.create(ClientConnection);
    self.* = .{ .stream = stream, .addr = null, .allocator = allocator };
    return self;
}

/// Create a TLS ClientConnection from an already-completed server-side TLS handshake.
///
/// Takes ownership of `ssl`; it will be freed in close().
/// The SSL_CTX that was used for the handshake is owned by the ServerConnection,
/// NOT by this ClientConnection.
pub fn initFromTlsHandshake(allocator: Allocator, fd: posix.socket_t, ssl: *tls_impl.SslConn) !*ClientConnection {
    const stream = net.Stream{ .handle = fd };
    const self = try allocator.create(ClientConnection);
    self.* = .{ .stream = stream, .addr = null, .allocator = allocator, .ssl = ssl };
    return self;
}

pub fn read(ctx: *anyopaque, buf: []u8) !usize {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| return tls_impl.sslReadAll(ssl, buf);
    return try self.stream.readAll(buf);
}

pub fn readNoBuffer(_: *anyopaque) !?[]const u8 {
    @panic("readNoBuffer not supported for client connections");
}

pub fn write(ctx: *anyopaque, data: []const u8) !void {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| return tls_impl.sslWrite(ssl, data);
    return try self.stream.writeAll(data);
}

pub fn accept(_: *anyopaque) anyerror!AcceptedConnection {
    @panic("accept not supported for client connections");
}

/// Close the connection: tear down TLS (if active), then close the socket.
/// Does NOT free the ClientConnection struct — call destroy() for that.
pub fn close(ctx: *anyopaque) void {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| {
        tls_impl.sslClose(ssl);
        self.ssl = null;
    }
    if (self.ssl_ctx) |ssl_ctx| {
        tls_impl.freeCtx(ssl_ctx);
        self.ssl_ctx = null;
    }
    self.stream.close();
}

pub fn destroy(ctx: *anyopaque) void {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}

pub fn getAddr(ctx: *anyopaque) ?@import("../network/connection.zig").NetAddress {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    if (self.addr) |addr| {
        var na = @import("../network/connection.zig").NetAddress{};
        @memcpy(&na.bytes, &addr.bytes);
        return na;
    }
    return null;
}

pub fn writeTimeout(self: *ClientConnection, ms: u32) !void {
    if (ms == 0) return;
    const timeout = std.mem.toBytes(posix.timeval{
        .sec = @intCast(@divTrunc(ms, 1000)),
        .usec = @intCast(@mod(ms, 1000) * 1000),
    });
    return posix.setsockopt(self.stream.handle, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &timeout);
}
