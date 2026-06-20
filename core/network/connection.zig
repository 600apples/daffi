const std = @import("std");
const posix = std.posix;
const ascii = std.ascii;
const serde = @import("../serde.zig");
const network = @import("../network.zig");
const tls_impl = @import("tls.zig");
const handlers = @import("../handlers.zig");
const store = @import("../store.zig");
const ClientConnection = network.ClientConnection;
const WasmConnection = network.WasmConnection;
// On wasm, WebConnection and ServerConnection are aliased to WasmConnection
// (which provides a SynParser stub), so no std.net import is triggered.
const WebConnection = network.WebConnection;
const SynParser = WebConnection.SynParser;
const ServerConnection = network.ServerConnection;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const misc    = @import("../misc.zig");
const is_wasm = misc.is_wasm;
const Mutex   = misc.Mutex;

pub const ConnectionType = enum {
    ClientConnectionType,
    ServerConnectionType,
};

/// Minimal network address type — replaces std.net.Address (removed in 0.16).
/// Native builds should populate this from the OS; for wasm it is a stub.
///
/// The `bytes` field stores the raw `sockaddr` structure written by the kernel
/// (same layout as `sockaddr_in` / `sockaddr_in6` / `sockaddr_un`).
/// Use `fmtNetAddr(addr)` with `{f}` to print as "127.0.0.1:6009".
pub const NetAddress = struct {
    bytes: [28]u8 = [_]u8{0} ** 28,
};

/// Format a `NetAddress` for display.
/// Example: `std.debug.print("from {f}\n", .{fmtNetAddr(addr)});`
pub fn fmtNetAddr(addr: NetAddress) std.fmt.Alt(NetAddress, formatNetAddrFn) {
    return .{ .data = addr };
}

fn formatNetAddrFn(addr: NetAddress, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    // bytes[0..2] = sin_family (u16, native/little-endian on Linux/macOS)
    const family = std.mem.readInt(u16, addr.bytes[0..2], .little);
    switch (family) {
        2 => { // AF_INET — sockaddr_in: [family u16][port u16 BE][addr u32 BE]
            const port = std.mem.readInt(u16, addr.bytes[2..4], .big);
            const ip   = addr.bytes[4..8];
            try writer.print("{d}.{d}.{d}.{d}:{d}", .{ ip[0], ip[1], ip[2], ip[3], port });
        },
        10 => { // AF_INET6 — sockaddr_in6
            const port = std.mem.readInt(u16, addr.bytes[2..4], .big);
            try writer.print("[ipv6]:{d}", .{port});
        },
        1 => { // AF_UNIX — sun_path starts at bytes[2]
            const path = std.mem.sliceTo(addr.bytes[2..], 0);
            try writer.print("unix:{s}", .{path});
        },
        else => try writer.writeAll("<unknown addr>"),
    }
}

/// Accepted connection descriptor — replaces std.net.Server.Connection (removed in 0.16).
pub const AcceptedConnection = struct {
    fd: posix.socket_t = -1,
    address: NetAddress = .{},
    /// Non-null when the server is in TLS mode.  Carries the server's shared
    /// SslCtx pointer so the caller can perform a server-side TLS handshake.
    /// The pointer is cast to *anyopaque here to keep connection.zig free of
    /// TLS headers — ClientConnection.initFromAccepted() casts it back.
    ssl_ctx: ?*anyopaque = null,
};

pub const OperationTable = struct {
    read: *const fn (ctx: *anyopaque, buf: []u8) anyerror!usize,
    readNoBuffer: *const fn (ctx: *anyopaque) anyerror!?[]const u8,
    write: *const fn (ctx: *anyopaque, data: []const u8) anyerror!void,
    accept: *const fn (ctx: *anyopaque) anyerror!AcceptedConnection,
    /// close: shut down OS resources (socket/fd) and mark suspended.
    /// Does NOT free the ctx struct — call destroy() for that.
    close: *const fn (ctx: *anyopaque) void,
    /// destroy: free the ctx struct (called after close, when no threads reference it).
    destroy: *const fn (ctx: *anyopaque) void,
    getAddr: *const fn (ctx: *anyopaque) ?NetAddress,
};

