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
/// `claim` forgets a uuid when it is handed out again.
expired: std.AutoHashMap(u16, void),
/// uuids issued to requests whose response was not taken yet.  Only those
/// are accepted, and none is issued again while in here.  Not used by the
/// wasm client, whose responses are kept by JavaScript.
pending: std.AutoHashMap(u16, void),
track_pending: bool = !is_wasm,
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

const is_wasm = @import("builtin").target.os.tag == .freestanding;

extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

pub fn init(allocator: Allocator) ClientMessageStore {
    return .{
        .allocator = allocator,
        .map = .init(allocator),
        .expired = .init(allocator),
        .pending = .init(allocator),
        .waiters = .init(allocator),
    };
}

pub fn deinit(self: *ClientMessageStore) void {
    var it = self.map.valueIterator();
    while (it.next()) |msg_ptr| msg_ptr.*.deinit();
    self.map.deinit();
    self.expired.deinit();
    self.pending.deinit();
    self.waiters.deinit();
}

/// Store a response, or hand it to the caller waiting for it.
/// `error.Expired`: that caller already gave up.  `error.NotPending`: no
/// request with this uuid is waiting (forged, or a duplicate).
/// `error.StoreFull`: a response for this uuid is already pending.  On
/// error the caller still owns `msg`.
pub fn insert(self: *ClientMessageStore, msg: *Message) !InsertResult {
    const uuid = msg.getUuid();
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.expired.remove(uuid)) return error.Expired;
    if (self.track_pending and !self.pending.contains(uuid)) return error.NotPending;
    if (self.waiters.get(uuid)) |waiter| {
        if (waiter.msg != null) return error.StoreFull;
        waiter.msg = msg;
        waiter.cond.signal();
        _ = self.pending.remove(uuid);
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
    _ = self.pending.remove(uuid);
    return kv.value;
}

/// Block until the response for `uuid` arrives, `timeout_ms` passes, or the
/// connection closes.  A response that arrived earlier is returned at once.
pub fn wait(self: *ClientMessageStore, uuid: u16, timeout_ms: u32) !WaitResult {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.map.fetchRemove(uuid)) |kv| {
        _ = self.pending.remove(uuid);
        return .{ .message = kv.value };
    }
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
        // Already taken: there is nothing left to drop.
        if (self.track_pending and !self.pending.remove(uuid)) return;
        if (!self.closed) try self.expired.put(uuid, {});
        return;
    }
    _ = self.pending.remove(uuid);
    self.mutex.unlock();
    kv.?.value.deinit();
}

/// Issue `uuid` to a new request, unless one still waiting has it.  An
/// expired uuid is only reused with `reuse_expired`: its response may still
/// be on the way, and is then dropped as the new request's.
pub fn claim(self: *ClientMessageStore, uuid: u16, reuse_expired: bool) !bool {
    self.mutex.lock();
    if (self.pending.contains(uuid) or (!reuse_expired and self.expired.contains(uuid))) {
        self.mutex.unlock();
        return false;
    }
    errdefer self.mutex.unlock();
    if (self.track_pending) try self.pending.put(uuid, {});
    _ = self.expired.remove(uuid);
    const stale = self.map.fetchRemove(uuid);
    self.mutex.unlock();
    if (stale) |kv| kv.value.deinit();
    return true;
}

/// Undo `claim` for a request that was never sent.
pub fn unclaim(self: *ClientMessageStore, uuid: u16) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    _ = self.pending.remove(uuid);
}

fn testResponse(uuid: u16, body: []const u8) !*Message {
    var raw = try serde.RawMessage.create(std.testing.allocator, body, uuid, .RESPONSE, .JSON, false, false, "svc", "me", "f");
    return Message.fromRawMessage(std.testing.allocator, &raw);
}

test "ClientMessageStore never issues a uuid that is still waiting" {
    var s = ClientMessageStore.init(std.testing.allocator);
    s.track_pending = true;
    defer s.deinit();

    try std.testing.expect(try s.claim(5, false));
    try std.testing.expect(!try s.claim(5, false));
    try std.testing.expect(!try s.claim(5, true));

    const msg = try testResponse(5, "1");
    try std.testing.expectEqual(InsertResult.parked, try s.insert(msg));
    // Parked but not fetched: still taken.
    try std.testing.expect(!try s.claim(5, true));
    s.fetch(5).?.deinit();
    try std.testing.expect(try s.claim(5, false));
}

test "ClientMessageStore drops responses nobody asked for" {
    var s = ClientMessageStore.init(std.testing.allocator);
    s.track_pending = true;
    defer s.deinit();

    const forged = try testResponse(9, "1");
    defer forged.deinit();
    try std.testing.expectError(error.NotPending, s.insert(forged));

    try std.testing.expect(try s.claim(9, false));
    const real = try testResponse(9, "2");
    try std.testing.expectEqual(InsertResult.parked, try s.insert(real));
    s.fetch(9).?.deinit();
    // A second response for the same request is not accepted either.
    try std.testing.expectError(error.NotPending, s.insert(forged));
}

test "ClientMessageStore reuses an expired uuid only when nothing else is free" {
    var s = ClientMessageStore.init(std.testing.allocator);
    s.track_pending = true;
    defer s.deinit();

    try std.testing.expect(try s.claim(3, false));
    try s.expire(3);
    try std.testing.expect(!try s.claim(3, false));
    try std.testing.expect(try s.claim(3, true));
    s.unclaim(3);

    try std.testing.expect(try s.claim(4, false));
    try s.expire(4);
    // Its late response is dropped, after which the uuid is free.
    const late = try testResponse(4, "old");
    defer late.deinit();
    try std.testing.expectError(error.Expired, s.insert(late));
    try std.testing.expect(try s.claim(4, false));

    // Expiring a request that was already answered changes nothing.
    const answer = try testResponse(4, "new");
    try std.testing.expectEqual(InsertResult.parked, try s.insert(answer));
    s.fetch(4).?.deinit();
    try s.expire(4);
    try std.testing.expect(try s.claim(4, false));
}
