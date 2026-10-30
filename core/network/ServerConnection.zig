//! Listening TCP server connection.  Accepts inbound TCP connections and
//! optionally wraps them in TLS using a shared SSL_CTX.

const std = @import("std");
const net = @import("posix_net.zig");
const tls_impl = @import("tls.zig");
const Allocator = std.mem.Allocator;
const OperationTable = @import("../network.zig").OperationTable;
const connection = @import("../network/connection.zig");
const AcceptedConnection = connection.AcceptedConnection;
const NetAddress = connection.NetAddress;

const ServerConnection = @This();

pub const op_table = OperationTable{
    .read = read,
    .readSome = readSome,
    .readNoBuffer = readNoBuffer,
    .write = write,
    .writeParts = writeParts,
    .writeNonBlocking = writeNonBlocking,
    .accept = accept,
    .handle = handle,
    .hasPendingInput = hasPendingInput,
    .close = close,
    .destroy = destroy,
    .getAddr = getAddr,
};

listener: net.Server,
allocator: Allocator,
/// Non-null when this server is in TLS mode.  Shared across all accepted
/// connections; freed by close().
ssl_ctx: ?*tls_impl.SslCtx = null,
/// Owned copy of `Config.allowed_origins`.
allowed_origins: []const u8 = "",

pub const Config = struct {
    host: ?[]const u8,
    port: u16,
    tls: bool = false,
    /// Server certificate: filesystem path or PEM material (required when tls).
    cert: []const u8 = "",
    /// Server private key: filesystem path or PEM material (required when tls).
    key: []const u8 = "",
    /// When non-empty with tls, require and verify client certificates (mTLS).
    ca: []const u8 = "",
    /// Newline-separated origins a WebSocket upgrade may come from; empty
    /// allows any.
    allowed_origins: []const u8 = "",
};

pub fn init(allocator: Allocator, config: Config) !*ServerConnection {
    const host = config.host orelse "0.0.0.0";
    const options = net.ListenOptions{ .kernel_backlog = 512 };

    var l = if (net.unixPath(host)) |path| blk: {
        if (path.len == 0) return error.InvalidPath;
        try net.removeStaleSocket(path);
        var addr = try net.Address.initUnix(path);
        break :blk try addr.listen(options);
    } else blk: {
        const addrlist = try net.getAddressList(allocator, host, config.port);
        defer addrlist.deinit();
        var last_err: anyerror = error.UnknownHostName;
        for (addrlist.addrs) |*addr| {
            break :blk addr.listen(options) catch |err| {
                last_err = err;
                continue;
            };
        }
        return last_err;
    };
    errdefer l.deinit();
    const self = try allocator.create(ServerConnection);
    errdefer allocator.destroy(self);
    self.* = ServerConnection{ .listener = l, .allocator = allocator };
    if (config.allowed_origins.len > 0) self.allowed_origins = try allocator.dupe(u8, config.allowed_origins);
    errdefer allocator.free(self.allowed_origins);

    if (config.tls) {
        // Asking for TLS but providing no certificate must fail loudly, not
        // quietly fall back to serving plaintext.
        if (config.cert.len == 0 or config.key.len == 0) return error.TlsCertRequired;
        tls_impl.init();
        self.ssl_ctx = try tls_impl.serverCtx(config.cert, config.key, config.ca);
    }

    return self;
}

pub fn read(_: *anyopaque, _: []u8) !usize {
    @panic("server connection does not support read");
}

pub fn readSome(_: *anyopaque, _: []u8) !usize {
    @panic("server connection does not support readSome");
}

pub fn handle(ctx: *anyopaque) std.posix.socket_t {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    return self.listener.handle;
}

pub fn hasPendingInput(_: *anyopaque) bool {
    return false;
}

pub fn readNoBuffer(_: *anyopaque) !?[]const u8 {
    @panic("server connection does not support readNoBuffer");
}

pub fn write(_: *anyopaque, _: []const u8) !void {
    @panic("server connection does not support write");
}

pub fn writeParts(_: *anyopaque, _: []const u8, _: []const u8) !void {
    @panic("server connection does not support write");
}

pub fn writeNonBlocking(_: *anyopaque, _: []const u8) !usize {
    @panic("server connection does not support write");
}

/// Accept one inbound TCP connection.  If the server was started with TLS,
/// the returned AcceptedConnection carries the shared ssl_ctx pointer so the
/// caller can perform the TLS handshake on the new connection.
pub fn accept(ctx: *anyopaque, timeout_ms: c_int) !AcceptedConnection {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    const conn = try self.listener.acceptTimeout(timeout_ms);
    var na = NetAddress{};
    const len = @min(na.bytes.len, conn.address.bytes.len);
    @memcpy(na.bytes[0..len], conn.address.bytes[0..len]);
    return AcceptedConnection{
        .fd = conn.stream.handle,
        .address = na,
        .ssl_ctx = @ptrCast(self.ssl_ctx),
        .allowed_origins = self.allowed_origins,
    };
}

/// Close the listening socket, keeping the SSL_CTX for connections still
/// being upgraded.  Only once nothing polls or accepts on it: closing a
/// listening fd does not reliably wake a blocked accept().
pub fn close(ctx: *anyopaque) void {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    if (self.listener.handle < 0) return;
    self.listener.deinit();
    self.listener.handle = -1;
}

/// Close the listening socket if still open, free the shared SSL_CTX (TLS
/// mode) and the struct.
pub fn destroy(ctx: *anyopaque) void {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl_ctx) |sc| {
        tls_impl.freeCtx(sc);
        self.ssl_ctx = null;
    }
    close(ctx);
    self.allocator.free(self.allowed_origins);
    self.allocator.destroy(self);
}

pub fn getAddr(ctx: *anyopaque) ?NetAddress {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    var na = NetAddress{};
    const len = @min(na.bytes.len, self.listener.listen_address.bytes.len);
    @memcpy(na.bytes[0..len], self.listener.listen_address.bytes[0..len]);
    return na;
}
