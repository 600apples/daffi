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
    .readSome = readSome,
    .readNoBuffer = readNoBuffer,
    .write = write,
    .accept = accept,
    .handle = handle,
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
/// Set by close() once the socket has been shut down; destroy() then skips the
/// TLS close_notify (it could no longer be delivered anyway).
interrupted: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

pub const Config = struct {
    host: []const u8,
    port: u16,
    tls: bool = false,
    /// CA trust: filesystem path or PEM material. Empty disables verification.
    ca: []const u8 = "",
    /// Client identity for mutual TLS (filesystem path or PEM material).
    cert: []const u8 = "",
    key: []const u8 = "",
};

const zero_timeout = std.mem.toBytes(posix.timeval{ .tv_sec = 0, .tv_usec = 0 });

/// Initiate an outbound TCP (or Unix-socket) connection.
/// If config.tls is true, a TLS client handshake is performed after the TCP connect.
pub fn init(allocator: Allocator, config: Config) !*ClientConnection {
    // '/' cannot occur in a host name, so such a host is a Unix socket path.
    const stream = if (std.mem.indexOfScalar(u8, config.host, '/') != null)
        try net.connectUnixSocket(config.host)
    else
        net.tcpConnectToHost(allocator, config.host, config.port) catch |tcp_err| blk: {
            // A Unix-socket fallback runs next and would replace the TCP
            // errno (EMFILE, ECONNREFUSED, timeout) with its own. Keep the
            // TCP reason for the Python traceback when the fallback fails.
            var saved: [160]u8 = undefined;
            const detail = net.connectFailure();
            const n = @min(detail.len, saved.len);
            @memcpy(saved[0..n], detail[0..n]);
            const unix_stream = net.connectUnixSocket(config.host) catch {
                if (n > 0) net.setConnectFailure(saved[0..n]);
                return tcp_err;
            };
            break :blk unix_stream;
        };
    errdefer stream.close();

    const self = try allocator.create(ClientConnection);
    errdefer allocator.destroy(self);
    self.* = ClientConnection{
        .stream = stream,
        .addr = null,
        .allocator = allocator,
    };

    // Applies to plain TCP; the TLS path replaces it with non-blocking I/O.
    try self.writeTimeout(1000);

    if (config.tls) {
        tls_impl.init();
        const ssl_ctx = try tls_impl.clientCtx(config.ca, config.cert, config.key);
        errdefer tls_impl.freeCtx(ssl_ctx);
        // Bound the blocking handshake so a server that accepts the TCP
        // connection but never answers cannot hang the caller forever.
        stream.setIoTimeout(tls_impl.HANDSHAKE_TIMEOUT_MS);
        const ssl = try tls_impl.clientHandshake(ssl_ctx, @intCast(stream.handle), config.host);
        tls_impl.finishHandshake(ssl);
        self.ssl_ctx = ssl_ctx;
        self.ssl = ssl;
    }

    self.enableKeepalive(10, 5, 3);
    return self;
}

/// Create a plain (non-TLS) ClientConnection from an already-accepted TCP fd.
pub fn initFromAccepted(allocator: Allocator, fd: posix.socket_t) !*ClientConnection {
    const stream = net.Stream{ .handle = fd };
    const self = try allocator.create(ClientConnection);
    self.* = .{ .stream = stream, .addr = null, .allocator = allocator };
    self.enableKeepalive(10, 5, 3);
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
    self.enableKeepalive(10, 5, 3);
    return self;
}

/// Block until some bytes arrive; returns how many (0 at end-of-stream).
pub fn read(ctx: *anyopaque, buf: []u8) !usize {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| return tls_impl.sslRead(ssl, buf);
    return try self.stream.read(buf);
}

pub fn readSome(ctx: *anyopaque, buf: []u8) !usize {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| return tls_impl.sslReadSome(ssl, buf);
    return self.stream.readSome(buf);
}

pub fn handle(ctx: *anyopaque) posix.socket_t {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    return self.stream.handle;
}

