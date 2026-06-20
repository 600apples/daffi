const std = @import("std");
const serde = @import("../serde.zig");
const Mutex = @import("../misc.zig").Mutex;
const Message = serde.Message;
const Allocator = std.mem.Allocator;

const ClientMessageStore = @This();

/// HashMap from uuid → *Message.  Replaces the old modulo-2048 fixed array
/// which silently dropped responses when two in-flight RPCs happened to share
/// the same (uuid % 2048) slot.  AutoHashMap grows dynamically and has O(1)
/// amortised insert/lookup with no collision limit.
map: std.AutoHashMap(u16, *Message),
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

pub fn init(allocator: Allocator) ClientMessageStore {
    return .{ .allocator = allocator, .map = std.AutoHashMap(u16, *Message).init(allocator) };
}

pub fn deinit(self: *ClientMessageStore) void {
    // Free any messages still in the store (e.g. on abrupt shutdown).
    var it = self.map.valueIterator();
    while (it.next()) |msg_ptr| msg_ptr.*.deinit();
    self.map.deinit();
}

/// Store a response message.
/// Returns error.StoreFull when another message already occupies this uuid
/// slot (i.e. two in-flight RPCs with the same uuid, which should not happen
/// under normal operation).
pub fn insert(self: *ClientMessageStore, msg: *Message) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    const result = try self.map.getOrPut(msg.getUuid());
    if (result.found_existing) return error.StoreFull;
    result.value_ptr.* = msg;
}

/// Explicitly notify Python ``RpcResult`` waiters that a new response may
/// be available.  Called by ``ClientHandler.wakeupFn`` *after* the
/// dispatcher has finished inspecting ``message.metadata.durable``.
pub fn triggerWakeup(self: *ClientMessageStore) void {
    self.signalWakeup();
}

/// Retrieve and remove the response for uuid.
/// Returns null if no message is present for that uuid.
pub fn fetch(self: *ClientMessageStore, uuid: u16) ?*Message {
    self.mutex.lock();
    defer self.mutex.unlock();
    const msg = self.map.get(uuid) orelse return null;
    _ = self.map.remove(uuid);
    return msg;
}

pub fn setTimeoutError(self: *ClientMessageStore, uuid: u16) !void {
    if (self.fetch(uuid)) |msg| {
        try msg.writeErrorMessage("Timeout error", .{});
    }
}
