const std = @import("std");
const serde = @import("../serde.zig");
const Mutex = @import("../misc.zig").Mutex;
const Message = serde.Message;

const TasksQueue = @This();

/// Requests waiting for Python beyond this many are refused with an ERROR
/// reply.  Blocking the reader instead could deadlock two peers that call
/// each other.
pub const max_pending: usize = 65_536;

queue: std.DoublyLinkedList = .{},
len: usize = 0,
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
}

/// Tell Python the queue has work, unless an earlier wakeup is still
/// unanswered.  Called after the pushing thread is done with the message:
/// once Python wakes it may pop and free it.
pub fn triggerWakeup(self: *TasksQueue) void {
    if (no_fds) return;
    if (self.armed.swap(true, .acq_rel)) return;
    self.fd_mutex.lock();
    defer self.fd_mutex.unlock();
    if (self.request_fd < 0) return;
    const val: u64 = 1;
    _ = write(@intCast(self.request_fd), @as([*]const u8, @ptrCast(&val)), @sizeOf(u64));
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
    return @alignCast(@fieldParentPtr("queue_node", node));
}

/// Queue a message whatever the backlog (events, lifecycle notices).
pub fn pushMessageToQueue(self: *TasksQueue, message: *Message) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    self.queue.append(&message.queue_node);
    self.len += 1;
}

/// Queue a request unless `max_pending` are already waiting.
pub fn tryPushRequest(self: *TasksQueue, message: *Message) bool {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.len >= max_pending) return false;
    self.queue.append(&message.queue_node);
    self.len += 1;
    return true;
}

pub fn pending(self: *TasksQueue) usize {
    self.mutex.lock();
    defer self.mutex.unlock();
    return self.len;
}
