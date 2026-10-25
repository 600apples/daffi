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
    .accept = accept,
    .handle = handle,
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
    /// Server certificate: filesystem path or PEM material (required when tls).
    cert: []const u8 = "",
    /// Server private key: filesystem path or PEM material (required when tls).
    key: []const u8 = "",
    /// When non-empty with tls, require and verify client certificates (mTLS).
    ca: []const u8 = "",
};

pub fn init(allocator: Allocator, config: Config) !*ServerConnection {
    const host = config.host orelse "0.0.0.0";
    const options = net.ListenOptions{ .kernel_backlog = 512 };

    // A host containing '/' can only be a Unix-domain socket path; never hand
    // it to the resolver (what it answers for such a name is platform-specific).
    const is_unix_path = std.mem.indexOfScalar(u8, host, '/') != null;
    const resolved: ?*net.AddressList =
        if (is_unix_path) null else (net.getAddressList(allocator, host, config.port) catch null);

    var listener: anyerror!net.Server = undefined;
    if (resolved) |addrlist| {
        defer addrlist.deinit();
        listener = error.ConnectionRefused;
        for (addrlist.addrs) |*addr| {
            const l = addr.listen(options);
            if (!std.meta.isError(l)) {
                listener = l;
                break;
            }
        }
    } else {
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

    if (config.tls) {
        // Asking for TLS but providing no certificate must fail loudly, not
        // quietly fall back to serving plaintext.
        if (config.cert.len == 0 or config.key.len == 0) {
            self.listener.deinit();
            allocator.destroy(self);
            return error.TlsCertRequired;
        }
        tls_impl.init();
        self.ssl_ctx = tls_impl.serverCtx(config.cert, config.key, config.ca) catch |err| {
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

pub fn readSome(_: *anyopaque, _: []u8) !usize {
    @panic("server connection does not support readSome");
}

pub fn handle(ctx: *anyopaque) std.posix.socket_t {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    return self.listener.handle;
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
    };
}

/// Nothing to interrupt: the accept loop polls with a timeout and notices the
/// owning Connection's `suspended` flag by itself.  (Closing a listening fd
/// from another thread does not reliably wake a blocked accept().)
pub fn close(_: *anyopaque) void {}

/// Close the listening socket, free the shared
/// SSL_CTX (TLS mode) and the struct.  Called once, by the accept-loop owner.
pub fn destroy(ctx: *anyopaque) void {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl_ctx) |sc| {
        tls_impl.freeCtx(sc);
        self.ssl_ctx = null;
    }
    self.listener.deinit();
    self.allocator.destroy(self);
}

pub fn getAddr(ctx: *anyopaque) ?NetAddress {
    const self: *ServerConnection = @ptrCast(@alignCast(ctx));
    var na = NetAddress{};
    const len = @min(na.bytes.len, self.listener.listen_address.bytes.len);
    @memcpy(na.bytes[0..len], self.listener.listen_address.bytes[0..len]);
    return na;
}
