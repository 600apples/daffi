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
///
/// 128 bytes == `sizeof(sockaddr_storage)`: large enough for `sockaddr_un`
/// (106/110 bytes), which a 28-byte (`sockaddr_in6`-sized) buffer silently
/// truncated, breaking Unix sockets whose path is longer than ~26 characters.
pub const NetAddress = struct {
    bytes: [128]u8 align(8) = [_]u8{0} ** 128,
};

/// Format a `NetAddress` for display.
/// Example: `std.debug.print("from {f}\n", .{fmtNetAddr(addr)});`
pub fn fmtNetAddr(addr: NetAddress) std.fmt.Alt(NetAddress, formatNetAddrFn) {
    return .{ .data = addr };
}

fn formatNetAddrFn(addr: NetAddress, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    // Linux:   bytes[0..2] = sa_family (u16, native endian)
    // BSD/macOS: bytes[0] = sa_len, bytes[1] = sa_family (u8)
    const builtin = @import("builtin");
    const bsd_layout = comptime builtin.os.tag.isBSD();
    const family: u16 = if (bsd_layout) addr.bytes[1] else std.mem.readInt(u16, addr.bytes[0..2], .little);
    const af_inet6: u16 = comptime switch (builtin.os.tag) {
        .linux => 10,
        .macos, .ios, .tvos, .watchos, .visionos => 30,
        else => 28,
    };
    if (family == af_inet6) {
        const port = std.mem.readInt(u16, addr.bytes[2..4], .big);
        return writer.print("[ipv6]:{d}", .{port});
    }
    switch (family) {
        2 => { // AF_INET — sockaddr_in: [family u16][port u16 BE][addr u32 BE]
            const port = std.mem.readInt(u16, addr.bytes[2..4], .big);
            const ip   = addr.bytes[4..8];
            try writer.print("{d}.{d}.{d}.{d}:{d}", .{ ip[0], ip[1], ip[2], ip[3], port });
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
        /// True once the connection has been interrupted/closed.  Atomic: it is
        /// written by whichever thread tears the connection down and polled by
        /// reader/accept loops.
        suspended: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
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

        /// Decrement the reference count.  When the count reaches zero (i.e.
        /// this was the last owner) the underlying socket/TLS session is closed
        /// and all memory is freed — nothing else ever releases the descriptor,
        /// so every `init`/`accept` must be matched by exactly one final release.
        pub fn release(self: *Self) void {
            if (self.refcount.fetchSub(1, .acq_rel) == 1) {
                self.op_table.destroy(self.ctx);
                self.allocator.destroy(self);
            }
        }

        // ServerConnectionType: accept
        //
        // Accepting is split in two so the (potentially slow) protocol probe and
        // TLS handshake can run on the per-connection thread instead of the
        // accept loop: a peer that connects and then says nothing must not be
        // able to stall every other client.

        /// Wait up to `timeout_ms` for an inbound TCP connection and return the
        /// raw accepted descriptor.  `error.Timeout` means "nothing yet".
        pub fn acceptRaw(self: *Self, timeout_ms: c_int) !AcceptedConnection {
            comptime if (contype != .ServerConnectionType) @compileError("acceptRaw() not available for this connection type");
            _ = timeout_ms; // the poll timeout is applied inside the op table
            return try self.op_table.accept(self.ctx);
        }

        /// Turn a raw accepted descriptor into a Connection: complete the TLS
        /// handshake if needed and tell WebSocket (browser) clients apart from
        /// native daffi clients.  Takes ownership of `conn.fd` — it is closed on
        /// every error path.
        pub fn upgradeAccepted(self: *Self, conn: AcceptedConnection) !*Connection(.ClientConnectionType) {
            comptime if (contype != .ServerConnectionType) @compileError("upgradeAccepted() not available for this connection type");
            const posix_net = @import("posix_net.zig");
            const stream = posix_net.Stream{ .handle = conn.fd };
            const addr = conn.address;
            const ClientConnectionType = Connection(.ClientConnectionType);

            // Until a connection object owns the descriptor, any failure closes it.
            var fd_owned = false;
            errdefer if (!fd_owned) stream.close();

            // Bound the blocking probe/handshake reads and writes.
            stream.setIoTimeout(tls_impl.HANDSHAKE_TIMEOUT_MS);

            var sync_parser = try SynParser.init(self.allocator);
            defer sync_parser.deinit();
            const pnet_addr = posix_net.Address{};

            var ctx: *anyopaque = undefined;
            var table: OperationTable = undefined;
            var is_websocket = false;

            if (conn.ssl_ctx != null) {
                // 1. Complete the TLS handshake to get a per-connection ssl object.
                //    The SSL_CTX belongs to the ServerConnection and must not be freed here.
                const ssl_ctx: *tls_impl.SslCtx = @ptrCast(@alignCast(conn.ssl_ctx.?));
                const ssl = try tls_impl.serverHandshake(ssl_ctx, @intCast(conn.fd));
                var ssl_owned = false;
                errdefer if (!ssl_owned) tls_impl.sslClose(ssl, false);

                // 2. Detect WSS vs plain TLS-TCP through the encrypted stream.
                //    WSS clients (browsers) open with an HTTP "GET" upgrade request.
                //    Plain TLS-TCP daffi clients open with the SYN probe instead.
                const is_wss = try sync_parser.tryWebSocket(tls_impl.TlsStream{ .ssl = ssl });
                tls_impl.finishHandshake(ssl);
                if (is_wss) {
                    ctx = try WebConnection.initWithTls(self.allocator, stream, pnet_addr, .{}, ssl);
                    table = WebConnection.op_table;
                    is_websocket = true;
                } else {
                    ctx = try ClientConnection.initFromTlsHandshake(self.allocator, conn.fd, ssl);
                    table = ClientConnection.op_table;
                }
                ssl_owned = true;
            } else {
                // Non-TLS path: SYN bytes distinguish WebSocket (browser) from plain TCP.
                is_websocket = try sync_parser.tryWebSocket(stream);
                stream.setIoTimeout(0);
                if (is_websocket) {
                    ctx = try WebConnection.init(self.allocator, stream, pnet_addr, .{});
                    table = WebConnection.op_table;
                } else {
                    ctx = try ClientConnection.initFromAccepted(self.allocator, conn.fd);
                    table = ClientConnection.op_table;
                }
            }
            // `ctx` now owns the descriptor (and TLS session).
            fd_owned = true;

            const new_self = self.allocator.create(ClientConnectionType) catch |err| {
                table.destroy(ctx);
                return err;
            };
            new_self.* = .{ .ctx = ctx, .op_table = table, .allocator = self.allocator, .is_websocket = is_websocket, .peer_addr = addr };
            if (comptime @import("builtin").mode == .Debug)
                std.debug.print("accepted {s} connection from {f}\n", .{ if (is_websocket) "web" else "native", fmtNetAddr(addr) });
            return new_self;
        }

        pub fn init(allocator: Allocator, config: Config) !*Self {
            const self: *Self = try allocator.create(Self);
            errdefer allocator.destroy(self);
            const kin = try T.init(allocator, config);
            self.* = .{ .ctx = kin, .op_table = T.op_table, .allocator = allocator };
            return self;
        }

        /// Interrupt the connection: mark it suspended and shut the socket down so
        /// threads blocked in read/write/accept wake up.  Idempotent and safe to
        /// call concurrently with I/O.  Frees nothing — the descriptor is released
        /// by the final destroy()/release().
        pub fn close(self: *Self) void {
            self.suspended.store(true, .release);
            self.op_table.close(self.ctx);
        }

        pub fn destroy(self: *Self) void {
            self.release();
        }

        pub fn isSuspended(self: *const Self) bool {
            return self.suspended.load(.acquire);
        }

        pub fn getAddr(self: *Self) ?NetAddress {
            return self.op_table.getAddr(self.ctx);
        }
    };
}
