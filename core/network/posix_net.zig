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

/// Darwin ignores MSG_DONTWAIT on send, so a blocking socket is flipped
/// non-blocking for the call.  Evented sockets already are; skip the dance.
const darwinNonblock = struct {
    const darwin = @import("builtin").target.os.tag.isDarwin();

    const Guard = struct {
        fd: c_int,
        restore: ?c_int,

        fn leave(self: @This()) void {
            if (self.restore) |flags| _ = fcntl(self.fd, F_SETFL, flags);
        }
    };

    fn enter(fd: c_int) ?Guard {
        if (!darwin) return .{ .fd = fd, .restore = null };
        const flags = fcntl(fd, F_GETFL, @as(c_int, 0));
        if (flags < 0) return null;
        if (flags & O_NONBLOCK != 0) return .{ .fd = fd, .restore = null };
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK);
        return .{ .fd = fd, .restore = flags };
    }
};

/// Keeps a write to a closed peer an error instead of a SIGPIPE.  Linux takes
/// it per call; Darwin has no such flag, so sockets get SO_NOSIGPIPE instead
/// (see `setNoSigpipe`).
pub const no_sigpipe: c_int = if (@import("builtin").target.os.tag == .linux) std.c.MSG.NOSIGNAL else 0;

const F_SETFD: c_int = 2;
const FD_CLOEXEC: c_int = 1;

/// Mark *fd* close-on-exec so sockets are not inherited by subprocesses the
/// host application spawns (an inherited copy would keep the connection alive
/// after we close ours).
fn setCloexec(fd: c_int) void {
    _ = fcntl(fd, F_SETFD, FD_CLOEXEC);
}

/// Darwin counterpart of `no_sigpipe`: a write to a closed peer fails with
/// EPIPE instead of killing a host that does not ignore SIGPIPE.
fn setNoSigpipe(fd: c_int) void {
    if (comptime !@import("builtin").target.os.tag.isDarwin()) return;
    const SO_NOSIGPIPE: c_int = 0x1022;
    const on: c_int = 1;
    _ = c.setsockopt(fd, c.SOL_SOCKET, SO_NOSIGPIPE, &on, @sizeOf(c_int));
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
pub extern "c" fn poll(fds: [*]PollFd, nfds: c_uint, timeout: c_int) c_int;

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

pub fn setBlocking(fd: c_int) void {
    const flags = fcntl(fd, F_GETFL, @as(c_int, 0));
    if (flags >= 0 and flags & O_NONBLOCK != 0) _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK);
}

pub fn isNonBlocking(fd: c_int) bool {
    const flags = fcntl(fd, F_GETFL, @as(c_int, 0));
    return flags >= 0 and flags & O_NONBLOCK != 0;
}

/// A write to an accepted peer that makes no progress for this long fails,
/// and the connection is dropped.
pub const SEND_STALL_TIMEOUT_MS: u32 = 5_000;

const std = @import("std");
const nofile = @import("../nofile.zig");
const misc = @import("../misc.zig");

/// Progress a writer must keep up over a long stretch of writes.  The stall
/// timeout only bounds each wait, so a peer that reads a few bytes every few
/// seconds would otherwise hold the writing thread for as long as it likes.
pub const WriteProgress = struct {
    window_ms: i64,
    min_bytes: usize,
    /// Monotonic ms by which `min_bytes` more must have been sent.
    deadline: i64,
    credit: usize = 0,

    pub fn init(window_ms: i64, min_bytes: usize) WriteProgress {
        return .{ .window_ms = window_ms, .min_bytes = min_bytes, .deadline = misc.monotonicMs() + window_ms };
    }

    fn note(self: *WriteProgress, n: usize) void {
        self.credit += n;
        if (self.credit < self.min_bytes) return;
        self.credit = 0;
        self.deadline = misc.monotonicMs() + self.window_ms;
    }
};

/// Set by a thread for the duration of a backlog drain: every `Stream` and
/// TLS write it makes then counts towards it and fails with a timeout once
/// the deadline passes.
pub threadlocal var write_progress: ?*WriteProgress = null;

pub fn noteWritten(n: usize) void {
    if (write_progress) |p| p.note(n);
}

