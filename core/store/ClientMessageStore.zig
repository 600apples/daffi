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
    /// uuids parked since the last `drainParked`.  The asyncio waiter asks for
    /// this list instead of probing every pending future.
    ready: std.ArrayList(u16) = .empty,
    /// A wakeup is in flight; further parked responses wait for `drainParked`
    /// to clear it, so each burst is one write to `response_fd`.
    armed: bool = false,

const Waiter = struct {
    cond: Condition = .{},
    msg: ?*Message = null,
    expired: bool = false,
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
    self.ready.deinit(self.allocator);
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
    self.ready.append(self.allocator, uuid) catch {
        _ = self.map.fetchRemove(uuid);
        return error.OutOfMemory;
    };
    return .parked;
}

/// Wake asyncio waiters after a response was parked, unless a wakeup is
/// already waiting to be drained.
pub fn triggerWakeup(self: *ClientMessageStore) void {
    if (comptime @import("builtin").target.os.tag == .freestanding) return;
    self.mutex.lock();
    defer self.mutex.unlock();
    self.triggerWakeupLocked();
}

fn triggerWakeupLocked(self: *ClientMessageStore) void {
    if (self.armed) return;
    if (self.response_fd < 0) return;
    self.armed = true;
    const val: u64 = 1;
    const n = write(@intCast(self.response_fd), @as([*]const u8, @ptrCast(&val)), @sizeOf(u64));
    if (n <= 0) self.armed = false;
}

pub fn setResponseFd(self: *ClientMessageStore, fd: i32) void {
    self.mutex.lock();
    self.response_fd = fd;
    const pending = self.ready.items.len > 0;
    self.armed = false;
    self.mutex.unlock();
    if (fd >= 0 and pending) self.triggerWakeup();
}

/// Take the uuids of every response parked since the last drain.  The
/// messages stay in `map` until `fetch`.  Call after a wakeup; further
/// parkings will write the fd again.
pub fn drainParked(self: *ClientMessageStore, out: *std.ArrayList(u16), out_alloc: Allocator) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    try out.appendSlice(out_alloc, self.ready.items);
    self.ready.clearRetainingCapacity();
    self.armed = false;
}

fn dropReady(self: *ClientMessageStore, uuid: u16) void {
    var i: usize = 0;
    while (i < self.ready.items.len) {
        if (self.ready.items[i] == uuid) {
            _ = self.ready.swapRemove(i);
        } else {
            i += 1;
        }
    }
}

/// Retrieve and remove the response for uuid, if it arrived.
pub fn fetch(self: *ClientMessageStore, uuid: u16) ?*Message {
    self.mutex.lock();
    defer self.mutex.unlock();
    const kv = self.map.fetchRemove(uuid) orelse return null;
    self.dropReady(uuid);
    _ = self.pending.remove(uuid);
    return kv.value;
}

/// Block until the response for `uuid` arrives, `timeout_ms` passes, or the
/// connection closes.  A response that arrived earlier is returned at once.
pub fn wait(self: *ClientMessageStore, uuid: u16, timeout_ms: u32) !WaitResult {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.map.fetchRemove(uuid)) |kv| {
        self.dropReady(uuid);
        _ = self.pending.remove(uuid);
        return .{ .message = kv.value };
    }
    if (self.closed) return .closed;
    var waiter = Waiter{};
    const deadline = misc.monotonicMs() + timeout_ms;
    self.waiters.put(uuid, &waiter) catch {
        // Hash map OOM: poll the store instead of registering a waiter.
        while (true) {
            if (self.map.fetchRemove(uuid)) |kv| {
                self.dropReady(uuid);
                _ = self.pending.remove(uuid);
                return .{ .message = kv.value };
            }
            if (self.closed) return .closed;
            const now = misc.monotonicMs();
            if (now >= deadline) return .timeout;
            self.mutex.unlock();
            if (comptime !is_wasm) {
                const ts = std.c.timespec{ .sec = 0, .nsec = std.time.ns_per_ms };
                _ = std.c.nanosleep(&ts, null);
            }
            self.mutex.lock();
        }
    };
    defer _ = self.waiters.remove(uuid);
    while (waiter.msg == null and !self.closed and !waiter.expired) {
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
    if (self.waiters.get(uuid)) |waiter| {
        defer self.mutex.unlock();
        waiter.*.expired = true;
        waiter.*.cond.signal();
        if (self.track_pending) _ = self.pending.remove(uuid);
        if (!self.closed) try self.expired.put(uuid, {});
        return;
    }
    const kv = self.map.fetchRemove(uuid);
    if (kv == null) {
        defer self.mutex.unlock();
        // Already taken: there is nothing left to drop.
        if (self.track_pending and !self.pending.remove(uuid)) return;
        self.dropReady(uuid);
        if (!self.closed) try self.expired.put(uuid, {});
        return;
    }
    self.dropReady(uuid);
    _ = self.pending.remove(uuid);
    self.mutex.unlock();
    kv.?.value.deinit();
}