pub fn readNoBuffer(_: *anyopaque) !?[]const u8 {
    @panic("readNoBuffer not supported for client connections");
}

pub fn write(ctx: *anyopaque, data: []const u8) !void {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| return tls_impl.sslWrite(ssl, data);
    return try self.stream.writeAll(data);
}

pub fn accept(_: *anyopaque, _: c_int) anyerror!AcceptedConnection {
    @panic("accept not supported for client connections");
}

/// Interrupt the connection: shut the socket down so that any thread blocked
/// in read()/write() returns immediately.  Idempotent and safe to call while
/// other threads are using the connection.
///
/// Nothing is freed here — the descriptor, the TLS session and the struct are
/// released by destroy(), which runs once the last reference is dropped.  Tearing
/// the SSL object down from this thread while the reader is inside SSL_read
/// (as an earlier version did) is a use-after-free.
pub fn close(ctx: *anyopaque) void {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    self.interrupted.store(true, .release);
    self.stream.shutdown();
}

/// Release every resource: TLS session, owned SSL_CTX, the socket descriptor
/// and the struct itself.  Called exactly once, when no thread references the
/// connection any more (see Connection.release).
pub fn destroy(ctx: *anyopaque) void {
    const self: *ClientConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| {
        tls_impl.sslClose(ssl, !self.interrupted.load(.acquire));
        self.ssl = null;
    }
    if (self.ssl_ctx) |ssl_ctx| {
        tls_impl.freeCtx(ssl_ctx);
        self.ssl_ctx = null;
    }
    self.stream.close();
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

/// Enable TCP keepalive so that a silently-dropped network path (e.g. Wi-Fi
/// turned off while the socket is idle) is detected within a bounded time
/// instead of leaving the read thread blocked forever.
///
/// Parameters (all in seconds):
///   idle     – inactivity before the first probe is sent   (default: 10)
///   interval – gap between subsequent probes               (default:  5)
///   count    – probes without a reply before declaring dead (default:  3)
///
/// Total worst-case detection: idle + interval * count  (default: 25 s)
///
/// Silently ignored on Unix-domain sockets, which do not support keepalive.
pub fn enableKeepalive(self: *ClientConnection, idle: u32, interval: u32, count: u32) void {
    const fd = self.stream.handle;

    const one: c_int = 1;
    posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.KEEPALIVE, std.mem.asBytes(&one)) catch return;

    const idle_i: c_int  = @intCast(idle);
    const intvl_i: c_int = @intCast(interval);
    const cnt_i: c_int   = @intCast(count);

    const tag = @import("builtin").target.os.tag;
    if (tag == .linux or tag == .emscripten) {
        posix.setsockopt(fd, posix.IPPROTO.TCP, posix.TCP.KEEPIDLE,  std.mem.asBytes(&idle_i))  catch {};
        posix.setsockopt(fd, posix.IPPROTO.TCP, posix.TCP.KEEPINTVL, std.mem.asBytes(&intvl_i)) catch {};
        posix.setsockopt(fd, posix.IPPROTO.TCP, posix.TCP.KEEPCNT,   std.mem.asBytes(&cnt_i))   catch {};
    } else if (tag == .macos or tag == .ios or tag == .tvos or tag == .watchos) {
        // macOS uses TCP_KEEPALIVE for the idle timeout (Linux calls it TCP_KEEPIDLE).
        posix.setsockopt(fd, posix.IPPROTO.TCP, posix.TCP.KEEPALIVE, std.mem.asBytes(&idle_i))  catch {};
        posix.setsockopt(fd, posix.IPPROTO.TCP, posix.TCP.KEEPINTVL, std.mem.asBytes(&intvl_i)) catch {};
        posix.setsockopt(fd, posix.IPPROTO.TCP, posix.TCP.KEEPCNT,   std.mem.asBytes(&cnt_i))   catch {};
    }
    // Other platforms: SO_KEEPALIVE is still set above; fine-tuning is best-effort.
}