/// How long a writer may wait for the socket to drain: the stall timeout,
/// cut short by the calling thread's `write_progress`; null once that has
/// run out.
pub fn writeWaitBudget() ?c_int {
    const cap: c_int = @intCast(SEND_STALL_TIMEOUT_MS);
    const p = write_progress orelse return cap;
    const left = p.deadline - misc.monotonicMs();
    if (left <= 0) return null;
    return @intCast(@min(left, cap));
}

/// Last connect/listen/accept failure on this thread. `Client.init` fails
/// with a coarse Zig error (`ConnectionRefused`, `SocketCreateFailed`); the
/// OS reason (EMFILE, ECONNREFUSED, timeout) lives here so Python can put it
/// in the traceback. Cleared at the start of each attempt.
threadlocal var fail_buf: [160]u8 = undefined;
threadlocal var fail_len: usize = 0;

pub fn noteOsFailure(what: []const u8) void {
    noteErrno(what);
}

fn noteErrno(what: []const u8) void {
    noteCode(what, std.c._errno().*);
}

fn noteCode(what: []const u8, code: c_int) void {
    const label = errnoLabel(code);
    const msg = if (label.len == 0)
        std.fmt.bufPrint(&fail_buf, "{s}: errno {d}", .{ what, code }) catch what
    else
        std.fmt.bufPrint(&fail_buf, "{s}: {s} (errno {d})", .{ what, label, code }) catch what;
    fail_len = msg.len;
}

fn noteLiteral(text: []const u8) void {
    const n = @min(text.len, fail_buf.len);
    @memcpy(fail_buf[0..n], text[0..n]);
    fail_len = n;
}

fn errnoLabel(code: c_int) []const u8 {
    const names = .{
        "EPERM",         "ENOENT",       "ENOMEM",       "EACCES",      "EINVAL",
        "ENFILE",        "EMFILE",       "ENOSPC",       "EPIPE",       "EADDRINUSE",
        "EADDRNOTAVAIL", "ECONNRESET",   "ENOBUFS",      "ETIMEDOUT",   "ECONNREFUSED",
        "EHOSTDOWN",     "EHOSTUNREACH", "ENETUNREACH",  "ENETDOWN",    "EAFNOSUPPORT",
    };
    inline for (names) |name| {
        if (code == @field(c, name)) return name;
    }
    return "";
}

pub fn connectFailure() []const u8 {
    return fail_buf[0..fail_len];
}

pub fn clearConnectFailure() void {
    fail_len = 0;
}

pub fn setConnectFailure(text: []const u8) void {
    const n = @min(text.len, fail_buf.len);
    @memcpy(fail_buf[0..n], text[0..n]);
    fail_len = n;
}

fn isFileLimit(code: c_int) bool {
    return code == 23 or code == 24;
}
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

/// Most slices one gathered write takes.
pub const max_vec = 32;

