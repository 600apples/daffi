const std = @import("std");
const builtin = @import("builtin");
pub const is_wasm = builtin.target.cpu.arch == .wasm32 or builtin.target.cpu.arch == .wasm64;

/// Returns seconds since Unix epoch (replaces std.time.timestamp removed in 0.16).
pub fn timestamp() i64 {
    if (is_wasm) return 0;
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.REALTIME, &ts);
    return ts.sec;
}

/// Returns milliseconds since Unix epoch (replaces std.time.milliTimestamp removed in 0.16).
pub fn milliTimestamp() i64 {
    if (is_wasm) return 0;
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.REALTIME, &ts);
    return ts.sec * 1000 + @divTrunc(ts.nsec, std.time.ns_per_ms);
}
pub const print = if (is_wasm) @import("wasm.zig").consoleLog else std.debug.print;

/// Like `print` but compiled away in non-Debug builds.
pub inline fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    if (builtin.mode == .debug) print(fmt, args);
}

/// std.Thread.Mutex was removed in 0.16.
/// For wasm (single-threaded) this is a no-op stub.
/// For native targets we delegate to pthread_mutex_t which uses a futex
/// internally on Linux and a ulock/os_unfair_lock on macOS — no busy-spin.
pub const Mutex = if (is_wasm) struct {
    pub fn lock(_: *@This()) void {}
    pub fn unlock(_: *@This()) void {}
    pub fn tryLock(_: *@This()) bool { return true; }
} else struct {
    inner: std.c.pthread_mutex_t = std.c.PTHREAD_MUTEX_INITIALIZER,

    pub fn lock(self: *@This()) void {
        _ = std.c.pthread_mutex_lock(&self.inner);
    }
    pub fn unlock(self: *@This()) void {
        _ = std.c.pthread_mutex_unlock(&self.inner);
    }
    pub fn tryLock(self: *@This()) bool {
        return std.c.pthread_mutex_trylock(&self.inner) == .SUCCESS;
    }
};

/// pthread condition variable paired with `Mutex`.  Native targets only.
pub const Condition = struct {
    inner: std.c.pthread_cond_t = std.c.PTHREAD_COND_INITIALIZER,

    pub fn wait(self: *Condition, mutex: *Mutex) void {
        _ = std.c.pthread_cond_wait(&self.inner, &mutex.inner);
    }

    /// Returns false when `timeout_ms` elapsed without a signal.
    pub fn timedWait(self: *Condition, mutex: *Mutex, timeout_ms: u32) bool {
        var ts: std.c.timespec = undefined;
        _ = std.c.clock_gettime(.REALTIME, &ts);
        const ns: i64 = @as(i64, ts.nsec) + @as(i64, timeout_ms % 1000) * std.time.ns_per_ms;
        ts.sec += @intCast(timeout_ms / 1000 + @as(u32, @intCast(@divTrunc(ns, std.time.ns_per_s))));
        ts.nsec = @intCast(@mod(ns, std.time.ns_per_s));
        return std.c.pthread_cond_timedwait(&self.inner, &mutex.inner, &ts) != .TIMEDOUT;
    }

    pub fn signal(self: *Condition) void {
        _ = std.c.pthread_cond_signal(&self.inner);
    }

    pub fn broadcast(self: *Condition) void {
        _ = std.c.pthread_cond_broadcast(&self.inner);
    }
};

/// One-shot event: `set` once, any number of threads `wait` for it.
pub const Event = struct {
    mutex: Mutex = .{},
    cond: Condition = .{},
    is_set: bool = false,

    pub fn set(self: *Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.is_set = true;
        self.cond.broadcast();
    }

    pub fn wait(self: *Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (!self.is_set) self.cond.wait(&self.mutex);
    }
};
