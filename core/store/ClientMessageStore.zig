const std = @import("std");
const serde = @import("../serde.zig");
const Mutex = @import("../misc.zig").Mutex;
const Message = serde.Message;
const Allocator = std.mem.Allocator;

const ClientMessageStore = @This();

const buf_size: u16 = 2048;

// Per-instance buffer (not global) so multiple connections don't share state.
buf: [buf_size]?*Message = [_]?*Message{null} ** buf_size,
mutex: Mutex = .{},
allocator: Allocator,
/// File descriptor (eventfd or pipe write-end) signalled whenever a new
/// response is inserted into the store.  Python's RpcResult waiters block
/// on the corresponding read end so they don't have to poll.
/// Set once by Python via dfcore.setClientResponseFd() before any
/// responses can arrive; -1 means no wakeup is registered (e.g. WASM).
/// Plain i32 so this struct compiles on every target (including wasm32).
response_fd: i32 = -1,

/// POSIX write(2) from libc.  Declared here because std.posix.write was
/// removed in Zig 0.16; the extern works on any POSIX target (Linux, macOS)
/// as long as we link -lc, which we always do for the Python extension.
extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

/// Write a single uint64(1) to response_fd.  Non-blocking: if the fd is full
/// or invalid we drop the signal silently (Python's select() will pick up
/// the next signal anyway).  No-op on freestanding targets (wasm32).
inline fn signalWakeup(self: *ClientMessageStore) void {
    if (comptime @import("builtin").target.os.tag == .freestanding) return;
    if (self.response_fd < 0) return;
    const val: u64 = 1;
    _ = write(@intCast(self.response_fd), @as([*]const u8, @ptrCast(&val)), @sizeOf(u64));
}

/// Store a response message.
/// Returns error.StoreFull when another message already occupies the slot
/// (hash collision from having >= buf_size simultaneous in-flight RPCs).
pub fn insert(self: *ClientMessageStore, msg: *Message) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    const uuid = msg.getUuid();
    const hash = @rem(uuid, buf_size);
    if (self.buf[hash] != null) return error.StoreFull;
    self.buf[hash] = msg;
}

/// Explicitly notify Python ``RpcResult`` waiters that a new response may
/// be available.  Called by ``ClientHandler.wakeupFn`` *after* the
/// dispatcher has finished inspecting ``message.metadata.durable``.
pub fn triggerWakeup(self: *ClientMessageStore) void {
    self.signalWakeup();
}

/// Retrieve and remove the response for uuid.
/// Returns null if no message is present or if the stored message belongs
/// to a different uuid (collision guard — should not happen with correct
/// insert, but protects against stale state).
pub fn fetch(self: *ClientMessageStore, uuid: u16) ?*Message {
    self.mutex.lock();
    defer self.mutex.unlock();
    const hash = @rem(uuid, buf_size);
    const msg = self.buf[hash] orelse return null;
    if (msg.getUuid() != uuid) return null; // collision guard — leave message in place
    self.buf[hash] = null;
    return msg;
}

pub fn setTimeoutError(self: *ClientMessageStore, uuid: u16) !void {
    // fetch() already verifies the UUID, so no extra check needed here.
    if (self.fetch(uuid)) |msg| {
        try msg.writeErrorMessage("Timeout error", .{});
    }
}