/// The unsent rest of a gathered write.
const IoVecs = struct {
    iov: [max_vec]c.struct_iovec = undefined,
    first: usize = 0,
    len: usize = 0,

    fn init(parts: []const []const u8) !IoVecs {
        var self = IoVecs{};
        for (parts) |part| {
            if (part.len == 0) continue;
            if (self.len == max_vec) return error.TooManyParts;
            self.iov[self.len] = .{ .iov_base = @constCast(part.ptr), .iov_len = part.len };
            self.len += 1;
        }
        return self;
    }

    fn done(self: *const IoVecs) bool {
        return self.first == self.len;
    }

    fn send(self: *IoVecs, fd: c_int, flags: c_int) isize {
        var msg = std.mem.zeroes(c.struct_msghdr);
        msg.msg_iov = &self.iov[self.first];
        msg.msg_iovlen = @intCast(self.len - self.first);
        return c.sendmsg(fd, &msg, flags);
    }

    fn advance(self: *IoVecs, sent: usize) void {
        var n = sent;
        while (self.first < self.len and n >= self.iov[self.first].iov_len) {
            n -= self.iov[self.first].iov_len;
            self.first += 1;
        }
        if (self.first < self.len) {
            const v = &self.iov[self.first];
            v.iov_base = @as([*]u8, @ptrCast(v.iov_base.?)) + n;
            v.iov_len -= n;
        }
    }
};

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

    /// Read whatever is available without blocking, regardless of the
    /// descriptor's mode.  Returns 0 on end-of-stream (or reset/shutdown) and
    /// `error.WouldBlock` when nothing is pending.
    pub fn readSome(self: Stream, buf: []u8) !usize {
        while (true) {
            const result = std.c.recv(self.handle, buf.ptr, buf.len, std.c.MSG.DONTWAIT);
            if (result >= 0) return @intCast(result);
            switch (lastErrno()) {
                .INTR => continue,
                .AGAIN => return error.WouldBlock,
                .CONNRESET, .NOTCONN, .PIPE, .TIMEDOUT => return 0,
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

    /// Evented sockets stay non-blocking.  `write` / `writeAllVec` from a
    /// worker then see EAGAIN when the kernel buffer is full — wait, do not
    /// treat that as SO_SNDTIMEO (which only applies to blocking sockets).
    fn waitWritable(self: Stream) !void {
        if (!isNonBlocking(self.handle)) return error.WriteTimeout;
        const budget = writeWaitBudget() orelse return error.WriteTimeout;
        if (!waitFd(self.handle, WAIT_WRITE, budget)) return error.WriteTimeout;
    }

    pub fn write(self: Stream, data: []const u8) !usize {
        while (true) {
            // A blocking send returns at SO_SNDTIMEO with what it got out,
            // so the progress deadline is checked between sends too.
            if (writeWaitBudget() == null) return error.WriteTimeout;
            const result = std.c.send(self.handle, data.ptr, data.len, no_sigpipe);
            if (result >= 0) {
                noteWritten(@intCast(result));
                return @intCast(result);
            }
            switch (lastErrno()) {
                .INTR => continue,
                .AGAIN => {
                    try self.waitWritable();
                    continue;
                },
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

    /// Send what the socket buffer takes without waiting; returns how much.
    /// The caller must be the only writer.
    pub fn writeNonBlocking(self: Stream, data: []const u8) !usize {
        const nb = darwinNonblock.enter(self.handle) orelse return 0;
        defer nb.leave();
        var sent: usize = 0;
        while (sent < data.len) {
            const result = std.c.send(self.handle, data[sent..].ptr, data.len - sent, std.c.MSG.DONTWAIT | no_sigpipe);
            if (result >= 0) {
                sent += @intCast(result);
                continue;
            }
            switch (lastErrno()) {
                .INTR => continue,
                .AGAIN => return sent,
                else => return error.WriteError,
            }
        }
        return sent;
    }

    /// `writeNonBlocking` of `head` then `body` in one sendmsg when the
    /// socket takes both.
    pub fn writeNonBlockingParts(self: Stream, head: []const u8, body: []const u8) !usize {
        return self.writeNonBlockingVec(&.{ head, body });
    }

    /// `writeNonBlocking` of `parts` back to back, gathered into as few
    /// system calls as the socket takes.
    pub fn writeNonBlockingVec(self: Stream, parts: []const []const u8) !usize {
        const nb = darwinNonblock.enter(self.handle) orelse return 0;
        defer nb.leave();
        var vec = try IoVecs.init(parts);
        var sent: usize = 0;
        while (!vec.done()) {
            const result = vec.send(self.handle, std.c.MSG.DONTWAIT | no_sigpipe);
            if (result < 0) switch (lastErrno()) {
                .INTR => continue,
                .AGAIN => return sent,
                else => return error.WriteError,
            };
            sent += @intCast(result);
            vec.advance(@intCast(result));
        }
        return sent;
    }

    /// `writeAll(head)` then `writeAll(body)` in as few system calls as the
    /// socket takes.
    pub fn writeAllParts(self: Stream, head: []const u8, body: []const u8) !void {
        return self.writeAllVec(&.{ head, body });
    }

    /// `writeAll` of every slice in `parts` (at most `max_vec`), in order.
    pub fn writeAllVec(self: Stream, parts: []const []const u8) !void {
        var vec = try IoVecs.init(parts);
        while (!vec.done()) {
            if (writeWaitBudget() == null) return error.WriteTimeout;
            const result = vec.send(self.handle, no_sigpipe);
            if (result < 0) switch (lastErrno()) {
                .INTR => continue,
                .AGAIN => {
                    try self.waitWritable();
                    continue;
                },
                else => return error.WriteError,
            };
            noteWritten(@intCast(result));
            vec.advance(@intCast(result));
        }
    }

    /// Set (or, with 0, clear) the receive and send timeouts of the socket.
    pub fn setIoTimeout(self: Stream, ms: u32) void {
        self.setReadTimeout(ms);
        self.setWriteTimeout(ms);
    }

    pub fn setReadTimeout(self: Stream, ms: u32) void {
        const tv = timeval(ms);
        _ = c.setsockopt(self.handle, c.SOL_SOCKET, c.SO_RCVTIMEO, &tv, @sizeOf(posix.timeval));
    }

    pub fn setWriteTimeout(self: Stream, ms: u32) void {
        const tv = timeval(ms);
        _ = c.setsockopt(self.handle, c.SOL_SOCKET, c.SO_SNDTIMEO, &tv, @sizeOf(posix.timeval));
    }

    fn timeval(ms: u32) posix.timeval {
        return .{ .sec = @intCast(ms / 1000), .usec = @intCast((ms % 1000) * 1000) };
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
        nofile.release(1);
    }
};

/// Maximum time (ms) to wait for a TCP connect() to complete.
/// Overrides the kernel's default retransmission timeout (~75 s on Linux).
const CONNECT_TIMEOUT_MS: c_int = 15_000;

/// Open a socket, counting it before the syscall so the soft limit grows
/// first. If the kernel still returns EMFILE/ENFILE (descriptors this
/// counter does not own), double the limit once and retry.
fn openSocket(family: c_int, socktype: c_int, protocol: c_int) !c_int {
    var grew = false;
    while (true) {
        nofile.acquire(1);
        const fd = c.socket(family, socktype, protocol);
        if (fd >= 0) return fd;
        const err = std.c._errno().*;
        nofile.release(1);
        if (!grew and isFileLimit(err) and nofile.bump()) {
            grew = true;
            continue;
        }
        noteCode("socket", err);
        return error.SocketCreateFailed;
    }
}

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

    clearConnectFailure();
    var res: ?*c.addrinfo = null;
    const gai = c.getaddrinfo(&host_buf, port_str.ptr, &hints, &res);
    if (gai != 0) {
        var gai_buf: [48]u8 = undefined;
        const text = std.fmt.bufPrint(&gai_buf, "getaddrinfo failed ({d})", .{gai}) catch "getaddrinfo failed";
        noteLiteral(text);
        return error.UnknownHostName;
    }
    defer if (res) |r| c.freeaddrinfo(r);

    var it = res;
    while (it) |rp| : (it = rp.ai_next) {
        const fd = openSocket(rp.ai_family, rp.ai_socktype, rp.ai_protocol) catch continue;
        setCloexec(fd);
        setNoSigpipe(fd);

        // Switch to non-blocking so connect() returns immediately instead of
        // blocking for the kernel's full retransmission timeout (~75 s).
        const orig_flags = fcntl(fd, F_GETFL, @as(c_int, 0));
        _ = fcntl(fd, F_SETFL, orig_flags | O_NONBLOCK);

        const rc = c.connect(fd, rp.ai_addr, rp.ai_addrlen);
        if (rc == 0) {
            // Rare fast path: connected synchronously (e.g. loopback).
            _ = fcntl(fd, F_SETFL, orig_flags);
            applyKeepalive(fd);
            clearConnectFailure();
            return Stream{ .handle = fd };
        }

        // EINPROGRESS (or EINTR, after which the attempt carries on) means the
        // outcome is pending: poll() for it.  Any other errno is final, and
        // poll() on that socket may not wake until the timeout (macOS).
        const connect_err = std.c._errno().*;
        if (connect_err != c.EINPROGRESS and connect_err != c.EINTR) {
            noteCode("connect", connect_err);
            _ = c.close(fd);
            nofile.release(1);
            continue;
        }
        var pfd = PollFd{ .fd = fd, .events = POLLOUT, .revents = 0 };
        const deadline = misc.monotonicMs() + CONNECT_TIMEOUT_MS;
        var nready: c_int = undefined;
        while (true) {
            const left: c_int = @intCast(@max(0, deadline - misc.monotonicMs()));
            nready = poll(@as([*]PollFd, @ptrCast(&pfd)), 1, left);
            if (nready >= 0 or std.c._errno().* != c.EINTR) break;
        }
        if (nready <= 0) {
            // 0 = timeout, -1 = poll error. Record it before close().
            if (nready < 0) noteErrno("poll") else noteLiteral("connect: timed out");
            _ = c.close(fd);
            nofile.release(1);
            continue;
        }

        // Check the async connect outcome.
        var so_err: c_int = 0;
        var so_len: c.socklen_t = @sizeOf(c_int);
        _ = c.getsockopt(fd, c.SOL_SOCKET, c.SO_ERROR, &so_err, &so_len);
        if (so_err != 0) {
            noteCode("connect", so_err);
            _ = c.close(fd);
            nofile.release(1);
            continue;
        }

        // Restore blocking mode for normal send/recv I/O.
        _ = fcntl(fd, F_SETFL, orig_flags);
        applyKeepalive(fd);
        clearConnectFailure();
        return Stream{ .handle = fd };
    }
    return error.ConnectionRefused;
}

/// Scheme of a host that names a Unix-domain socket: `unix:<path>`.  A host
/// without it is always resolved as a TCP host, so a name that fails to
/// resolve is never mistaken for a socket file.
pub const unix_scheme = "unix:";

/// The socket path of a `unix:<path>` host, or null for a TCP host.
pub fn unixPath(host: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, host, unix_scheme)) return null;
    return host[unix_scheme.len..];
}

/// Make way for a listener at `path`: remove a socket file left behind by a
/// server that is gone.  Refuses to remove anything that is not a socket,
/// or a socket some server still accepts on.
pub fn removeStaleSocket(path: []const u8) !void {
    var path_buf: [256]u8 = undefined;
    if (path.len >= path_buf.len) return error.NameTooLong;
    @memcpy(path_buf[0..path.len], path);
    path_buf[path.len] = 0;
    const path_z: [*:0]const u8 = @ptrCast(&path_buf);

    const is_sock = blk: {
        if (comptime @import("builtin").os.tag == .linux) {
            var stx = std.mem.zeroes(std.os.linux.Statx);
            const rc = std.os.linux.statx(
                std.os.linux.AT.FDCWD,
                path_z,
                std.os.linux.AT.SYMLINK_NOFOLLOW,
                .{ .TYPE = true, .MODE = true },
                &stx,
            );
            const signed: isize = @bitCast(rc);
            if (signed < 0) return; // absent / unreachable — bind reports it
            break :blk std.os.linux.S.ISSOCK(stx.mode);
        } else {
            var st: std.c.Stat = undefined;
            if (std.c.stat(path_z, &st) != 0) return;
            break :blk std.c.S.ISSOCK(@intCast(st.mode));
        }
    };
    if (!is_sock) {
        noteLiteral("the path exists and is not a socket");
        return error.PathAlreadyExists;
    }
    if (connectUnixSocket(path)) |live| {
        live.close();
        noteLiteral("another server is listening on this socket");
        return error.AddressInUse;
    } else |_| {}
    clearConnectFailure();
    _ = c.unlink(path_z);
}

pub fn connectUnixSocket(path: []const u8) !Stream {
    var sun: c.sockaddr_un = std.mem.zeroes(c.sockaddr_un);
    sun.sun_family = c.AF_UNIX;
    if (path.len >= sun.sun_path.len) return error.NameTooLong;
    @memcpy(sun.sun_path[0..path.len], path);

    const fd = openSocket(c.AF_UNIX, c.SOCK_STREAM, 0) catch return error.SocketCreateFailed;
    setCloexec(fd);
    setNoSigpipe(fd);

    if (c.connect(fd, @ptrCast(&sun), @sizeOf(c.sockaddr_un)) != 0) {
        noteErrno("connect");
        _ = c.close(fd);
        nofile.release(1);
        return error.ConnectionRefused;
    }
    clearConnectFailure();
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
    errdefer allocator.free(addrs);
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
        // The listening socket is non-blocking: try it directly.
        if (timeout_ms == 0) return self.accept();
        var pfd = PollFd{ .fd = self.handle, .events = POLLIN, .revents = 0 };
        const n = poll(@as([*]PollFd, @ptrCast(&pfd)), 1, timeout_ms);
        if (n == 0) return error.Timeout;
        if (n < 0) {
            if (Stream.lastErrno() == .INTR) return error.Timeout;
            noteErrno("poll");
            return error.AcceptError;
        }
        return self.accept();
    }

    pub fn accept(self: *Server) !ServerConn {
        var grew = false;
        while (true) {
            var addr_storage: c.sockaddr_storage = std.mem.zeroes(c.sockaddr_storage);
            var addr_len: c.socklen_t = @sizeOf(c.sockaddr_storage);
            nofile.acquire(1);
            const fd = c.accept(self.handle, @ptrCast(&addr_storage), &addr_len);
            if (fd < 0) {
                const err = std.c._errno().*;
                nofile.release(1);
                if (!grew and isFileLimit(err) and nofile.bump()) {
                    grew = true;
                    continue;
                }
                return switch (Stream.lastErrno()) {
                    .INTR, .CONNABORTED, .AGAIN => error.Timeout,
                    else => {
                        noteCode("accept", err);
                        return error.AcceptError;
                    },
                };
            }
            setCloexec(fd);
            setNoSigpipe(fd);
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
    }

    pub fn deinit(self: *Server) void {
        _ = c.close(self.handle);
        nofile.release(1);
    }
};

fn listenOn(addr: *const Address, options: ListenOptions) !Server {
    const family: c_int = @intCast(addr.family);
    const fd = openSocket(family, c.SOCK_STREAM, 0) catch return error.SocketCreateFailed;
    errdefer {
        _ = c.close(fd);
        nofile.release(1);
    }
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
        noteErrno("bind");
        return error.AddressInUse;
    }
    if (c.listen(fd, options.kernel_backlog) != 0) {
        noteErrno("listen");
        return error.ListenError;
    }
    // Accept loops drain the backlog until EAGAIN instead of polling first.
    setNonBlocking(fd);
    clearConnectFailure();
    return Server{ .handle = fd, .listen_address = addr.* };
}

test "writeAllParts sends head then body across partial writes" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer for (fds) |fd| {
        _ = c.close(fd);
    };
    const body = try std.testing.allocator.alloc(u8, 1 << 20);
    defer std.testing.allocator.free(body);
    for (body, 0..) |*b, i| b.* = @truncate(i *% 31);
    const out = try std.testing.allocator.alloc(u8, 5 + body.len);
    defer std.testing.allocator.free(out);

    const Reader = struct {
        fn run(fd: c_int, buf: []u8) void {
            var got: usize = 0;
            while (got < buf.len) {
                const n = c.read(fd, buf[got..].ptr, buf.len - got);
                if (n <= 0) return;
                got += @intCast(n);
            }
        }
    };
    const reader = try std.Thread.spawn(.{}, Reader.run, .{ fds[1], out });
    try (Stream{ .handle = fds[0] }).writeAllParts("head:", body);
    reader.join();
    try std.testing.expectEqualSlices(u8, "head:", out[0..5]);
    try std.testing.expectEqualSlices(u8, body, out[5..]);
}

