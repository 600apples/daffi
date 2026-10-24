//! Minimal POSIX/C-socket networking — replaces std.net (removed in Zig 0.16).
//! Requires linking with libc (-lc).

const c = @import("posix_c");

// ── fcntl — declared manually to avoid glibc bits/fcntl2.h ──────────────────
const F_GETFL: c_int = 3;
const F_SETFL: c_int = 4;
/// O_NONBLOCK: 0x800 on Linux/x86-64 and most Linux arches; 0x4 on Darwin.
const O_NONBLOCK: c_int = switch (@import("builtin").target.os.tag) {
    .macos, .ios, .watchos, .tvos, .visionos => 0x0004,
    else => 0x0800,
};
extern "c" fn fcntl(fd: c_int, cmd: c_int, ...) c_int;

const F_SETFD: c_int = 2;
const FD_CLOEXEC: c_int = 1;

/// Mark *fd* close-on-exec so sockets are not inherited by subprocesses the
/// host application spawns (an inherited copy would keep the connection alive
/// after we close ours).
fn setCloexec(fd: c_int) void {
    _ = fcntl(fd, F_SETFD, FD_CLOEXEC);
}

// ── TCP keepalive + user timeout — declared manually ─────────────────────────
const IPPROTO_TCP: c_int = 6;

/// TCP_KEEPIDLE (Linux) / TCP_KEEPALIVE (Darwin): seconds of inactivity before
/// the kernel sends the first keepalive probe.
const TCP_KEEPIDLE: c_int = switch (@import("builtin").target.os.tag) {
    .macos, .ios, .watchos, .tvos, .visionos => 0x10,
    else => 4,
};
/// TCP_KEEPINTVL: seconds between consecutive keepalive probes.
const TCP_KEEPINTVL: c_int = switch (@import("builtin").target.os.tag) {
    .macos, .ios, .watchos, .tvos, .visionos => 0x101,
    else => 5,
};
/// TCP_KEEPCNT: number of unanswered probes before the connection is declared dead.
const TCP_KEEPCNT: c_int = switch (@import("builtin").target.os.tag) {
    .macos, .ios, .watchos, .tvos, .visionos => 0x102,
    else => 6,
};
/// TCP_USER_TIMEOUT (Linux only, value 18): max milliseconds any transmitted
/// data may remain unacknowledged before the kernel aborts the connection.
/// This covers the active-traffic case (data in-flight but no ACKs) where
/// keepalive probes are never sent because the connection is not idle.
const TCP_USER_TIMEOUT: c_int = 18;  // Linux; ignored on other platforms
/// TCP_NODELAY (value 1 on all POSIX platforms): disable Nagle's algorithm.
/// Without this, the kernel coalesces small writes into larger TCP segments,
/// introducing up to ~200 ms of latency per round-trip — fatal for interactive
/// terminal use where each keystroke is a tiny payload.
const TCP_NODELAY: c_int = 1;

/// Apply dead-connection detection to *fd*.
///
/// Two complementary mechanisms are used so both idle and active-traffic
/// scenarios are covered with a ~25 s worst-case detection time:
///
/// 1. **TCP keepalive** — fires when the connection is idle (no data in-flight).
///    idle=10 s → first probe; every 5 s; give up after 3 probes (25 s total).
///
/// 2. **TCP_USER_TIMEOUT** (Linux only) — caps how long unacknowledged data
///    may sit in-flight before the kernel forcibly closes the socket.  Without
///    this, actively sending data to a dead peer triggers TCP retransmissions
///    for up to ~15 minutes before the kernel gives up.  Set to 25 000 ms so
///    both idle and active paths detect failures in roughly the same window.
fn applyKeepalive(fd: c_int) void {
    const on:   c_int = 1;
    const idle: c_int = 10;
    const intvl: c_int = 5;
    const cnt:  c_int = 3;
    _ = c.setsockopt(fd, IPPROTO_TCP,  TCP_NODELAY,    &on,   @sizeOf(c_int));
    _ = c.setsockopt(fd, c.SOL_SOCKET, c.SO_KEEPALIVE, &on,   @sizeOf(c_int));
    _ = c.setsockopt(fd, IPPROTO_TCP,  TCP_KEEPIDLE,   &idle, @sizeOf(c_int));
    _ = c.setsockopt(fd, IPPROTO_TCP,  TCP_KEEPINTVL,  &intvl,@sizeOf(c_int));
    _ = c.setsockopt(fd, IPPROTO_TCP,  TCP_KEEPCNT,    &cnt,  @sizeOf(c_int));
    // TCP_USER_TIMEOUT is Linux-specific; the setsockopt silently fails on
    // other platforms, so it is safe to call unconditionally.
    const user_timeout: c_int = 25_000;  // milliseconds
    _ = c.setsockopt(fd, IPPROTO_TCP, TCP_USER_TIMEOUT, &user_timeout, @sizeOf(c_int));
}

