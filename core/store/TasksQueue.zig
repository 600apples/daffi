const std = @import("std");
const serde = @import("../serde.zig");
const Mutex = @import("../misc.zig").Mutex;
const Message = serde.Message;
const Allocator = std.mem.Allocator;


const MessageNode = struct {
    node: std.DoublyLinkedList.Node = .{},
    data: *Message,
};

const TasksQueue = @This();

allocator: Allocator,
queue: std.DoublyLinkedList,
mutex: Mutex = .{},
/// File descriptor to signal when a message is pushed.
/// Set once by Python via dfcore.setRequestFd() before any messages can
/// arrive; -1 means no wakeup is registered.
/// Plain i32 so this struct compiles on every target (including wasm32).
request_fd: i32 = -1,
/// Single pipe write-end shared by both the AutoReconnect path and the
/// non-autoreconnect disconnect watcher.  Written once with a single-byte
/// reason code so Python knows both *that* the connection ended and *why*:
///   'd'  — normal disconnect  → ConnectionError / reconnect
///   'e'  — this client was evicted → Evicted / stop
/// -1 means not registered.
lifecycle_fd: i32 = -1,

pub fn init(allocator: std.mem.Allocator) !TasksQueue {
    return .{ .allocator = allocator, .queue = .{} };
}

/// POSIX write(2) from libc.  Declared here because std.posix.write was
/// removed in Zig 0.16; the extern works on any POSIX target (Linux, macOS)
/// as long as we link -lc, which we always do for the Python extension.
extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

/// Write a single uint64(1) to request_fd (eventfd or pipe write-end).
/// Non-blocking: if the fd is full or invalid we drop the signal silently.
/// No-op on targets without POSIX (e.g. wasm32-freestanding).
inline fn signalWakeup(self: *TasksQueue) void {
    if (comptime @import("builtin").target.os.tag == .freestanding) return;
    if (self.request_fd < 0) return;
    const val: u64 = 1;
    _ = write(@intCast(self.request_fd), @as([*]const u8, @ptrCast(&val)), @sizeOf(u64));
}

/// Explicitly notify the Python poller that one or more messages are ready.
///
/// This is intentionally *not* called inside pushMessageToQueue.  Calling it
/// there would create a race in serverLoop: after the signal is sent, the
/// Python poller can dequeue and free the message before serverLoop's
/// `defer message.deinit()` has had a chance to observe `metadata.durable`.
/// Instead, serverLoop calls triggerWakeup() itself, *after* it has inspected
/// `metadata.durable` and (if necessary) freed the message.
pub fn triggerWakeup(self: *TasksQueue) void {
    self.signalWakeup();
}

/// Signal Python that this connection has been lost.
/// Writes the single byte 'd' to lifecycle_fd.
/// Called once from messageDispatcherClientEntry after the connection drops.
pub fn triggerDisconnect(self: *TasksQueue) void {
    if (comptime @import("builtin").target.os.tag == .freestanding) return;
    if (self.lifecycle_fd < 0) return;
    const reason: u8 = 'd';
    _ = write(@intCast(self.lifecycle_fd), @as([*]const u8, @ptrCast(&reason)), 1);
}

/// Signal Python that THIS client has been evicted by its router/service.
/// Writes the single byte 'e' to lifecycle_fd so the watcher thread raises
/// EvictedError instead of the generic ConnectionError.
/// Called from ClientHandler.onEvent when the received "evicted" event
/// names this client itself as the evicted member.
pub fn triggerEviction(self: *TasksQueue) void {
    if (comptime @import("builtin").target.os.tag == .freestanding) return;
    if (self.lifecycle_fd < 0) return;
    const reason: u8 = 'e';
    _ = write(@intCast(self.lifecycle_fd), @as([*]const u8, @ptrCast(&reason)), 1);
}

pub fn deinit(self: *TasksQueue) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    while (self.queue.popFirst()) |raw_node| {
        const msg_node: *MessageNode = @fieldParentPtr("node", raw_node);
        msg_node.data.deinit();
        self.allocator.destroy(msg_node);
    }
}

pub fn getMessageFromQueue(self: *TasksQueue) ?*Message {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.queue.popFirst()) |raw_node| {
        const msg_node: *MessageNode = @fieldParentPtr("node", raw_node);
        defer self.allocator.destroy(msg_node);
        return msg_node.data;
    }
    return null;
}

pub fn pushMessageToQueue(self: *TasksQueue, message: *Message) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    const msg_node = try self.allocator.create(MessageNode);
    msg_node.* = .{ .data = message };
    self.queue.append(&msg_node.node);
    // NOTE: triggerWakeup() is NOT called here.  The caller (serverLoop) is
    // responsible for calling triggerWakeup() after it is done examining the
    // message pointer.  This prevents a race where the Python poller frees the
    // message before serverLoop's ownership check completes.
}

pub fn len(self: *TasksQueue) usize {
    self.mutex.lock();
    defer self.mutex.unlock();
    return self.queue.len();
}