test "writeNonBlocking returns at a full buffer and leaves the socket blocking" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer for (fds) |fd| {
        _ = c.close(fd);
    };
    // Bound the wait if the send does block, so a regression fails instead of hanging.
    const stream = Stream{ .handle = fds[0] };
    stream.setWriteTimeout(2000);
    const flags_before = fcntl(fds[0], F_GETFL, @as(c_int, 0));

    const data = try std.testing.allocator.alloc(u8, 8 << 20);
    defer std.testing.allocator.free(data);
    @memset(data, 7);
    const started = misc.monotonicMs();
    const sent = try stream.writeNonBlocking(data);
    try std.testing.expect(sent < data.len);
    try std.testing.expect(misc.monotonicMs() - started < 1000);
    try std.testing.expectEqual(flags_before, fcntl(fds[0], F_GETFL, @as(c_int, 0)));
}

test "writeNonBlocking leaves an already-nonblocking socket nonblocking" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer for (fds) |fd| {
        _ = c.close(fd);
    };
    setNonBlocking(fds[0]);
    try std.testing.expect(isNonBlocking(fds[0]));
    const sent = try (Stream{ .handle = fds[0] }).writeNonBlocking("abc");
    try std.testing.expectEqual(@as(usize, 3), sent);
    try std.testing.expect(isNonBlocking(fds[0]));
}