// ── poll — declared manually ─────────────────────────────────────────────────
const POLLIN: c_short = 1;
const POLLOUT: c_short = 4;
pub const PollFd = extern struct {
    fd:      c_int,
    events:  c_short,
    revents: c_short,
};
extern "c" fn poll(fds: [*]PollFd, nfds: c_uint, timeout: c_int) c_int;

pub const WAIT_READ: c_short = POLLIN;
pub const WAIT_WRITE: c_short = POLLOUT;

/// Block until *fd* is ready for `events` (WAIT_READ / WAIT_WRITE), a hang-up
/// or error is reported, or `timeout_ms` elapses (-1 = forever).
/// Returns false only on timeout.  Used by the TLS layer, which runs its
/// sockets in non-blocking mode so that reader and writer threads can share
/// one SSL object under a mutex.
pub fn waitFd(fd: c_int, events: c_short, timeout_ms: c_int) bool {
    var pfd = PollFd{ .fd = fd, .events = events, .revents = 0 };
    while (true) {
        const n = poll(@as([*]PollFd, @ptrCast(&pfd)), 1, timeout_ms);
        if (n > 0) return true;
        if (n == 0) return false;
        if (Stream.lastErrno() != .INTR) return true; // let the I/O call report the error
    }
}

/// Put *fd* into non-blocking mode.
pub fn setNonBlocking(fd: c_int) void {
    const flags = fcntl(fd, F_GETFL, @as(c_int, 0));
    if (flags >= 0) _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

const std = @import("std");
const posix = std.posix;
const Allocator = std.mem.Allocator;


pub const Address = struct {
    // sizeof(sockaddr_storage): must hold a sockaddr_un (106/110 bytes), not just
    // a sockaddr_in6 (28), or long Unix-socket paths are truncated and the
    // casts to `*const sockaddr_un` read past the end of the buffer.
    bytes: [128]u8 align(8) = @splat(0),
    family: u16 = 0,
    port: u16 = 0,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (self.family == c.AF_INET) {
            const sa4: *const c.sockaddr_in = @ptrCast(@alignCast(&self.bytes));
            const ip = std.mem.bigToNative(u32, sa4.sin_addr.s_addr);
            try writer.print("{d}.{d}.{d}.{d}:{d}", .{
                (ip >> 24) & 0xff, (ip >> 16) & 0xff, (ip >> 8) & 0xff, ip & 0xff,
                self.port,
            });
        } else if (self.family == c.AF_INET6) {
            try writer.print("<ipv6>:{d}", .{self.port});
        } else if (self.family == c.AF_UNIX) {
            const sun: *const c.sockaddr_un = @ptrCast(@alignCast(&self.bytes));
            try writer.print("unix:{s}", .{std.mem.sliceTo(&sun.sun_path, 0)});
        } else {
            try writer.writeAll("<addr>");
        }
    }

    pub fn initUnix(path: []const u8) !Address {
        var sun: c.sockaddr_un = std.mem.zeroes(c.sockaddr_un);
        sun.sun_family = c.AF_UNIX;
        if (path.len >= sun.sun_path.len) return error.NameTooLong;
        @memcpy(sun.sun_path[0..path.len], path);
        var addr = Address{ .family = c.AF_UNIX };
        const len = @min(@sizeOf(c.sockaddr_un), addr.bytes.len);
        @memcpy(addr.bytes[0..len], std.mem.asBytes(&sun)[0..len]);
        return addr;
    }

    pub fn listen(self: *const Address, options: ListenOptions) !Server {
        return listenOn(self, options);
    }
};


