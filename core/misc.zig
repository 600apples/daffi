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

/// std.Thread.Mutex was removed in 0.16.
/// For wasm (single-threaded) this is a no-op. For native targets it is a
/// simple atomic spinlock until the codebase is ported to std.Io.Mutex.
pub const Mutex = if (is_wasm) struct {
    pub fn lock(_: *@This()) void {}
    pub fn unlock(_: *@This()) void {}
    pub fn tryLock(_: *@This()) bool { return true; }
} else struct {
    inner: std.atomic.Mutex = .unlocked,
    pub fn lock(self: *@This()) void {
        while (!self.inner.tryLock()) std.atomic.spinLoopHint();
    }
    pub fn unlock(self: *@This()) void { self.inner.unlock(); }
    pub fn tryLock(self: *@This()) bool { return self.inner.tryLock(); }
};
