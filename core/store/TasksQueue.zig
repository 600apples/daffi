const std = @import("std");
const serde = @import("../serde.zig");
const Mutex = @import("../misc.zig").Mutex;
const Message = serde.Message;

const TasksQueue = @This();

/// Requests waiting for Python beyond this many are refused with an ERROR
/// reply.  Blocking the reader instead could deadlock two peers that call
/// each other.
pub const max_pending: usize = 65_536;
/// The same for the bytes the waiting requests hold: a few peers sending
/// large messages faster than Python takes them must not exhaust memory.
pub const max_pending_bytes: usize = 256 * 1024 * 1024;

queue: std.DoublyLinkedList = .{},
len: usize = 0,
bytes: usize = 0,
byte_limit: usize = max_pending_bytes,
mutex: Mutex = .{},
/// Guards both descriptors.  Python sets one to -1 before closing it, so a
/// write never lands on a reused descriptor number.
fd_mutex: Mutex = .{},
/// Eventfd or pipe write end signalled when the queue becomes non-empty.
request_fd: i32 = -1,
/// Pipe write end that gets one byte per lifecycle change:
///   'd' — the connection ended
///   'e' — this client was evicted by a newer connection with its name
lifecycle_fd: i32 = -1,
/// A wakeup is in flight and Python has not yet drained the queue.  Further
/// pushes skip the write; `pop` clears it when it finds the queue empty.
armed: std.atomic.Value(bool) = .init(false),

extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

const no_fds = @import("builtin").target.os.tag == .freestanding;

pub fn deinit(self: *TasksQueue) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    while (self.queue.popFirst()) |node| {
        const msg: *Message = @alignCast(@fieldParentPtr("queue_node", node));
        msg.deinit();
    }
    self.len = 0;
    self.bytes = 0;
}

/// Tell Python the queue has work, unless an earlier wakeup is still
/// unanswered.  Called after the pushing thread is done with the message:
/// once Python wakes it may pop and free it.
pub fn triggerWakeup(self: *TasksQueue) void {
    if (no_fds) return;
    if (self.armed.swap(true, .acq_rel)) return;
    self.fd_mutex.lock();
    defer self.fd_mutex.unlock();
    if (self.request_fd < 0) {
        self.armed.store(false, .release);
        return;
    }
    const val: u64 = 1;
    const n = write(@intCast(self.request_fd), @as([*]const u8, @ptrCast(&val)), @sizeOf(u64));
    if (n <= 0) self.armed.store(false, .release);
}

pub fn triggerDisconnect(self: *TasksQueue) void {
    self.writeLifecycle('d');
}

pub fn triggerEviction(self: *TasksQueue) void {
    self.writeLifecycle('e');
}

fn writeLifecycle(self: *TasksQueue, reason: u8) void {
    if (no_fds) return;
    self.fd_mutex.lock();
    defer self.fd_mutex.unlock();
    if (self.lifecycle_fd < 0) return;
    _ = write(@intCast(self.lifecycle_fd), @as([*]const u8, @ptrCast(&reason)), 1);
}

/// Install (or with -1, withdraw) the request descriptor.  Work queued
/// while none was installed is announced on the new one.
pub fn setRequestFd(self: *TasksQueue, fd: i32) void {
    self.fd_mutex.lock();
    self.request_fd = fd;
    self.fd_mutex.unlock();
    self.armed.store(false, .release);
    if (fd >= 0 and self.pending() > 0) self.triggerWakeup();
}

pub fn setLifecycleFd(self: *TasksQueue, fd: i32) void {
    self.fd_mutex.lock();
    defer self.fd_mutex.unlock();
    self.lifecycle_fd = fd;
}

pub fn getMessageFromQueue(self: *TasksQueue) ?*Message {
    self.mutex.lock();
    defer self.mutex.unlock();
    const node = self.queue.popFirst() orelse {
        self.armed.store(false, .release);
        return null;
    };
    self.len -= 1;
    const msg: *Message = @alignCast(@fieldParentPtr("queue_node", node));
    self.bytes -= msg.data.len;
    return msg;
}

/// Queue a message whatever the backlog (events, lifecycle notices).
pub fn pushMessageToQueue(self: *TasksQueue, message: *Message) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    self.append(message);
}

/// Queue a request unless `max_pending` requests or `byte_limit` bytes are
/// already waiting.  One request is always taken into an empty queue, so a
/// single message larger than the limit is not refused forever.
pub fn tryPushRequest(self: *TasksQueue, message: *Message) bool {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.len >= max_pending) return false;
    if (self.len > 0 and self.bytes + message.data.len > self.byte_limit) return false;
    self.append(message);
    return true;
}

fn append(self: *TasksQueue, message: *Message) void {
    self.queue.append(&message.queue_node);
    self.len += 1;
    self.bytes += message.data.len;
}

pub fn pending(self: *TasksQueue) usize {
    self.mutex.lock();
    defer self.mutex.unlock();
    return self.len;
}

fn testRequest(body: []const u8) !*Message {
    var raw = try serde.RawMessage.create(std.testing.allocator, body, 1, .REQUEST, .JSON, false, true, "caller", "svc", "f");
    return Message.fromRawMessage(std.testing.allocator, &raw);
}

test "TasksQueue refuses requests past its byte limit" {
    var q = TasksQueue{ .byte_limit = 1000 };
    defer q.deinit();

    const body: [1500]u8 = @splat('1');
    const big = try testRequest(&body);
    try std.testing.expect(q.tryPushRequest(big));

    const small = try testRequest("1");
    try std.testing.expect(!q.tryPushRequest(small));
    try std.testing.expectEqual(@as(usize, 1), q.pending());

    q.getMessageFromQueue().?.deinit();
    try std.testing.expectEqual(@as(usize, 0), q.bytes);
    try std.testing.expect(q.tryPushRequest(small));
    try std.testing.expect(q.bytes > 0);
}