comptime {
    std.debug.assert(@sizeOf(c.sockaddr_un) <= @sizeOf(@FieldType(Address, "bytes")));
    std.debug.assert(@sizeOf(c.sockaddr_in6) <= @sizeOf(@FieldType(Address, "bytes")));
}

pub const Stream = struct {
    handle: posix.socket_t,

    fn lastErrno() std.c.E {
        return @fromBackingInt(@intCast(std.c._errno().*));
    }

    pub fn read(self: Stream, buf: []u8) !usize {
        while (true) {
            const result = c.read(self.handle, buf.ptr, buf.len);
            if (result >= 0) return @intCast(result);
            switch (lastErrno()) {
                .INTR => continue,
                // SO_RCVTIMEO expired.
                .AGAIN => return error.Timeout,
                else => return error.ReadError,
            }
        }
    }

    pub fn readAll(self: Stream, buf: []u8) !usize {
        var total: usize = 0;
        while (total < buf.len) {
            const n = try self.read(buf[total..]);
            if (n == 0) break;
            total += n;
        }
        return total;
    }

    pub fn write(self: Stream, data: []const u8) !usize {
        while (true) {
            const result = c.write(self.handle, data.ptr, data.len);
            if (result >= 0) return @intCast(result);
            switch (lastErrno()) {
                .INTR => continue,
                else => return error.WriteError,
            }
        }
    }

    pub fn writeAll(self: Stream, data: []const u8) !void {
        var sent: usize = 0;
        while (sent < data.len) {
            sent += try self.write(data[sent..]);
        }
    }

    /// Set (or, with 0, clear) the receive and send timeouts of the socket.
    pub fn setIoTimeout(self: Stream, ms: u32) void {
        const tv = posix.timeval{
            .sec = @intCast(ms / 1000),
            .usec = @intCast((ms % 1000) * 1000),
        };
        _ = c.setsockopt(self.handle, c.SOL_SOCKET, c.SO_RCVTIMEO, &tv, @sizeOf(posix.timeval));
        _ = c.setsockopt(self.handle, c.SOL_SOCKET, c.SO_SNDTIMEO, &tv, @sizeOf(posix.timeval));
    }

    /// Shut both directions down *without* releasing the descriptor.
    ///
    /// This is the only thing that is safe to do to a socket while another
    /// thread may be blocked in read()/write() on it: the blocked call returns
    /// immediately, and the descriptor number cannot be recycled by an
    /// unrelated open() until `close()` is called by the (single) owner.
    /// Idempotent.
    pub fn shutdown(self: Stream) void {
        _ = c.shutdown(self.handle, c.SHUT_RDWR);
    }

    /// Shut down and release the descriptor.  Must be called exactly once,
    /// when no other thread can still be using the socket.
    pub fn close(self: Stream) void {
        self.shutdown();
        _ = c.close(self.handle);
    }
};

/// Maximum time (ms) to wait for a TCP connect() to complete.
/// Overrides the kernel's default retransmission timeout (~75 s on Linux).
const CONNECT_TIMEOUT_MS: c_int = 15_000;

