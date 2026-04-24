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