test "writeNonBlockingParts sends head and body in one write" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer for (fds) |fd| {
        _ = c.close(fd);
    };
    const sent = try (Stream{ .handle = fds[0] }).writeNonBlockingParts("HEAD", "BODY");
    try std.testing.expectEqual(@as(usize, 8), sent);
    var got: [8]u8 = undefined;
    try std.testing.expectEqual(@as(isize, 8), c.read(fds[1], &got, got.len));
    try std.testing.expectEqualSlices(u8, "HEADBODY", &got);
}

test "writeAllParts waits on EAGAIN when the socket is non-blocking" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer for (fds) |fd| {
        _ = c.close(fd);
    };
    setNonBlocking(fds[0]);
    const writer = Stream{ .handle = fds[0] };

    var filler: [4096]u8 = undefined;
    @memset(&filler, 0xAB);
    while (true) {
        const n = try writer.writeNonBlocking(&filler);
        if (n < filler.len) break;
    }

    const Reader = struct {
        fn run(fd: c_int) void {
            var buf: [4096]u8 = undefined;
            while (true) {
                const n = c.read(fd, &buf, buf.len);
                if (n <= 0) return;
            }
        }
    };
    const t = try std.Thread.spawn(.{}, Reader.run, .{fds[1]});
    defer t.join();

    const head = "HEAD";
    var body: [256 * 1024]u8 = undefined;
    @memset(&body, 0xCD);
    try writer.writeAllParts(head, &body);
    _ = c.shutdown(fds[0], c.SHUT_WR);
}

