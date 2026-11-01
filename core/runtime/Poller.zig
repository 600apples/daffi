//! Readiness notification for the event loop: kqueue on macOS/BSD, epoll on
//! Linux.  Only read interest is needed — writes stay blocking in both
//! runtimes.  Level-triggered: a descriptor keeps being reported
//! while it has unread data (or a pending EOF), so a callback may consume
//! input in bounded chunks.

const std = @import("std");
const builtin = @import("builtin");
const c = std.c;
const nofile = @import("../nofile.zig");
const net = @import("../network/posix_net.zig");
const log = std.log.scoped(.poller);

const os_tag = builtin.target.os.tag;
const use_kqueue = os_tag.isDarwin() or os_tag.isBSD();
const use_epoll = os_tag == .linux;

comptime {
    if (!use_kqueue and !use_epoll) @compileError("the evented runtime needs kqueue or epoll");
}

const Poller = @This();

pub const max_events = 128;

const RawEvent = if (use_kqueue) c.Kevent else c.epoll_event;

fd: c_int,
events: [max_events]RawEvent = undefined,

pub fn init() !Poller {
    var grew = false;
    while (true) {
        nofile.acquire(1);
        const fd = if (use_kqueue) c.kqueue() else c.epoll_create1(std.os.linux.EPOLL.CLOEXEC);
        if (fd >= 0) {
            net.clearConnectFailure();
            return .{ .fd = fd };
        }
        const err = c._errno().*;
        net.noteOsFailure(if (use_kqueue) "kqueue" else "epoll_create1");
        nofile.release(1);
        if (!grew and (err == 23 or err == 24) and nofile.bump()) {
            grew = true;
            continue;
        }
        return error.PollerInitFailed;
    }
}

pub fn deinit(self: *Poller) void {
    _ = c.close(self.fd);
    nofile.release(1);
}

/// Watch `fd` for readability (including EOF/hang-up); `udata` is handed back
/// by `wait`.  Thread-safe.
pub fn add(self: *Poller, fd: c_int, udata: usize) !void {
    if (use_kqueue) {
        const change = c.Kevent{
            .ident = @intCast(fd),
            .filter = c.EVFILT.READ,
            .flags = c.EV.ADD | c.EV.ENABLE,
            .fflags = 0,
            .data = 0,
            .udata = udata,
        };
        var none: c.Kevent = undefined;
        if (c.kevent(self.fd, @ptrCast(&change), 1, @ptrCast(&none), 0, null) < 0) {
            net.noteOsFailure("kevent");
            return error.PollerAddFailed;
        }
    } else {
        const EPOLL = std.os.linux.EPOLL;
        var ev = c.epoll_event{ .events = EPOLL.IN | EPOLL.RDHUP, .data = .{ .ptr = udata } };
        if (c.epoll_ctl(self.fd, EPOLL.CTL_ADD, fd, &ev) != 0) {
            net.noteOsFailure("epoll_ctl");
            return error.PollerAddFailed;
        }
    }
}

/// Stop watching `fd`.  Must happen before the descriptor is closed.
pub fn remove(self: *Poller, fd: c_int) void {
    if (use_kqueue) {
        const change = c.Kevent{
            .ident = @intCast(fd),
            .filter = c.EVFILT.READ,
            .flags = c.EV.DELETE,
            .fflags = 0,
            .data = 0,
            .udata = 0,
        };
        var none: c.Kevent = undefined;
        _ = c.kevent(self.fd, @ptrCast(&change), 1, @ptrCast(&none), 0, null);
    } else {
        _ = c.epoll_ctl(self.fd, std.os.linux.EPOLL.CTL_DEL, fd, null);
    }
}

/// Pause after a failed wait other than EINTR (ENOMEM, ...), so a failure
/// that persists does not spin a core.
const ERROR_BACKOFF_MS = 10;

/// Block until at least one watched descriptor is ready and return the
/// `udata` of each ready one in `out`.  Returns 0 after a failed wait.
pub fn wait(self: *Poller, out: *[max_events]usize) usize {
    while (true) {
        const n = if (use_kqueue)
            c.kevent(self.fd, @ptrCast(&self.events), 0, @ptrCast(&self.events), max_events, null)
        else
            c.epoll_wait(self.fd, @ptrCast(&self.events), max_events, -1);
        if (n < 0) {
            const err = c._errno().*;
            if (err == @intFromEnum(c.E.INTR)) continue;
            log.warn("{s} failed (errno {d}); retrying in {d} ms", .{ if (use_kqueue) "kevent" else "epoll_wait", err, ERROR_BACKOFF_MS });
            const pause = c.timespec{ .sec = 0, .nsec = ERROR_BACKOFF_MS * std.time.ns_per_ms };
            _ = c.nanosleep(&pause, null);
            return 0;
        }
        const count: usize = @intCast(n);
        for (self.events[0..count], 0..) |ev, i| {
            out[i] = if (use_kqueue) ev.udata else ev.data.ptr;
        }
        return count;
    }
}

test "Poller.wait returns after a failed wait instead of spinning" {
    var poller = try Poller.init();
    // A closed descriptor fails every wait with EBADF.
    _ = c.close(poller.fd);
    nofile.release(1);
    var out: [max_events]usize = undefined;
    try std.testing.expectEqual(@as(usize, 0), poller.wait(&out));
}
