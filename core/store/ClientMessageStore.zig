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

pub fn fetch(self: *ClientMessageStore, uuid: u16) ?*Message {
    self.mutex.lock();
    defer self.mutex.unlock();
    const hash = @rem(uuid, buf_size);
    if (self.buf[hash]) |msg| {
        self.buf[hash] = null;
        return msg;
    }
    return null;
}

pub fn insert(self: *ClientMessageStore, msg: *Message) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    const uuid = msg.getUuid();
    const hash = @rem(uuid, buf_size);
    self.buf[hash] = msg;
}

pub fn setTimeoutError(self: *ClientMessageStore, uuid: u16) !void {
    if (self.fetch(uuid)) |msg| {
        if (msg.getUuid() == uuid) try msg.writeErrorMessage("Timeout error", .{});
    }
}
