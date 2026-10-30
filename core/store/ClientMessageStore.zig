const std = @import("std");
const serde = @import("../serde.zig");
const misc = @import("../misc.zig");
const Mutex = misc.Mutex;
const Condition = misc.Condition;
const Message = serde.Message;
const Allocator = std.mem.Allocator;

const ClientMessageStore = @This();

/// Responses that arrived before anyone waited for them, by uuid.
map: std.AutoHashMap(u16, *Message),
/// uuids whose caller already gave up before the response arrived.  A late
/// response is dropped instead of being parked in `map` forever, and
/// `reserve` forgets a uuid when it is handed out again.
expired: std.AutoHashMap(u16, void),
/// Callers blocked in `wait`, by uuid.  `insert` hands a response straight to
/// its waiter, so it is never parked in `map`.
waiters: std.AutoHashMap(u16, *Waiter),
/// Set once the connection is gone: every waiter wakes, and `wait` no longer
/// blocks.
closed: bool = false,
mutex: Mutex = .{},
allocator: Allocator,
/// Eventfd or pipe write end signalled when a response is parked in `map`.
/// Only the asyncio client sets it; blocking callers use `wait`.  Guarded by
/// `mutex`, so Python can set it to -1 and then close the descriptor.
response_fd: i32 = -1,

const Waiter = struct {
    cond: Condition = .{},
    msg: ?*Message = null,
};

pub const WaitResult = union(enum) {
    message: *Message,
    timeout,
    closed,
};

pub const InsertResult = enum {
    /// Handed to a caller blocked in `wait`.
    delivered,
    /// Parked in `map` until fetched.
    parked,
};

extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

pub fn init(allocator: Allocator) ClientMessageStore {
    return .{
        .allocator = allocator,
        .map = .init(allocator),
        .expired = .init(allocator),
        .waiters = .init(allocator),
    };
}

pub fn deinit(self: *ClientMessageStore) void {
    var it = self.map.valueIterator();
    while (it.next()) |msg_ptr| msg_ptr.*.deinit();
    self.map.deinit();
    self.expired.deinit();
    self.waiters.deinit();
}

/// Store a response, or hand it to the caller waiting for it.
/// `error.Expired`: that caller already gave up.  `error.StoreFull`: a
/// response for this uuid is already pending.  On error the caller still
/// owns `msg`.
pub fn insert(self: *ClientMessageStore, msg: *Message) !InsertResult {
    const uuid = msg.getUuid();
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.expired.remove(uuid)) return error.Expired;
    if (self.waiters.get(uuid)) |waiter| {
        if (waiter.msg != null) return error.StoreFull;
        waiter.msg = msg;
        waiter.cond.signal();
        return .delivered;
    }
    const result = try self.map.getOrPut(uuid);
    if (result.found_existing) return error.StoreFull;
    result.value_ptr.* = msg;
    return .parked;
}

/// Wake asyncio waiters after a response was parked.
pub fn triggerWakeup(self: *ClientMessageStore) void {
    if (comptime @import("builtin").target.os.tag == .freestanding) return;
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.response_fd < 0) return;
    const val: u64 = 1;
    _ = write(@intCast(self.response_fd), @as([*]const u8, @ptrCast(&val)), @sizeOf(u64));
}

pub fn setResponseFd(self: *ClientMessageStore, fd: i32) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    self.response_fd = fd;
}

/// Retrieve and remove the response for uuid, if it arrived.
pub fn fetch(self: *ClientMessageStore, uuid: u16) ?*Message {
    self.mutex.lock();
    defer self.mutex.unlock();
    const kv = self.map.fetchRemove(uuid) orelse return null;
    return kv.value;
}

/// Block until the response for `uuid` arrives, `timeout_ms` passes, or the
/// connection closes.  A response that arrived earlier is returned at once.
pub fn wait(self: *ClientMessageStore, uuid: u16, timeout_ms: u32) !WaitResult {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.map.fetchRemove(uuid)) |kv| return .{ .message = kv.value };
    if (self.closed) return .closed;
    var waiter = Waiter{};
    try self.waiters.put(uuid, &waiter);
    defer _ = self.waiters.remove(uuid);
    const deadline = misc.monotonicMs() + timeout_ms;
    while (waiter.msg == null and !self.closed) {
        const now = misc.monotonicMs();
        if (now >= deadline) break;
        _ = waiter.cond.timedWait(&self.mutex, @intCast(deadline - now));
    }
    if (waiter.msg) |msg| return .{ .message = msg };
    return if (self.closed) .closed else .timeout;
}

/// Wake every waiter: no further response can arrive.
pub fn close(self: *ClientMessageStore) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    self.closed = true;
    var it = self.waiters.valueIterator();
    while (it.next()) |waiter| waiter.*.cond.signal();
}

/// The caller gave up on `uuid`.  Frees a response that already arrived, or
/// remembers the uuid so one that arrives later is discarded.
pub fn expire(self: *ClientMessageStore, uuid: u16) !void {
    self.mutex.lock();
    const kv = self.map.fetchRemove(uuid);
    if (kv == null) {
        defer self.mutex.unlock();
        if (!self.closed) try self.expired.put(uuid, {});
        return;
    }
    self.mutex.unlock();
    kv.?.value.deinit();
}

/// `uuid` is being issued to a new request: forget the previous owner's
/// expiry and free any response of its that is still parked.
pub fn reserve(self: *ClientMessageStore, uuid: u16) void {
    self.mutex.lock();
    _ = self.expired.remove(uuid);
    const stale = self.map.fetchRemove(uuid);
    self.mutex.unlock();
    if (stale) |kv| kv.value.deinit();
}
