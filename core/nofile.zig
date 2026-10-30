//! Soft open-file limit for this process.
//!
//! The limit is the capacity and the number of descriptors daffi currently
//! holds is the length. Both live in atomics. A compare reads those two
//! variables; it does not ask the kernel what the limit is.
//!
//! Growth is the same rule as a dynamic array, triggered 100 descriptors
//! early. Capacity 1024 with 924 already in use is inside that margin, so
//! the capacity doubles to 2048 before the next open can reach the kernel
//! limit. If one acquire still does not fit, it doubles again, and so on,
//! stopping at the hard limit.

const std = @import("std");
const misc = @import("misc.zig");

var in_use = std.atomic.Value(usize).init(0);
var limit = std.atomic.Value(usize).init(0);
/// 0 means the hard limit is infinity (or not loaded yet).
var hard_cap = std.atomic.Value(usize).init(0);
/// Kernel hard limit, captured once with the soft limit. `setrlimit` has to
/// send it back; the compare path never reads it from the kernel again.
const HardRlim = if (misc.is_wasm) u64 else std.c.rlim_t;
var hard_rlim: HardRlim = 0;
var lock: misc.Mutex = .{};

/// Free descriptors to keep below the stored soft limit. Growth runs when
/// fewer than this many remain, so an open is not the thing that discovers
/// the process is full.
const headroom: usize = 100;

pub fn acquire(additional: usize) void {
    if (comptime misc.is_wasm) return;
    nativeAcquire(additional);
}

pub fn release(n: usize) void {
    if (comptime misc.is_wasm) return;
    nativeRelease(n);
}

/// Double the stored soft limit once. An open can still fail with EMFILE
/// when descriptors this counter does not own already fill the old limit.
pub fn bump() bool {
    if (comptime misc.is_wasm) return false;
    return nativeBump();
}

fn nativeAcquire(additional: usize) void {
    if (additional == 0) return;
    // Count the descriptors before they exist so two threads cannot both
    // decide the current capacity still has room.
    const used = in_use.fetchAdd(additional, .monotonic) + additional;
    const cap = cachedLimit();
    const needed = used +| headroom;
    if (needed < cap) return;
    // `+ 1` forces a real double when `used + headroom` lands exactly on the
    // current capacity. `grow` leaves the limit alone when it already fits.
    _ = grow(needed +| 1);
}

fn nativeRelease(n: usize) void {
    if (n == 0) return;
    while (true) {
        const cur = in_use.load(.monotonic);
        const next = if (cur >= n) cur - n else 0;
        if (in_use.cmpxchgWeak(cur, next, .monotonic, .monotonic) == null) return;
    }
}

fn nativeBump() bool {
    const cap = cachedLimit();
    if (cap >= std.math.maxInt(usize) / 2) return grow(cap);
    return grow(cap + 1);
}

fn cachedLimit() usize {
    const cached = limit.load(.acquire);
    if (cached != 0) return cached;
    return loadLimit();
}

fn loadLimit() usize {
    lock.lock();
    defer lock.unlock();
    const cached = limit.load(.monotonic);
    if (cached != 0) return cached;

    const current = std.posix.getrlimit(.NOFILE) catch {
        limit.store(1024, .release);
        hard_cap.store(1024, .release);
        return 1024;
    };
    const infinity = std.c.RLIM.INFINITY;
    const soft: usize = if (current.cur == infinity) std.math.maxInt(usize) else @intCast(current.cur);
    hard_rlim = current.max;
    if (current.max == infinity) {
        hard_cap.store(0, .release);
    } else {
        hard_cap.store(@intCast(current.max), .release);
    }
    const stored: usize = if (soft == 0) 4 else soft;
    limit.store(stored, .release);
    return stored;
}

/// Double `limit` until it is at least `needed`. One `setrlimit` publishes
/// the final capacity.
fn grow(needed: usize) bool {
    lock.lock();
    defer lock.unlock();

    var cap = limit.load(.monotonic);
    if (cap == 0) cap = 4;
    if (cap >= needed) return true;

    const hard = hard_cap.load(.monotonic);
    if (hard != 0 and cap >= hard) return false;

    while (cap < needed) {
        if (cap > std.math.maxInt(usize) / 2) {
            if (hard == 0 or hard <= cap) return false;
            cap = hard;
            break;
        }
        var next = cap * 2;
        if (hard != 0 and next > hard) next = hard;
        if (next <= cap) return false;
        cap = next;
        if (hard != 0 and cap == hard) break;
    }
    if (cap <= limit.load(.monotonic)) return cap >= needed;

    if (!setLimit(cap)) {
        // macOS reports RLIM_INFINITY as the hard cap, but setrlimit
        // refuses a soft limit above kern.maxfilesperproc.
        if (comptime @import("builtin").os.tag.isDarwin()) {
            const max_proc = procMaxFiles() orelse return false;
            hard_cap.store(max_proc, .release);
            if (cap > max_proc) cap = max_proc;
            if (cap <= limit.load(.monotonic)) return false;
            if (!setLimit(cap)) return false;
        } else return false;
    }
    limit.store(cap, .release);
    return cap >= needed;
}

fn setLimit(cap: usize) bool {
    std.posix.setrlimit(.NOFILE, .{
        .cur = @intCast(cap),
        .max = hard_rlim,
    }) catch return false;
    return true;
}

/// `kern.maxfilesperproc`, or null if the sysctl is missing.
fn procMaxFiles() ?usize {
    var mib = [2]c_int{ 1, 29 }; // CTL_KERN, KERN_MAXFILESPERPROC
    var max: c_int = 0;
    var len: usize = @sizeOf(c_int);
    if (sysctl(&mib, 2, &max, &len, null, 0) != 0) return null;
    if (max <= 0) return null;
    return @intCast(max);
}

extern "c" fn sysctl(name: [*c]c_int, namelen: c_uint, oldp: ?*anyopaque, oldlenp: ?*usize, newp: ?*anyopaque, newlen: usize) c_int;

test "procMaxFiles is a finite cap on Darwin" {
    if (comptime !@import("builtin").os.tag.isDarwin()) return;
    const max = procMaxFiles() orelse return error.TestUnexpectedResult;
    try std.testing.expect(max >= 256);
    try std.testing.expect(max < std.math.maxInt(usize) / 2);
}