test "writeNonBlockingParts returns at a full buffer of a blocking socket" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer for (fds) |fd| {
        _ = c.close(fd);
    };
    const stream = Stream{ .handle = fds[0] };
    stream.setWriteTimeout(2000);
    const body = try std.testing.allocator.alloc(u8, 8 << 20);
    defer std.testing.allocator.free(body);
    @memset(body, 3);
    const started = misc.monotonicMs();
    const sent = try stream.writeNonBlockingParts("HEAD", body);
    try std.testing.expect(sent > 0 and sent < body.len + 4);
    try std.testing.expect(misc.monotonicMs() - started < 1000);
    try std.testing.expect(!isNonBlocking(fds[0]));
}

test "writeAllVec sends every part in order" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer for (fds) |fd| {
        _ = c.close(fd);
    };
    try (Stream{ .handle = fds[0] }).writeAllVec(&.{ "a", "", "bc", "def" });
    var got: [6]u8 = undefined;
    try std.testing.expectEqual(@as(isize, 6), c.read(fds[1], &got, got.len));
    try std.testing.expectEqualSlices(u8, "abcdef", &got);
    var too_many: [max_vec + 1][]const u8 = @splat("x");
    try std.testing.expectError(error.TooManyParts, (Stream{ .handle = fds[0] }).writeAllVec(&too_many));
}