/// Issue `uuid` to a new request, unless one still waiting has it.  An
/// expired uuid is only reused with `reuse_expired`: its response may still
/// be on the way, and is then dropped as the new request's.
pub fn claim(self: *ClientMessageStore, uuid: u16, reuse_expired: bool) !bool {
    self.mutex.lock();
    if (self.pending.contains(uuid) or self.waiters.contains(uuid) or (!reuse_expired and self.expired.contains(uuid))) {
        self.mutex.unlock();
        return false;
    }
    errdefer self.mutex.unlock();
    if (self.track_pending) try self.pending.put(uuid, {});
    _ = self.expired.remove(uuid);
    const stale = self.map.fetchRemove(uuid);
    if (stale != null) self.dropReady(uuid);
    self.mutex.unlock();
    if (stale) |kv| kv.value.deinit();
    return true;
}

/// Next free uuid after `counter`, never 0.  `reuse_expired` allows ids whose
/// caller already gave up.  Null when every id is still waiting.
pub fn claimNext(self: *ClientMessageStore, counter: *std.atomic.Value(u16), reuse_expired: bool) !?u16 {
    var tries: u32 = 0;
    while (tries < std.math.maxInt(u16)) : (tries += 1) {
        const next = counter.fetchAdd(1, .monotonic) +% 1;
        if (next == 0) continue;
        if (try self.claim(next, reuse_expired)) return next;
    }
    return null;
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

test "drainParked names every parked uuid once and coalesces wakeups" {
    if (comptime is_wasm) return;
    const c = @import("posix_c");
    var s = ClientMessageStore.init(std.testing.allocator);
    s.track_pending = true;
    defer s.deinit();

    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.socketpair(c.AF_UNIX, c.SOCK_STREAM, 0, &fds));
    defer {
        _ = c.close(fds[0]);
        _ = c.close(fds[1]);
    }
    s.setResponseFd(fds[1]);

    try std.testing.expect(try s.claim(11, false));
    try std.testing.expect(try s.claim(12, false));
    const m1 = try testResponse(11, "a");
    const m2 = try testResponse(12, "b");
    try std.testing.expectEqual(InsertResult.parked, try s.insert(m1));
    s.triggerWakeup();
    try std.testing.expectEqual(InsertResult.parked, try s.insert(m2));
    s.triggerWakeup();

    var buf: [16]u8 = undefined;
    const n = c.read(fds[0], &buf, buf.len);
    try std.testing.expectEqual(@as(isize, 8), n);

    var uuids: std.ArrayList(u16) = .empty;
    defer uuids.deinit(std.testing.allocator);
    try s.drainParked(&uuids, std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), uuids.items.len);
    try std.testing.expect(std.mem.indexOfScalar(u16, uuids.items, 11) != null);
    try std.testing.expect(std.mem.indexOfScalar(u16, uuids.items, 12) != null);

    // Messages stay until fetch, and a fetch is not listed again.
    s.fetch(11).?.deinit();
    uuids.clearRetainingCapacity();
    try s.drainParked(&uuids, std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), uuids.items.len);
    s.fetch(12).?.deinit();
}
