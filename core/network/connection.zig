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
const runtime = @import("../runtime.zig");
const log = std.log.scoped(.connection);

/// Writes queued for a peer that is not reading, past which it is dropped.
pub const max_outbox_bytes: usize = 64 * 1024 * 1024;

/// Write side of a connection: one writer at a time.  Unlike a pthread
/// mutex it may be released by another thread than the one that took it,
/// so a frame an event loop only partly sent can be finished elsewhere
/// without any other writer getting in between.
pub const WriteGate = struct {
    mutex: Mutex = .{},
    cond: misc.Condition = .{},
    busy: bool = false,

    pub fn lock(self: *WriteGate) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.busy) self.cond.wait(&self.mutex);
        self.busy = true;
    }

    pub fn tryLock(self: *WriteGate) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.busy) return false;
        self.busy = true;
        return true;
    }

    pub fn unlock(self: *WriteGate) void {
        self.mutex.lock();
        self.busy = false;
        self.mutex.unlock();
        self.cond.signal();
    }
};

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
    bytes: [128]u8 align(8) = @splat(0),
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
    const bsd_layout = comptime builtin.target.os.tag.isBSD();
    const family: u16 = if (bsd_layout) addr.bytes[1] else std.mem.readInt(u16, addr.bytes[0..2], .little);
    const af_inet6: u16 = comptime switch (builtin.target.os.tag) {
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
    /// The listener's WebSocket Origin allow-list (newline-separated; empty
    /// refuses every upgrade, ``*`` allows any).  Native clients ignore this.
    /// Owned by the listener, which outlives every upgrade.
    websocket_allowed_origins: []const u8 = "",
};