test "a write to a closed peer fails instead of raising SIGPIPE" {
    const Sig = struct {
        extern "c" fn signal(sig: c_int, handler: usize) usize;
    };
    const previous = Sig.signal(13, 0); // SIGPIPE, SIG_DFL: a regression kills the test run
    defer _ = Sig.signal(13, previous);
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer _ = c.close(fds[0]);
    _ = c.close(fds[1]);
    const stream = Stream{ .handle = fds[0] };
    try std.testing.expectError(error.WriteError, stream.writeAll("x"));
    try std.testing.expectError(error.WriteError, stream.writeAllParts("a", "b"));
    try std.testing.expectError(error.WriteError, stream.writeNonBlockingParts("a", "b"));
}

test "write_progress fails a write the peer reads too slowly" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer for (fds) |fd| {
        _ = c.close(fd);
    };
    setNonBlocking(fds[0]);
    const data = try std.testing.allocator.alloc(u8, 8 << 20);
    defer std.testing.allocator.free(data);
    @memset(data, 9);

    var progress = WriteProgress.init(200, data.len);
    write_progress = &progress;
    defer write_progress = null;
    const started = misc.monotonicMs();
    try std.testing.expectError(error.WriteTimeout, (Stream{ .handle = fds[0] }).writeAllParts("", data));
    const took = misc.monotonicMs() - started;
    try std.testing.expect(took >= 150 and took < 2000);
}

test "getAddressList frees what it allocated when a later allocation fails" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    try std.testing.expectError(error.OutOfMemory, getAddressList(failing.allocator(), "127.0.0.1", 80));
    const list = try getAddressList(std.testing.allocator, "127.0.0.1", 80);
    defer list.deinit();
    try std.testing.expect(list.addrs.len >= 1);
}