pub fn tcpConnectToHost(_: Allocator, host: []const u8, port: u16) !Stream {
    var port_buf: [8]u8 = undefined;
    const port_str = std.fmt.bufPrintSentinel(&port_buf, "{d}", .{port}, 0) catch return error.BadPort;

    var hints: c.addrinfo = std.mem.zeroes(c.addrinfo);
    hints.ai_family = c.AF_UNSPEC;
    hints.ai_socktype = c.SOCK_STREAM;

    var host_buf: [256]u8 = undefined;
    if (host.len >= host_buf.len) return error.NameTooLong;
    @memcpy(host_buf[0..host.len], host);
    host_buf[host.len] = 0;

    var res: ?*c.addrinfo = null;
    if (c.getaddrinfo(&host_buf, port_str.ptr, &hints, &res) != 0) return error.UnknownHostName;
    defer if (res) |r| c.freeaddrinfo(r);

    var it = res;
    while (it) |rp| : (it = rp.ai_next) {
        const fd = c.socket(rp.ai_family, rp.ai_socktype, rp.ai_protocol);
        if (fd < 0) continue;
        setCloexec(fd);

        // Switch to non-blocking so connect() returns immediately instead of
        // blocking for the kernel's full retransmission timeout (~75 s).
        const orig_flags = fcntl(fd, F_GETFL, @as(c_int, 0));
        _ = fcntl(fd, F_SETFL, orig_flags | O_NONBLOCK);

        const rc = c.connect(fd, rp.ai_addr, rp.ai_addrlen);
        if (rc == 0) {
            // Rare fast path: connected synchronously (e.g. loopback).
            _ = fcntl(fd, F_SETFL, orig_flags);
            applyKeepalive(fd);
            return Stream{ .handle = fd };
        }

        // For non-blocking sockets, EINPROGRESS means "in progress" — use
        // poll() to wait up to CONNECT_TIMEOUT_MS for the result.
        // Any other errno (ECONNREFUSED, ENETUNREACH, …) causes poll() to
        // return immediately with POLLERR, so SO_ERROR will be non-zero and
        // we fall through to the failure path below without extra errno checks.
        var pfd = PollFd{ .fd = fd, .events = POLLOUT, .revents = 0 };
        const nready = poll(@as([*]PollFd, @ptrCast(&pfd)), 1, CONNECT_TIMEOUT_MS);
        if (nready <= 0) {
            // 0 = timeout, -1 = poll error.
            _ = c.close(fd);
            continue;
        }

        // Check the async connect outcome.
        var so_err: c_int = 0;
        var so_len: c.socklen_t = @sizeOf(c_int);
        _ = c.getsockopt(fd, c.SOL_SOCKET, c.SO_ERROR, &so_err, &so_len);
        if (so_err != 0) {
            _ = c.close(fd);
            continue;
        }

        // Restore blocking mode for normal send/recv I/O.
        _ = fcntl(fd, F_SETFL, orig_flags);
        applyKeepalive(fd);
        return Stream{ .handle = fd };
    }
    return error.ConnectionRefused;
}

pub fn connectUnixSocket(path: []const u8) !Stream {
    var sun: c.sockaddr_un = std.mem.zeroes(c.sockaddr_un);
    sun.sun_family = c.AF_UNIX;
    if (path.len >= sun.sun_path.len) return error.NameTooLong;
    @memcpy(sun.sun_path[0..path.len], path);

    const fd = c.socket(c.AF_UNIX, c.SOCK_STREAM, 0);
    if (fd < 0) return error.SocketCreateFailed;
    setCloexec(fd);

    if (c.connect(fd, @ptrCast(&sun), @sizeOf(c.sockaddr_un)) != 0) {
        _ = c.close(fd);
        return error.ConnectionRefused;
    }
    return Stream{ .handle = fd };
}


pub const AddressList = struct {
    addrs: []Address,
    allocator: Allocator,

    pub fn deinit(self: *AddressList) void {
        self.allocator.free(self.addrs);
        self.allocator.destroy(self);
    }
};

pub fn getAddressList(allocator: Allocator, host: []const u8, port: u16) !*AddressList {
    var port_buf: [8]u8 = undefined;
    const port_str = std.fmt.bufPrintSentinel(&port_buf, "{d}", .{port}, 0) catch return error.BadPort;

    var hints: c.addrinfo = std.mem.zeroes(c.addrinfo);
    hints.ai_family = c.AF_UNSPEC;
    hints.ai_socktype = c.SOCK_STREAM;

    var host_buf: [256]u8 = undefined;
    if (host.len >= host_buf.len) return error.NameTooLong;
    @memcpy(host_buf[0..host.len], host);
    host_buf[host.len] = 0;

    var res: ?*c.addrinfo = null;
    if (c.getaddrinfo(&host_buf, port_str.ptr, &hints, &res) != 0) return error.UnknownHostName;
    defer if (res) |r| c.freeaddrinfo(r);

    var count: usize = 0;
    var it = res;
    while (it) |rp| : (it = rp.ai_next) count += 1;

    const addrs = try allocator.alloc(Address, count);
    const list = try allocator.create(AddressList);
    list.* = .{ .addrs = addrs, .allocator = allocator };

    var idx: usize = 0;
    it = res;
    while (it) |rp| : (it = rp.ai_next) {
        var addr = Address{ .family = @intCast(rp.ai_family), .port = port };
        const len = @min(@sizeOf(Address), rp.ai_addrlen);
        @memcpy(addr.bytes[0..len], @as([*]const u8, @ptrCast(rp.ai_addr.?))[0..len]);
        addrs[idx] = addr;
        idx += 1;
    }
    return list;
}