pub const OperationTable = struct {
    /// Block until some bytes arrive; 0 means end-of-stream.
    read: *const fn (ctx: *anyopaque, buf: []u8) anyerror!usize,
    /// Non-blocking read of whatever is available: 0 means end-of-stream,
    /// `error.WouldBlock` that nothing is pending yet (evented model).
    readSome: *const fn (ctx: *anyopaque, buf: []u8) anyerror!usize,
    readNoBuffer: *const fn (ctx: *anyopaque) anyerror!?[]const u8,
    write: *const fn (ctx: *anyopaque, data: []const u8) anyerror!void,
    /// Send what the socket takes without blocking and return how much that
    /// was; 0 when the transport cannot (TLS, WebSocket).
    writeNonBlocking: *const fn (ctx: *anyopaque, data: []const u8) anyerror!usize,
    /// Write `head` then `body` as one message (one WebSocket frame).
    writeParts: *const fn (ctx: *anyopaque, head: []const u8, body: []const u8) anyerror!void,
    /// Wait up to `timeout_ms` for an inbound connection; `error.Timeout`
    /// means none arrived.
    accept: *const fn (ctx: *anyopaque, timeout_ms: c_int) anyerror!AcceptedConnection,
    /// Descriptor to watch for readiness (evented model).
    handle: *const fn (ctx: *anyopaque) posix.socket_t,
    /// Input already taken off the socket but not yet read (decrypted TLS
    /// bytes), which no readiness event will report.
    hasPendingInput: *const fn (ctx: *anyopaque) bool,
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
        /// One writer at a time on the socket.
        wlock: WriteGate = .{},
        /// Event-loop threads never block on a write: what the socket does
        /// not take at once is queued here, in order, and a blocking-pool
        /// worker sends it (see `post`).
        outbox_mutex: Mutex = .{},
        outbox: std.ArrayList([]u8) = .empty,
        outbox_bytes: usize = 0,
        /// A worker owns the write side and is sending the outbox.
        outbox_draining: bool = false,
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
        /// Monotonic ms of the last read that left a frame unfinished; 0 when
        /// no frame is in progress.  The server closes a connection whose
        /// frame stops making progress (see `frameStalled`).
        frame_progress_ms: std.atomic.Value(i64) = .init(0),

        pub const Self = @This();
        pub const Config = T.Config;

        pub fn noteFrameProgress(self: *Self, partial: bool) void {
            if (comptime is_wasm) return;
            if (!partial) {
                if (self.frame_progress_ms.load(.monotonic) != 0) self.frame_progress_ms.store(0, .monotonic);
                return;
            }
            self.frame_progress_ms.store(@import("../misc.zig").monotonicMs(), .monotonic);
        }

        /// Whether a frame has been unfinished, with no bytes arriving, for
        /// longer than `limit_ms`.
        pub fn frameStalled(self: *const Self, now_ms: i64, limit_ms: i64) bool {
            const since = self.frame_progress_ms.load(.monotonic);
            return since != 0 and now_ms - since > limit_ms;
        }

        // ClientConnectionType non-wasm: Reader/Writer infrastructure
        pub const ReadError = anyerror;
        pub const WriteError = anyerror;

        pub fn read(self: *Self, buf: []u8) anyerror!usize {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("read() not available for this connection type");
            return self.op_table.read(self.ctx, buf);
        }

        pub fn readSome(self: *Self, buf: []u8) anyerror!usize {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("readSome() not available for this connection type");
            return self.op_table.readSome(self.ctx, buf);
        }

        pub fn handle(self: *Self) posix.socket_t {
            comptime if (is_wasm) @compileError("handle() not available on wasm");
            return self.op_table.handle(self.ctx);
        }

        pub fn hasPendingInput(self: *Self) bool {
            comptime if (is_wasm) @compileError("hasPendingInput() not available on wasm");
            return self.op_table.hasPendingInput(self.ctx);
        }

        pub fn readNoBuffer(self: *Self) anyerror!?[]const u8 {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("readNoBuffer() not available for this connection type");
            return self.op_table.readNoBuffer(self.ctx);
        }

        pub fn write(self: *Self, data: []const u8) anyerror!void {
            if (comptime !is_wasm and contype == .ClientConnectionType) {
                if (runtime.onLoopThread()) return self.post(&.{data});
            }
            self.wlock.lock();
            defer self.wlock.unlock();
            try self.writeHeld(data);
        }

        /// `write` that never blocks, for event-loop threads.  Sends at once
        /// when nothing is queued and the socket takes it all; otherwise the
        /// rest is queued for a blocking-pool worker.  Writes keep their order.
        fn post(self: *Self, parts: []const []const u8) anyerror!void {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("post() not available for this connection type");
            self.outbox_mutex.lock();
            defer self.outbox_mutex.unlock();
            if (self.outbox_draining) return self.enqueue(parts, 0);
            if (!self.wlock.tryLock()) {
                // Another thread is writing: queue, and wait for it elsewhere.
                try self.enqueue(parts, 0);
                return self.startDrain(false);
            }
            var skip: usize = 0;
            for (parts) |part| {
                const sent = self.op_table.writeNonBlocking(self.ctx, part) catch |err| {
                    self.wlock.unlock();
                    self.close();
                    return err;
                };
                skip += sent;
                if (sent < part.len) break;
            } else {
                self.wlock.unlock();
                return;
            }
            // Part of a frame may be out: keep the write side, and hand it
            // to the worker that sends the rest.
            self.enqueue(parts, skip) catch |err| {
                self.wlock.unlock();
                // Bytes already on the wire — drop the connection so a later
                // write cannot continue mid-frame after a failed enqueue.
                self.close();
                return err;
            };
            return self.startDrain(true);
        }

        /// Queue `parts` minus their first `skip` bytes as one entry.  Call
        /// with `outbox_mutex` held.
        fn enqueue(self: *Self, parts: []const []const u8, skip: usize) !void {
            var len: usize = 0;
            for (parts) |part| len += part.len;
            len -= skip;
            if (self.outbox_bytes + len > max_outbox_bytes) {
                log.warn("closing a connection whose peer is not reading ({d} bytes queued)", .{self.outbox_bytes});
                self.close();
                return error.OutboxFull;
            }
            const buf = try self.allocator.alloc(u8, len);
            errdefer self.allocator.free(buf);
            var at: usize = 0;
            var left = skip;
            for (parts) |part| {
                const from = @min(left, part.len);
                left -= from;
                @memcpy(buf[at..][0 .. part.len - from], part[from..]);
                at += part.len - from;
            }
            try self.outbox.append(self.allocator, buf);
            self.outbox_bytes += len;
        }

        /// Start the worker that sends the outbox.  Call with `outbox_mutex`
        /// held; with `holds_gate` the caller's write side passes to it.
        fn startDrain(self: *Self, holds_gate: bool) !void {
            self.retain();
            runtime.spawnBlocking(drainOutbox, .{ self, holds_gate }) catch |err| {
                self.release();
                if (holds_gate) self.wlock.unlock();
                self.dropOutbox();
                self.close();
                return err;
            };
            self.outbox_draining = true;
        }

        fn drainOutbox(self: *Self, holds_gate: bool) void {
            defer self.release();
            if (!holds_gate) self.wlock.lock();
            while (true) {
                self.outbox_mutex.lock();
                if (self.outbox.items.len == 0) {
                    self.outbox_draining = false;
                    self.wlock.unlock();
                    self.outbox_mutex.unlock();
                    return;
                }
                const buf = self.outbox.orderedRemove(0);
                self.outbox_bytes -= buf.len;
                self.outbox_mutex.unlock();
                defer self.allocator.free(buf);
                self.writeHeld(buf) catch {
                    self.outbox_mutex.lock();
                    self.dropOutbox();
                    self.outbox_draining = false;
                    self.wlock.unlock();
                    self.outbox_mutex.unlock();
                    return;
                };
            }
        }

        /// Free everything queued.  Call with `outbox_mutex` held.
        fn dropOutbox(self: *Self) void {
            for (self.outbox.items) |buf| self.allocator.free(buf);
            self.outbox.clearRetainingCapacity();
            self.outbox_bytes = 0;
        }

        /// Hold the write side: writes from other threads wait until
        /// `unlockWrites`.
        pub fn lockWrites(self: *Self) void {
            self.wlock.lock();
        }

        /// `lockWrites` if no other thread holds the write side.
        pub fn tryLockWrites(self: *Self) bool {
            return self.wlock.tryLock();
        }

        pub fn unlockWrites(self: *Self) void {
            self.wlock.unlock();
        }

        /// `write` for a caller that holds `lockWrites`.  A failed write may
        /// have sent part of a frame and the stream cannot be resynchronised,
        /// so the connection is closed.
        pub fn writeHeld(self: *Self, data: []const u8) anyerror!void {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("write() not available for this connection type");
            self.op_table.write(self.ctx, data) catch |err| {
                self.close();
                return err;
            };
        }

        /// `write` of `head` followed by `body`, without joining them first.
        pub fn writeParts(self: *Self, head: []const u8, body: []const u8) anyerror!void {
            comptime if (is_wasm or contype != .ClientConnectionType) @compileError("writeParts() not available for this connection type");
            if (runtime.onLoopThread()) return self.post(&.{ head, body });
            self.wlock.lock();
            defer self.wlock.unlock();
            self.op_table.writeParts(self.ctx, head, body) catch |err| {
                self.close();
                return err;
            };
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
                if (comptime !is_wasm) {
                    self.dropOutbox();
                    self.outbox.deinit(self.allocator);
                }
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
            return try self.op_table.accept(self.ctx, timeout_ms);
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

            // macOS hands out accepted sockets with the listener's O_NONBLOCK.
            posix_net.setBlocking(conn.fd);
            // Each read and write is bounded, and so is the whole upgrade: a
            // peer trickling one byte at a time cannot hold this thread.
            stream.setIoTimeout(tls_impl.HANDSHAKE_TIMEOUT_MS);
            const deadline = @import("../misc.zig").monotonicMs() + tls_impl.HANDSHAKE_TIMEOUT_MS;

            var sync_parser = SynParser.init(self.allocator, deadline, conn.websocket_allowed_origins);
            defer sync_parser.deinit();
            const pnet_addr = posix_net.Address{};

            var ctx: *anyopaque = undefined;
            var table: OperationTable = undefined;
            var is_websocket = false;

            if (conn.ssl_ctx != null) {
                // 1. Complete the TLS handshake to get a per-connection ssl object.
                //    The SSL_CTX belongs to the ServerConnection and must not be freed here.
                const ssl_ctx: *tls_impl.SslCtx = @ptrCast(@alignCast(conn.ssl_ctx.?));
                const ssl = try tls_impl.serverHandshake(ssl_ctx, @intCast(conn.fd), deadline);
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
                stream.setReadTimeout(0);
                stream.setWriteTimeout(posix_net.SEND_STALL_TIMEOUT_MS);
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
            if (comptime @import("builtin").mode == .debug)
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

const TestPeer = struct {
    const c = @import("posix_c");
    const Conn = Connection(.ClientConnectionType);

    conn: *Conn,
    /// The far end, read by the test.
    fd: c_int,

    extern "c" fn signal(sig: c_int, handler: usize) usize;

    fn open() !TestPeer {
        // The drainer's write to a shut-down socket must fail, not kill the test.
        _ = signal(13, 1); // SIGPIPE, SIG_IGN
        var fds: [2]c_int = undefined;
        try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
        const ctx = try ClientConnection.initFromAccepted(std.testing.allocator, fds[0]);
        // Stream.close() releases a descriptor this socketpair never counted.
        @import("../nofile.zig").acquire(1);
        // Bound a write if the far end is not reading, so a stuck drainer
        // fails the test instead of hanging the suite.
        ctx.stream.setWriteTimeout(2000);
        const conn = try std.testing.allocator.create(Conn);
        conn.* = .{ .ctx = ctx, .op_table = ClientConnection.op_table, .allocator = std.testing.allocator };
        return .{ .conn = conn, .fd = fds[1] };
    }

    fn draining(self: TestPeer) bool {
        self.conn.outbox_mutex.lock();
        defer self.conn.outbox_mutex.unlock();
        return self.conn.outbox_draining;
    }

    fn waitDrained(self: TestPeer) !void {
        const deadline = misc.monotonicMs() + 5_000;
        while (self.draining()) {
            try std.testing.expect(misc.monotonicMs() < deadline);
            std.Thread.yield() catch {};
        }
        // The drainer drops its reference just after it stops draining.
        while (self.conn.refcount.load(.acquire) > 1) {
            try std.testing.expect(misc.monotonicMs() < deadline);
            std.Thread.yield() catch {};
        }
    }

    /// Wait for the drainer to finish, then free everything.
    fn close(self: TestPeer) !void {
        try self.waitDrained();
        self.conn.release();
        _ = c.close(self.fd);
    }
};

test "post does not wait for a slow peer and keeps the order of writes" {
    if (comptime is_wasm) return;
    const peer = try TestPeer.open();
    const chunk = 256 * 1024;
    const count = 32;
    var buf: [chunk]u8 = undefined;

    // Nobody reads yet: far more than the socket buffer holds is posted.
    const started = misc.monotonicMs();
    for (0..count) |i| {
        @memset(&buf, @truncate(i));
        try peer.conn.post(&.{ buf[0..16], buf[16..] });
    }
    try std.testing.expect(misc.monotonicMs() - started < 1000);
    try std.testing.expect(peer.draining());

    const Reader = struct {
        fn run(fd: c_int, out: *bool) void {
            var got: [chunk]u8 = undefined;
            for (0..count) |i| {
                var at: usize = 0;
                while (at < chunk) {
                    const n = TestPeer.c.read(fd, got[at..].ptr, chunk - at);
                    if (n <= 0) return;
                    at += @intCast(n);
                }
                for (got) |b| if (b != @as(u8, @truncate(i))) return;
            }
            out.* = true;
        }
    };
    var in_order = false;
    const reader = try std.Thread.spawn(.{}, Reader.run, .{ peer.fd, &in_order });
    reader.join();
    try std.testing.expect(in_order);
    try peer.close();
}

test "post closes a peer that stops reading once max_outbox_bytes are queued" {
    if (comptime is_wasm) return;
    const peer = try TestPeer.open();
    const chunk = try std.testing.allocator.alloc(u8, 1024 * 1024);
    defer std.testing.allocator.free(chunk);
    @memset(chunk, 1);

    // Fill the outbox without a drainer so the cap is what we measure, not
    // a race against a write that times out.
    peer.conn.outbox_mutex.lock();
    var posted: usize = 0;
    const err = while (posted <= max_outbox_bytes + chunk.len) {
        peer.conn.enqueue(&.{chunk}, 0) catch |e| break e;
        posted += chunk.len;
    } else error.TestUnexpectedResult;
    peer.conn.outbox_mutex.unlock();
    try std.testing.expectEqual(error.OutboxFull, err);
    try std.testing.expect(posted >= max_outbox_bytes);
    try std.testing.expect(peer.conn.isSuspended());
    try peer.close();
}

test "post closes when enqueue fails after a partial write" {
    // Regression: a non-zero skip followed by enqueue failure used to unlock
    // the write gate without close(), leaving the wire mid-frame.
    if (comptime is_wasm) return;
    const peer = try TestPeer.open();
    const chunk = try std.testing.allocator.alloc(u8, 1024 * 1024);
    defer std.testing.allocator.free(chunk);
    @memset(chunk, 7);

    // Nearly fill the outbox with no drainer, leaving less room than one chunk.
    peer.conn.outbox_mutex.lock();
    while (peer.conn.outbox_bytes + chunk.len <= max_outbox_bytes) {
        try peer.conn.enqueue(&.{chunk}, 0);
    }
    peer.conn.outbox_mutex.unlock();

    // Saturate the kernel send buffer so the next post() cannot send everything.
    while (true) {
        const n = peer.conn.op_table.writeNonBlocking(peer.conn.ctx, chunk) catch break;
        if (n < chunk.len) break;
    }

    const result = peer.conn.post(&.{chunk});
    try std.testing.expectError(error.OutboxFull, result);
    try std.testing.expect(peer.conn.isSuspended());
    try peer.close();
}
