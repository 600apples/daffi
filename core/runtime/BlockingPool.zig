//! Elastic pool of OS threads for work that may block for a long time and
//! therefore must never run on an event-loop thread (TLS handshake, protocol
//! probe of a fresh connection, WebSocket sessions).
//!
//! A job never waits behind another one: when no worker is idle a new one is
//! started, up to `max_workers`; beyond that `spawn` fails and the caller
//! drops the work.  Idle workers exit after `idle_timeout_ms`, so the pool
//! shrinks back once a burst is over.

const std = @import("std");
const misc = @import("../misc.zig");

const BlockingPool = @This();
const log = std.log.scoped(.blocking_pool);
const allocator = std.heap.c_allocator;

const idle_timeout_ms: u32 = 10_000;
/// Bounds the threads a flood of slow handshakes or WebSocket sessions can
/// pin (each reserves `misc.thread_stack_size` of address space).
pub const max_workers: usize = 1024;

const Job = struct {
    run: *const fn (job: *Job) void,
    next: ?*Job = null,
};

mutex: misc.Mutex = .{},
cond: misc.Condition = .{},
head: ?*Job = null,
tail: ?*Job = null,
queued: usize = 0,
/// Workers waiting for a job, including ones started but not yet running.
idle: usize = 0,
workers: usize = 0,

/// Run `func(args...)` on a pool thread.
pub fn spawn(self: *BlockingPool, comptime func: anytype, args: std.meta.ArgsTuple(@TypeOf(func))) !void {
    const Args = @TypeOf(args);
    const Closure = struct {
        job: Job = .{ .run = run },
        args: Args,

        fn run(job: *Job) void {
            const closure: *@This() = @fieldParentPtr("job", job);
            const a = closure.args;
            allocator.destroy(closure);
            @call(.auto, func, a);
        }
    };
    const closure = try allocator.create(Closure);
    closure.* = .{ .args = args };
    errdefer allocator.destroy(closure);

    self.mutex.lock();
    defer self.mutex.unlock();
    // Every queued job has an idle worker reserved for it.
    if (self.queued >= self.idle) {
        if (self.workers >= max_workers) return error.BlockingPoolExhausted;
        const thread = try std.Thread.spawn(.{ .stack_size = misc.thread_stack_size }, worker, .{self});
        thread.detach();
        self.idle += 1;
        self.workers += 1;
    }
    if (self.tail) |t| t.next = &closure.job else self.head = &closure.job;
    self.tail = &closure.job;
    self.queued += 1;
    self.cond.signal();
}

fn worker(self: *BlockingPool) void {
    self.mutex.lock();
    while (true) {
        while (self.head == null) {
            if (!self.cond.timedWait(&self.mutex, idle_timeout_ms) and self.head == null) {
                self.idle -= 1;
                self.workers -= 1;
                self.mutex.unlock();
                return;
            }
        }
        const job = self.head.?;
        self.head = job.next;
        if (self.head == null) self.tail = null;
        self.queued -= 1;
        self.idle -= 1;
        self.mutex.unlock();

        job.run(job);

        self.mutex.lock();
        self.idle += 1;
    }
}

test "BlockingPool runs every job, concurrently when they block" {
    // Idle workers outlive the test, so the pool must too (as in production).
    const pool = &struct {
        var instance: BlockingPool = .{};
    }.instance;
    const Ctx = struct {
        gate: misc.Event = .{},
        started: std.atomic.Value(u32) = .init(0),
        finished: std.atomic.Value(u32) = .init(0),

        fn job(ctx: *@This()) void {
            _ = ctx.started.fetchAdd(1, .acq_rel);
            ctx.gate.wait();
            _ = ctx.finished.fetchAdd(1, .acq_rel);
        }
    };
    var ctx = Ctx{};
    for (0..8) |_| try pool.spawn(Ctx.job, .{&ctx});
    // All eight must be running at once: none may queue behind a blocked one.
    const deadline = misc.milliTimestamp() + 5_000;
    while (ctx.started.load(.acquire) < 8) {
        try std.testing.expect(misc.milliTimestamp() < deadline);
        std.Thread.yield() catch {};
    }
    ctx.gate.set();
    while (ctx.finished.load(.acquire) < 8) {
        try std.testing.expect(misc.milliTimestamp() < deadline);
        std.Thread.yield() catch {};
    }
}