pub fn Connection(comptime contype: ConnectionType) type {
    const T = switch (contype) {
        .ClientConnectionType => if (is_wasm) WasmConnection else ClientConnection,
        .ServerConnectionType => ServerConnection,
    };

    return struct {
        ctx: *anyopaque,
        op_table: OperationTable,
        allocator: Allocator,
        /// Write-side mutex — prevents concurrent writes to the same socket.
        /// Uses pthread_mutex_t (OS futex) instead of a busy-spin bool.
        wlock: Mutex = .{},
        suspended: bool = false,
        is_websocket: bool = false,
        /// Remote peer address, set on accepted client connections.
        peer_addr: ?NetAddress = null,
        /// Reference count for server-accepted connections shared between the
        /// serverLoop thread and router onRequest/onResponse routing threads.
        /// Initial value is 1 (the serverLoop owns the connection).  Callers
        /// that need the connection to outlive a mutex release call retain()
        /// before releasing the mutex and release() when done.
        refcount: std.atomic.Value(u32) = std.atomic.Value(u32).init(1),

        pub const Self = @This();
        pub const Config = T.Config;

        // ClientConnectionType non-wasm: Reader/Writer infrastructure
        pub const ReadError = anyerror;
        pub const WriteError = anyerror;

        pub fn read(self: *Self, buf: []u8) anyerror!usize {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("read() not available for this connection type");
            return self.op_table.read(self.ctx, buf);
        }

        pub fn readNoBuffer(self: *Self) anyerror!?[]const u8 {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("readNoBuffer() not available for this connection type");
            return self.op_table.readNoBuffer(self.ctx);
        }

        pub fn write(self: *Self, data: []const u8) anyerror!void {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("write() not available for this connection type");
            self.wlock.lock();
            defer self.wlock.unlock();
            try self.op_table.write(self.ctx, data);
        }

        /// Increment the reference count.  Call before releasing a lock that
        /// protects this connection pointer when another thread may destroy it.
        pub fn retain(self: *Self) void {
            _ = self.refcount.fetchAdd(1, .monotonic);
        }

        /// Decrement the reference count.  Frees all resources when the count
        /// reaches zero (i.e. this was the last owner).
        pub fn release(self: *Self) void {
            if (self.refcount.fetchSub(1, .acq_rel) == 1) {
                self.op_table.destroy(self.ctx);
                self.allocator.destroy(self);
            }
        }

        // ServerConnectionType: accept
        pub fn accept(self: *Self) !*Connection(.ClientConnectionType) {
            comptime if (contype != .ServerConnectionType) @compileError("accept() not available for this connection type");
            const conn = try self.op_table.accept(self.ctx);
            const stream = @import("posix_net.zig").Stream{ .handle = conn.fd };
            const addr = conn.address;

            const ClientConnectionType = Connection(.ClientConnectionType);
            const new_self: *ClientConnectionType = try self.allocator.create(ClientConnectionType);

            if (conn.ssl_ctx != null) {
                // 1. Complete the TLS handshake to get a per-connection ssl object.
                //    The SSL_CTX belongs to the ServerConnection and must not be freed here.
                const ssl_ctx: *tls_impl.SslCtx = @ptrCast(@alignCast(conn.ssl_ctx.?));
                const ssl = tls_impl.serverHandshake(ssl_ctx, @intCast(conn.fd)) catch |err| {
                    std.debug.print("TLS handshake failed: {}\n", .{err});
                    stream.close();
                    self.allocator.destroy(new_self);
                    return err;
                };
                errdefer tls_impl.sslClose(ssl);

                // 2. Detect WSS vs plain TLS-TCP through the encrypted stream.
                //    WSS clients (browsers) open with an HTTP "GET" upgrade request.
                //    Plain TLS-TCP daffi clients open with the SYN probe instead.
                //    tryWebSocket reads exactly HEADER_SIZE bytes and — for WSS — also
                //    completes the HTTP 101 upgrade exchange in place.
                var sync_parser = try SynParser.init(self.allocator);
                defer sync_parser.deinit();
                const tls_stream = tls_impl.TlsStream{ .ssl = ssl };
                const is_wss = try sync_parser.tryWebSocket(tls_stream);

                const pnet_addr = @import("posix_net.zig").Address{};
                if (is_wss) {
                    if (comptime @import("builtin").mode == .Debug)
                        std.debug.print("accepted WSS connection from {f}\n", .{fmtNetAddr(addr)});
                    const client = try WebConnection.initWithTls(self.allocator, stream, pnet_addr, .{}, ssl);
                    new_self.* = .{ .ctx = client, .op_table = WebConnection.op_table, .allocator = self.allocator, .is_websocket = true, .peer_addr = addr };
                } else {
                    if (comptime @import("builtin").mode == .Debug)
                        std.debug.print("accepted TLS connection from {f}\n", .{fmtNetAddr(addr)});
                    const client = try ClientConnection.initFromTlsHandshake(self.allocator, conn.fd, ssl);
                    new_self.* = .{ .ctx = client, .op_table = ClientConnection.op_table, .allocator = self.allocator, .peer_addr = addr };
                }
                return new_self;
            }

            // Non-TLS path: SYN bytes distinguish WebSocket (browser) from plain TCP.
            var sync_parser = try SynParser.init(self.allocator);
            defer sync_parser.deinit();
            const is_websocket = try sync_parser.tryWebSocket(stream);
            if (is_websocket) {
                if (comptime @import("builtin").mode == .Debug)
                    std.debug.print("accepted web connection from {f}\n", .{fmtNetAddr(addr)});
                const pnet_addr = @import("posix_net.zig").Address{};
                const client = try WebConnection.init(self.allocator, stream, pnet_addr, .{});
                new_self.* = .{ .ctx = client, .op_table = WebConnection.op_table, .allocator = self.allocator, .is_websocket = true, .peer_addr = addr };
            } else {
                if (comptime @import("builtin").mode == .Debug)
                    std.debug.print("accepted connection from {f}\n", .{fmtNetAddr(addr)});
                const client = try ClientConnection.initFromAccepted(self.allocator, conn.fd);
                new_self.* = .{ .ctx = client, .op_table = ClientConnection.op_table, .allocator = self.allocator, .peer_addr = addr };
            }
            return new_self;
        }

        pub fn init(allocator: Allocator, config: Config) !*Self {
            const self: *Self = try allocator.create(Self);
            const kin = try T.init(allocator, config);
            self.* = .{ .ctx = kin, .op_table = T.op_table, .allocator = allocator };
            return self;
        }

        /// Close OS resources (socket). Marks the connection as suspended.
        /// Does NOT free any Zig memory — call destroy() when no threads hold a reference.
        pub fn close(self: *Self) void {
            self.suspended = true;
            self.op_table.close(self.ctx);
        }

        pub fn destroy(self: *Self) void {
            self.release();
        }

        pub fn getAddr(self: *Self) ?NetAddress {
            return self.op_table.getAddr(self.ctx);
        }
    };
}

test "test connection" {
    const allocator = std.testing.allocator;
    var conn = try Connection(.ClientConnectionType).init(allocator, "tcpbin.com", 4242, .{ .mode = .Router }, false);
    conn.close();
}
