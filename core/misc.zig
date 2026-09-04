const std = @import("std");
const builtin = @import("builtin");
pub const is_wasm = builtin.cpu.arch == .wasm32 or builtin.cpu.arch == .wasm64;

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
    if (builtin.mode == .Debug) print(fmt, args);
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