pub const ListenOptions = struct {
    kernel_backlog: u31 = 128,
    reuse_address: bool = true,
};

pub const ServerConn = struct {
    stream: Stream,
    address: Address,
};

pub const Server = struct {
    handle: posix.socket_t,
    listen_address: Address,

    /// Wait up to `timeout_ms` for an inbound connection.  Returns
    /// `error.Timeout` when none arrived, so callers can re-check a shutdown
    /// flag; closing a listening fd from another thread does not reliably wake a
    /// blocked accept() on all platforms.
    pub fn acceptTimeout(self: *Server, timeout_ms: c_int) !ServerConn {
        var pfd = PollFd{ .fd = self.handle, .events = POLLIN, .revents = 0 };
        const n = poll(@as([*]PollFd, @ptrCast(&pfd)), 1, timeout_ms);
        if (n == 0) return error.Timeout;
        if (n < 0) {
            if (Stream.lastErrno() == .INTR) return error.Timeout;
            return error.AcceptError;
        }
        return self.accept();
    }

    pub fn accept(self: *Server) !ServerConn {
        var addr_storage: c.sockaddr_storage = std.mem.zeroes(c.sockaddr_storage);
        var addr_len: c.socklen_t = @sizeOf(c.sockaddr_storage);
        const fd = c.accept(self.handle, @ptrCast(&addr_storage), &addr_len);
        if (fd < 0) {
            return switch (Stream.lastErrno()) {
                .INTR, .CONNABORTED, .AGAIN => error.Timeout,
                else => error.AcceptError,
            };
        }
        setCloexec(fd);
        applyKeepalive(fd);

        var addr = Address{ .family = addr_storage.ss_family };
        const copy_len = @min(@sizeOf(Address), addr_len);
        @memcpy(addr.bytes[0..copy_len], std.mem.asBytes(&addr_storage)[0..copy_len]);
        if (addr_storage.ss_family == c.AF_INET) {
            const sa4: *const c.sockaddr_in = @ptrCast(&addr_storage);
            addr.port = std.mem.bigToNative(u16, sa4.sin_port);
        } else if (addr_storage.ss_family == c.AF_INET6) {
            const sa6: *const c.sockaddr_in6 = @ptrCast(&addr_storage);
            addr.port = std.mem.bigToNative(u16, sa6.sin6_port);
        }
        return ServerConn{ .stream = .{ .handle = fd }, .address = addr };
    }

    pub fn deinit(self: *Server) void {
        _ = c.close(self.handle);
    }
};

fn listenOn(addr: *const Address, options: ListenOptions) !Server {
    const family: c_int = @intCast(addr.family);
    const fd = c.socket(family, c.SOCK_STREAM, 0);
    if (fd < 0) return error.SocketCreateFailed;
    setCloexec(fd);

    if (options.reuse_address) {
        const opt: c_int = 1;
        _ = c.setsockopt(fd, c.SOL_SOCKET, c.SO_REUSEADDR, &opt, @sizeOf(c_int));
    }

    const sa: *const c.sockaddr = @ptrCast(@alignCast(&addr.bytes));
    const sa_len: c.socklen_t = switch (addr.family) {
        c.AF_INET => @sizeOf(c.sockaddr_in),
        c.AF_INET6 => @sizeOf(c.sockaddr_in6),
        c.AF_UNIX => @sizeOf(c.sockaddr_un),
        else => @sizeOf(c.sockaddr_storage),
    };

    if (c.bind(fd, sa, sa_len) != 0) {
        _ = c.close(fd);
        return error.AddressInUse;
    }
    if (c.listen(fd, options.kernel_backlog) != 0) {
        _ = c.close(fd);
        return error.ListenError;
    }
    return Server{ .handle = fd, .listen_address = addr.* };
}
