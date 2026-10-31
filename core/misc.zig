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
/// Milliseconds on a clock that wall-clock changes do not move.
pub fn monotonicMs() i64 {
    if (is_wasm) return 0;
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return ts.sec * 1000 + @divTrunc(ts.nsec, std.time.ns_per_ms);
}

/// Stack for native worker threads (connections, accept loops, the blocking
/// pool).  They run no Python, and OpenSSL needs far less than the 16 MiB
/// default, which adds up when every connection has a thread.
pub const thread_stack_size = 512 * 1024;

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

/// Readers share the lock; a writer holds it alone.  No-op on wasm.
pub const RwLock = if (is_wasm) struct {
    pub fn lockShared(_: *@This()) void {}
    pub fn unlockShared(_: *@This()) void {}
    pub fn lock(_: *@This()) void {}
    pub fn unlock(_: *@This()) void {}
} else struct {
    inner: std.c.pthread_rwlock_t = .{},

    pub fn lockShared(self: *@This()) void {
        _ = std.c.pthread_rwlock_rdlock(&self.inner);
    }
    pub fn unlockShared(self: *@This()) void {
        _ = std.c.pthread_rwlock_unlock(&self.inner);
    }
    pub fn lock(self: *@This()) void {
        _ = std.c.pthread_rwlock_wrlock(&self.inner);
    }
    pub fn unlock(self: *@This()) void {
        _ = std.c.pthread_rwlock_unlock(&self.inner);
    }
};

/// pthread condition variable paired with `Mutex`.  On wasm (single
/// threaded) nothing can signal, so waits return at once.
pub const Condition = if (is_wasm) struct {
    pub fn wait(_: *@This(), _: *Mutex) void {}
    pub fn timedWait(_: *@This(), _: *Mutex, _: u32) bool {
        return false;
    }
    pub fn signal(_: *@This()) void {}
    pub fn broadcast(_: *@This()) void {}
} else struct {
    inner: std.c.pthread_cond_t = std.c.PTHREAD_COND_INITIALIZER,

    pub fn wait(self: *Condition, mutex: *Mutex) void {
        _ = std.c.pthread_cond_wait(&self.inner, &mutex.inner);
    }

    /// Returns false when `timeout_ms` elapsed without a signal.  The
    /// timeout is measured on the monotonic clock: setting the wall clock
    /// neither stretches nor cuts it.
    pub fn timedWait(self: *Condition, mutex: *Mutex, timeout_ms: u32) bool {
        if (builtin.target.os.tag.isDarwin()) {
            const rel = msTimespec(timeout_ms);
            return pthread_cond_timedwait_relative_np(&self.inner, &mutex.inner, &rel) != @intFromEnum(std.c.E.TIMEDOUT);
        }
        // pthread_cond_timedwait takes a wall-clock deadline here; wait in
        // short slices so a clock step moves the end by at most one slice.
        const deadline = monotonicMs() + timeout_ms;
        while (true) {
            const left = deadline - monotonicMs();
            if (left <= 0) return false;
            var ts: std.c.timespec = undefined;
            _ = std.c.clock_gettime(.REALTIME, &ts);
            const slice = msTimespec(@intCast(@min(left, max_wall_slice_ms)));
            const ns: i64 = @as(i64, ts.nsec) + slice.nsec;
            ts.sec += slice.sec + @as(@TypeOf(ts.sec), @intCast(@divTrunc(ns, std.time.ns_per_s)));
            ts.nsec = @intCast(@mod(ns, std.time.ns_per_s));
            if (std.c.pthread_cond_timedwait(&self.inner, &mutex.inner, &ts) != .TIMEDOUT) return true;
        }
    }

    const max_wall_slice_ms = 1000;

    extern "c" fn pthread_cond_timedwait_relative_np(
        cond: *std.c.pthread_cond_t,
        mutex: *std.c.pthread_mutex_t,
        reltime: *const std.c.timespec,
    ) c_int;

    fn msTimespec(ms: u32) std.c.timespec {
        return .{ .sec = @intCast(ms / 1000), .nsec = @intCast(@as(u64, ms % 1000) * std.time.ns_per_ms) };
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

test "Condition.timedWait times out on the monotonic clock" {
    if (is_wasm) return;
    var mutex: Mutex = .{};
    var cond: Condition = .{};
    mutex.lock();
    defer mutex.unlock();
    const start = monotonicMs();
    try std.testing.expect(!cond.timedWait(&mutex, 1200));
    const took = monotonicMs() - start;
    try std.testing.expect(took >= 1190 and took < 3000);
}
