//! Process-wide runtime of the native core.
//!
//! `threads` (default): every connection — and every client dispatcher — owns
//! an OS thread that blocks on reads.
//!
//! `evented`: connections are multiplexed over a few event-loop threads
//! (kqueue/epoll); messages are decoded incrementally as bytes arrive and
//! handlers run on the loop thread.  Work that can block indefinitely
//! (TLS handshake, the protocol probe of an accepted socket, WebSocket
//! sessions) runs on an elastic blocking pool instead.
//!
//! Selected once per process by `runtime.configure` (the `runtime` constructor
//! argument). The first use without a choice is `threads`.
//! `DAFFI_EVENT_LOOPS` sets the number of loop threads (default: CPU count,
//! capped at 64). A later choice that disagrees is rejected.

const std = @import("std");
const misc = @import("misc.zig");
pub const EventLoop = @import("runtime/EventLoop.zig");
pub const BlockingPool = @import("runtime/BlockingPool.zig");

const log = std.log.scoped(.runtime);

pub const Model = enum { threads, evented };

const max_loops = 64;

var init_mutex: misc.Mutex = .{};
var initialized: bool = false;
var selected: Model = .threads;
var loop_count: usize = 1;
var loops: [max_loops]?*EventLoop = @splat(null);
var next_loop: std.atomic.Value(usize) = .init(0);
var blocking_pool: BlockingPool = .{};

pub fn model() Model {
    init_mutex.lock();
    defer init_mutex.unlock();
    ensureInit();
    return selected;
}

/// Lock the process to `explicit`. A second call may only repeat that choice.
pub fn configure(explicit: Model) error{RuntimeMismatch}!void {
    init_mutex.lock();
    defer init_mutex.unlock();
    if (initialized) {
        if (explicit != selected) return error.RuntimeMismatch;
        return;
    }
    finishInit(explicit);
}

/// Event loop for a new source, chosen round-robin.  The whole set of loops
/// starts on first use and lives for the rest of the process.
pub fn loop() !*EventLoop {
    init_mutex.lock();
    defer init_mutex.unlock();
    ensureInit();
    for (loops[0..loop_count]) |*slot| {
        if (slot.* == null) slot.* = try EventLoop.start(std.heap.c_allocator);
    }
    return loops[next_loop.fetchAdd(1, .monotonic) % loop_count].?;
}

/// Whether the calling thread is an event-loop thread, which must not block.
pub fn onLoopThread() bool {
    if (comptime misc.is_wasm) return false;
    return EventLoop.current != null;
}

/// Run `func(args...)` on the blocking pool.
pub fn spawnBlocking(comptime func: anytype, args: std.meta.ArgsTuple(@TypeOf(func))) !void {
    return blocking_pool.spawn(func, args);
}

/// A forked child inherits these globals but none of the loop or pool threads
/// (nor, on macOS, the kqueue descriptors): start over with fresh ones.
fn resetAfterFork() callconv(.c) void {
    init_mutex = .{};
    loops = @splat(null);
    blocking_pool = .{};
}

fn ensureInit() void {
    if (initialized) return;
    finishInit(.threads);
}

fn finishInit(chosen: Model) void {
    selected = chosen;
    initialized = true;
    _ = std.c.pthread_atfork(null, null, resetAfterFork);
    const cpus = std.Thread.getCpuCount() catch 1;
    // Unset DAFFI_EVENT_LOOPS → one loop per CPU (hard cap max_loops).
    loop_count = @max(1, @min(cpus, max_loops));
    if (std.c.getenv("DAFFI_EVENT_LOOPS")) |raw| {
        const value = std.mem.span(raw);
        if (std.fmt.parseInt(usize, value, 10)) |n| {
            if (n >= 1 and n <= max_loops) loop_count = n else log.warn("DAFFI_EVENT_LOOPS must be 1..{d}, got {d}", .{ max_loops, n });
        } else |_| log.warn("invalid DAFFI_EVENT_LOOPS '{s}'", .{value});
    }
}

test {
    _ = EventLoop;
    _ = BlockingPool;
}
