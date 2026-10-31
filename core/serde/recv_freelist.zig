const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = @import("../misc.zig").Mutex;

/// Thread-safe size-class freelist for receive-side frame buffers and message
/// shells.  Receive runs on the connection thread; `Message.deinit` often runs
/// on a Python worker after dispatch, so every acquire/release takes the mutex.
///
/// Bounded fixed stacks (not `ArrayList`): Zig's ArrayList `SafetyLock` is a
/// single-threaded debug check and races under concurrent freelist use even
/// when an external mutex serialises the logical operations.
///
/// Buffers larger than the biggest class bypass the pool (alloc/free directly).
pub const RecvFreelist = struct {
    mutex: Mutex = .{},
    buf_len: [class_sizes.len]usize = @splat(0),
    buffers: [class_sizes.len][max_per_class]?[]u8 = @splat(@splat(null)),
    /// Recycled `Message` shells (`*anyopaque` avoids a cycle with message.zig).
    msg_len: usize = 0,
    messages: [max_messages]?*anyopaque = @splat(null),

    /// Capacities that cover typical RPC frames and `INITIAL_RECV_CHUNK`.
    pub const class_sizes = [_]usize{ 4 * 1024, 16 * 1024, 64 * 1024 };
    pub const max_per_class: usize = 64;
    pub const max_messages: usize = 128;

    /// Free every cached buffer and message shell.  `T` is the message type
    /// whose shells were stored via `acquireMessage`/`releaseMessage`.
    pub fn deinit(self: *RecvFreelist, allocator: Allocator, comptime T: type) void {
        self.mutex.lock();
        for (&self.buffers, &self.buf_len) |*slot, *n| {
            var i: usize = 0;
            while (i < n.*) : (i += 1) {
                if (slot[i]) |buf| allocator.free(buf);
                slot[i] = null;
            }
            n.* = 0;
        }
        var i: usize = 0;
        while (i < self.msg_len) : (i += 1) {
            if (self.messages[i]) |ptr| {
                allocator.destroy(@as(*T, @ptrCast(@alignCast(ptr))));
                self.messages[i] = null;
            }
        }
        self.msg_len = 0;
        // Unlock the live mutex, then clear — do not `self.* = .{}` while locked
        // (that would replace the held pthread mutex with a fresh unlocked one).
        self.mutex.unlock();
        self.* = .{};
    }

    /// Smallest class that fits `len`, or null when `len` exceeds every class.
    pub fn classFor(len: usize) ?usize {
        for (class_sizes, 0..) |sz, i| {
            if (len <= sz) return i;
        }
        return null;
    }

    /// Allocate a buffer of at least `min_len` bytes.  The returned slice length
    /// is the capacity (a class size, or exact `min_len` when unpooled).
    pub fn allocBuf(self: *RecvFreelist, allocator: Allocator, min_len: usize) ![]u8 {
        if (classFor(min_len)) |ci| {
            self.mutex.lock();
            if (self.buf_len[ci] > 0) {
                self.buf_len[ci] -= 1;
                const buf = self.buffers[ci][self.buf_len[ci]].?;
                self.buffers[ci][self.buf_len[ci]] = null;
                self.mutex.unlock();
                return buf;
            }
            self.mutex.unlock();
            return try allocator.alloc(u8, class_sizes[ci]);
        }
        return try allocator.alloc(u8, min_len);
    }

    /// Grow `old` (full capacity slice) to at least `new_len`.  Preserves the
    /// first `filled` bytes.  May return `old` when it already fits.
    pub fn reallocBuf(self: *RecvFreelist, allocator: Allocator, old: []u8, filled: usize, new_len: usize) ![]u8 {
        if (old.len >= new_len) return old;
        const fresh = try self.allocBuf(allocator, new_len);
        @memcpy(fresh[0..filled], old[0..filled]);
        self.freeBuf(allocator, old);
        return fresh;
    }

    /// Return a full-capacity buffer to the pool, or free it when the class is
    /// full / the size is not pooled.
    pub fn freeBuf(self: *RecvFreelist, allocator: Allocator, buf: []u8) void {
        if (buf.len == 0) return;
        const ci = blk: {
            for (class_sizes, 0..) |sz, i| {
                if (buf.len == sz) break :blk i;
            }
            allocator.free(buf);
            return;
        };
        self.mutex.lock();
        if (self.buf_len[ci] >= max_per_class) {
            self.mutex.unlock();
            allocator.free(buf);
            return;
        }
        self.buffers[ci][self.buf_len[ci]] = buf;
        self.buf_len[ci] += 1;
        self.mutex.unlock();
    }

    /// Allocate a `T` (typically `Message`) from the shell freelist or the heap.
    pub fn acquireMessage(self: *RecvFreelist, allocator: Allocator, comptime T: type) !*T {
        self.mutex.lock();
        if (self.msg_len > 0) {
            self.msg_len -= 1;
            const ptr = self.messages[self.msg_len].?;
            self.messages[self.msg_len] = null;
            self.mutex.unlock();
            return @ptrCast(@alignCast(ptr));
        }
        self.mutex.unlock();
        return try allocator.create(T);
    }

    /// Recycle a message shell, or destroy it when the shell freelist is full.
    pub fn releaseMessage(self: *RecvFreelist, allocator: Allocator, comptime T: type, msg: *T) void {
        self.mutex.lock();
        if (self.msg_len >= max_messages) {
            self.mutex.unlock();
            allocator.destroy(msg);
            return;
        }
        self.messages[self.msg_len] = msg;
        self.msg_len += 1;
        self.mutex.unlock();
    }
};

test "classFor picks the smallest fitting class" {
    try std.testing.expect(RecvFreelist.classFor(1).? == 0);
    try std.testing.expect(RecvFreelist.classFor(4 * 1024).? == 0);
    try std.testing.expect(RecvFreelist.classFor(4 * 1024 + 1).? == 1);
    try std.testing.expect(RecvFreelist.classFor(64 * 1024).? == 2);
    try std.testing.expect(RecvFreelist.classFor(64 * 1024 + 1) == null);
}

test "allocBuf recycles a class-sized buffer" {
    const allocator = std.testing.allocator;
    var pool: RecvFreelist = .{};
    defer pool.deinit(allocator, u8);

    const a = try pool.allocBuf(allocator, 100);
    try std.testing.expectEqual(@as(usize, 4 * 1024), a.len);
    pool.freeBuf(allocator, a);
    const b = try pool.allocBuf(allocator, 200);
    try std.testing.expect(a.ptr == b.ptr);
    pool.freeBuf(allocator, b);
}

test "allocBuf bypasses the pool for oversized buffers" {
    const allocator = std.testing.allocator;
    var pool: RecvFreelist = .{};
    defer pool.deinit(allocator, u8);

    const big = try pool.allocBuf(allocator, 128 * 1024);
    try std.testing.expectEqual(@as(usize, 128 * 1024), big.len);
    pool.freeBuf(allocator, big);
    try std.testing.expectEqual(@as(usize, 0), pool.buf_len[0]);
    try std.testing.expectEqual(@as(usize, 0), pool.buf_len[1]);
    try std.testing.expectEqual(@as(usize, 0), pool.buf_len[2]);
}
