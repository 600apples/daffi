//! One event-loop thread multiplexing many descriptors.
//!
//! A `Source` is a descriptor plus two callbacks.  `onReadable` runs on the
//! loop thread whenever the descriptor is readable (data, EOF or error); it
//! returns `.remove` once the source is finished, after which the loop stops
//! watching the descriptor and calls `onRemoved` — the only place a source
//! may release itself.  Sources therefore never need locking against the loop.
//!
//! Other threads talk to the loop through `call`, which runs a function on the
//! loop thread between two batches of events and waits for it; that is how a
//! source is detached from outside (e.g. a listener when its server stops).

const std = @import("std");
const misc = @import("../misc.zig");
const Poller = @import("Poller.zig");

const EventLoop = @This();
const log = std.log.scoped(.event_loop);
const c = std.c;

/// Bytes read per readiness event, shared by every source of the loop (only
/// one callback runs at a time).
pub const scratch_size = 64 * 1024;

pub const Action = enum { keep, remove };

pub const Source = struct {
    fd: c_int,
    onReadable: *const fn (source: *Source, scratch: []u8) Action,
    onRemoved: *const fn (source: *Source) void,
};

const Command = struct {
    func: *const fn (ctx: *anyopaque) void,
    ctx: *anyopaque,
    done: misc.Event = .{},
    next: ?*Command = null,
};

/// `udata` of the wake-up pipe; source pointers are never 0.
const wake_udata: usize = 0;

poller: Poller,
wake_read: c_int,
wake_write: c_int,
thread: std.Thread = undefined,
thread_id: std.Thread.Id = 0,
commands_mutex: misc.Mutex = .{},
commands: ?*Command = null,
scratch: [scratch_size]u8 = undefined,

/// Start a loop thread.  Loops live for the rest of the process.
pub fn start(allocator: std.mem.Allocator) !*EventLoop {
    var poller = try Poller.init();
    errdefer poller.deinit();
    var fds: [2]c.fd_t = undefined;
    if (c.pipe(&fds) != 0) return error.PipeFailed;
    errdefer {
        _ = c.close(fds[0]);
        _ = c.close(fds[1]);
    }
    for (fds) |fd| {
        _ = c.fcntl(fd, c.F.SETFD, @as(c_int, c.FD_CLOEXEC));
        const flags = c.fcntl(fd, c.F.GETFL, @as(c_int, 0));
        _ = c.fcntl(fd, c.F.SETFL, flags | @as(c_int, @bitCast(c.O{ .NONBLOCK = true })));
    }
    try poller.add(fds[0], wake_udata);

    const self = try allocator.create(EventLoop);
    errdefer allocator.destroy(self);
    self.* = .{ .poller = poller, .wake_read = fds[0], .wake_write = fds[1] };
    var ready: misc.Event = .{};
    self.thread = try std.Thread.spawn(.{}, run, .{ self, &ready });
    self.thread.detach();
    ready.wait();
    return self;
}

/// Start watching `source.fd`.  Thread-safe.
pub fn register(self: *EventLoop, source: *Source) !void {
    try self.poller.add(source.fd, @intFromPtr(source));
}

/// Stop watching `source.fd` without calling `onRemoved`; afterwards the loop
/// never touches `source` again.  Must not be used for a source that may have
/// removed itself already.
pub fn detach(self: *EventLoop, source: *Source) void {
    const Ctx = struct {
        loop: *EventLoop,
        source: *Source,
        fn run(ctx: *anyopaque) void {
            const s: *@This() = @ptrCast(@alignCast(ctx));
            s.loop.poller.remove(s.source.fd);
        }
    };
    var ctx = Ctx{ .loop = self, .source = source };
    self.call(Ctx.run, &ctx);
}

/// Run `func(ctx)` on the loop thread between event batches and wait for it.
/// Runs inline when called from the loop thread itself.
pub fn call(self: *EventLoop, func: *const fn (ctx: *anyopaque) void, ctx: *anyopaque) void {
    if (std.Thread.getCurrentId() == self.thread_id) return func(ctx);
    var cmd = Command{ .func = func, .ctx = ctx };
    {
        self.commands_mutex.lock();
        defer self.commands_mutex.unlock();
        cmd.next = self.commands;
        self.commands = &cmd;
    }
    self.wake();
    cmd.done.wait();
}

pub fn isLoopThread(self: *const EventLoop) bool {
    return std.Thread.getCurrentId() == self.thread_id;
}

fn wake(self: *EventLoop) void {
    const byte = [1]u8{1};
    // A full pipe already guarantees a pending wake-up.
    _ = c.write(self.wake_write, &byte, byte.len);
}

fn drainWake(self: *EventLoop) void {
    var buf: [64]u8 = undefined;
    while (c.read(self.wake_read, &buf, buf.len) > 0) {}
}

fn runCommands(self: *EventLoop) void {
    self.commands_mutex.lock();
    var list = self.commands;
    self.commands = null;
    self.commands_mutex.unlock();
    while (list) |cmd| {
        // `cmd` lives on the waiting caller's stack: read `next` before
        // signalling `done`.
        list = cmd.next;
        cmd.func(cmd.ctx);
        cmd.done.set();
    }
}

fn run(self: *EventLoop, ready: *misc.Event) void {
    self.thread_id = std.Thread.getCurrentId();
    ready.set();
    var ready_udata: [Poller.max_events]usize = undefined;
    while (true) {
        const n = self.poller.wait(&ready_udata);
        for (ready_udata[0..n]) |udata| {
            if (udata == wake_udata) {
                self.drainWake();
                continue;
            }
            const source: *Source = @ptrFromInt(udata);
            if (source.onReadable(source, &self.scratch) == .remove) {
                self.poller.remove(source.fd);
                source.onRemoved(source);
            }
        }
        self.runCommands();
    }
}

test "EventLoop delivers readability and runs commands" {
    const loop = try start(std.heap.c_allocator);

    const Probe = struct {
        source: Source,
        hits: std.atomic.Value(u32) = .init(0),
        removed: misc.Event = .{},

        fn onReadable(s: *Source, scratch: []u8) Action {
            const self: *@This() = @fieldParentPtr("source", s);
            const n = c.read(s.fd, scratch.ptr, scratch.len);
            if (n <= 0) return .remove;
            _ = self.hits.fetchAdd(1, .acq_rel);
            return .keep;
        }
        fn onRemoved(s: *Source) void {
            const self: *@This() = @fieldParentPtr("source", s);
            self.removed.set();
        }
    };

    var fds: [2]c.fd_t = undefined;
    try std.testing.expect(c.pipe(&fds) == 0);
    var probe = Probe{ .source = .{ .fd = fds[0], .onReadable = Probe.onReadable, .onRemoved = Probe.onRemoved } };
    try loop.register(&probe.source);

    _ = c.write(fds[1], "x", 1);
    var flag: bool = false;
    const Set = struct {
        fn run(ctx: *anyopaque) void {
            const f: *bool = @ptrCast(@alignCast(ctx));
            f.* = true;
        }
    };
    loop.call(Set.run, &flag);
    try std.testing.expect(flag);

    _ = c.close(fds[1]); // EOF -> source removes itself
    probe.removed.wait();
    try std.testing.expect(probe.hits.load(.acquire) >= 1);
    _ = c.close(fds[0]);
}
