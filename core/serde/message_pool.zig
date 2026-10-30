const std = @import("std");
const serde = @import("../serde.zig");

const ascii = std.ascii;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const Header = serde.Header;
const Metadata = serde.Metadata;
const Message = serde.Message;
const RawMessage = serde.RawMessage;
const MessageFlag = serde.MessageFlag;
const MessageDecoder = serde.MessageDecoder;
const print = std.debug.print;

/// First allocation made for an incoming message body.  Only once the peer
/// has actually sent that much is the buffer grown to the declared size, so a
/// bare header cannot make us reserve up to 32 MiB.  A single jump (instead of
/// doubling) matters: each realloc copies and faults in fresh pages, which
/// cost ~30% throughput on multi-MiB messages.  Large allocations are backed
/// lazily by the OS, so resident memory still follows the bytes received.
const INITIAL_RECV_CHUNK: usize = 64 * 1024;

/// Bytes past `INITIAL_RECV_CHUNK` that unfinished frames hold, summed over
/// every connection in the process.  A frame that would take the sum past
/// `max_partial_bytes` fails with `error.FrameBudgetExceeded`, which closes
/// its connection: many peers that each start a large message and never
/// finish it must not exhaust memory.  The first chunk of each frame is not
/// counted, so small messages never touch the shared counter.
pub var max_partial_bytes: usize = 1024 * 1024 * 1024;
var partial_bytes: std.atomic.Value(usize) = .init(0);

pub fn partialBytes() usize {
    return partial_bytes.load(.monotonic);
}

pub const MessagePool = struct {
    allocator: Allocator,
    // web_connection: ?*WebConnection,

    const Self = @This();

    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            // .web_connection = null,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        // if (self.web_connection) |web_connection| web_connection.deinit();
        self.allocator.destroy(self);
    }

    /// Messages that fit here are framed on the stack. A typical RPC (header,
    /// three short names, a small pickle) is a few hundred bytes, and allocating
    /// that buffer on every send showed up in the call latency. A larger
    /// payload is not copied: its header and metadata go out in front of it.
    const send_scratch_len: usize = 8 * 1024;

    pub fn sendMessage(
        self: *Self,
        writer: anytype,
        data: []const u8,
        uuid: u16,
        flag: MessageFlag,
        decoder: MessageDecoder,
        is_bytes: bool,
        return_result: bool,
        transmitter: ?[]const u8,
        receiver: ?[]const u8,
        func_name: ?[]const u8,
    ) !void {
        const n = try RawMessage.encodedLen(data, transmitter, receiver, func_name);
        if (n <= send_scratch_len) {
            var scratch: [send_scratch_len]u8 = undefined;
            try RawMessage.encodeInto(scratch[0..n], data, uuid, flag, decoder, is_bytes, return_result, transmitter, receiver, func_name);
            const raw_message = RawMessage{ .data = scratch[0..n] };
            try raw_message.sendTo(writer);
            return;
        }
        const prefix_len = n - data.len;
        var scratch: [send_scratch_len]u8 = undefined;
        const prefix = if (prefix_len <= scratch.len) scratch[0..prefix_len] else try self.allocator.alloc(u8, prefix_len);
        defer if (prefix_len > scratch.len) self.allocator.free(prefix);
        _ = try RawMessage.encodePrefixInto(prefix, data, uuid, flag, decoder, is_bytes, return_result, transmitter, receiver, func_name);
        try writer.writeParts(prefix, data);
    }

    pub fn createMessage(
        _: *Self,
        allocator: Allocator,
        data: []const u8,
        uuid: u16,
        flag: MessageFlag,
        decoder: MessageDecoder,
        is_bytes: bool,
        return_result: bool,
        transmitter: ?[]const u8,
        receiver: ?[]const u8,
        func_name: ?[]const u8,
    ) ![]u8 {
        return (try RawMessage.create(allocator, data, uuid, flag, decoder, is_bytes, return_result, transmitter, receiver, func_name)).data;
    }

    pub fn sendSynMessage(_: *Self, writer: anytype) !void {
        // Create and send SYN message. This message is used to distinguish between websockets and raw TCP connections.
        const fulfillment: [serde.HEADER_SIZE]u8 = @splat(ascii.control_code.us);
        _ = try writer.write(&fulfillment);
    }

    pub fn receiveWsMessage(self: *Self, reader: anytype) !?*Message {
        const data = (try reader.readNoBuffer()) orelse return null;
        return try self.buildWsMessage(data);
    }

    pub fn buildWsMessage(self: *Self, data: []const u8) !*Message {
        const header = try Header.parse(data);
        if (data.len != @as(usize, serde.HEADER_SIZE) + header.msg_len) return error.LengthMismatch;
        const data_buf = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(data_buf);
        return try Message.create(self.allocator, header, data_buf);
    }
};

/// Incremental frame decoder: bytes are fed as they arrive and complete
/// messages come out.  The header comes from an untrusted peer, so it is
/// validated before anything is allocated, and the body buffer is sized from
/// it only after `INITIAL_RECV_CHUNK` bytes arrived: a bare header must not
/// make us reserve up to 32 MiB per connection.
pub const FrameDecoder = struct {
    allocator: Allocator,
    header_buf: [serde.HEADER_SIZE]u8 = undefined,
    header_filled: usize = 0,
    header: Header = undefined,
    /// Whole frame (header included) once the header is parsed.
    frame: []u8 = &.{},
    filled: usize = 0,
    /// This frame's share of `partial_bytes`.
    budgeted: usize = 0,

    pub fn init(allocator: Allocator) FrameDecoder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FrameDecoder) void {
        if (self.frame.len != 0) self.allocator.free(self.frame);
        self.releaseBudget();
        self.* = undefined;
    }

    /// Whether a frame has started and not yet finished.
    pub fn partial(self: *const FrameDecoder) bool {
        return self.frame.len != 0 or self.header_filled != 0;
    }

    fn chargeBudget(self: *FrameDecoder) !void {
        if (self.filled <= INITIAL_RECV_CHUNK) return;
        const want = self.filled - INITIAL_RECV_CHUNK;
        if (want <= self.budgeted) return;
        const delta = want - self.budgeted;
        const before = partial_bytes.fetchAdd(delta, .monotonic);
        if (before + delta > max_partial_bytes) {
            _ = partial_bytes.fetchSub(delta, .monotonic);
            return error.FrameBudgetExceeded;
        }
        self.budgeted = want;
    }

    fn releaseBudget(self: *FrameDecoder) void {
        if (self.budgeted == 0) return;
        _ = partial_bytes.fetchSub(self.budgeted, .monotonic);
        self.budgeted = 0;
    }

    /// Consume bytes from the front of `input` until a message is complete
    /// (returned) or `input` is exhausted (null).  Call again with the rest of
    /// `input` to get further messages.
    pub fn next(self: *FrameDecoder, input: *[]const u8) !?*Message {
        if (self.frame.len == 0) {
            const n = @min(input.len, self.header_buf.len - self.header_filled);
            @memcpy(self.header_buf[self.header_filled..][0..n], input.*[0..n]);
            self.header_filled += n;
            input.* = input.*[n..];
            if (self.header_filled < self.header_buf.len) return null;

            self.header = try Header.parse(&self.header_buf);
            const total: usize = @as(usize, serde.HEADER_SIZE) + self.header.msg_len;
            self.frame = try self.allocator.alloc(u8, @min(total, INITIAL_RECV_CHUNK));
            @memcpy(self.frame[0..self.header_buf.len], &self.header_buf);
            self.filled = self.header_buf.len;
        }

        const total: usize = @as(usize, serde.HEADER_SIZE) + self.header.msg_len;
        while (self.filled < total) {
            if (input.len == 0) return null;
            if (self.filled == self.frame.len) {
                self.frame = try self.allocator.realloc(self.frame, total);
            }
            const n = @min(input.len, self.frame.len - self.filled);
            @memcpy(self.frame[self.filled..][0..n], input.*[0..n]);
            self.filled += n;
            input.* = input.*[n..];
            if (self.filled < total) try self.chargeBudget();
        }

        return try self.finish();
    }

    /// The unfilled tail of the current body when at least `min` bytes are
    /// still missing, so a large body can be read into place instead of
    /// through a scratch buffer.  Follow with `commit`.
    pub fn directBuffer(self: *FrameDecoder, min: usize) !?[]u8 {
        if (self.frame.len == 0) return null;
        const total: usize = @as(usize, serde.HEADER_SIZE) + self.header.msg_len;
        if (total - self.filled < min) return null;
        if (self.filled == self.frame.len) self.frame = try self.allocator.realloc(self.frame, total);
        return self.frame[self.filled..];
    }

    /// Account for `n` bytes read into `directBuffer`; returns the message
    /// once its body is complete.
    pub fn commit(self: *FrameDecoder, n: usize) !?*Message {
        self.filled += n;
        if (self.filled < @as(usize, serde.HEADER_SIZE) + self.header.msg_len) {
            try self.chargeBudget();
            return null;
        }
        return try self.finish();
    }

    fn finish(self: *FrameDecoder) !*Message {
        const frame = self.frame;
        self.frame = &.{};
        self.header_filled = 0;
        self.filled = 0;
        self.releaseBudget();
        errdefer self.allocator.free(frame);
        return try Message.create(self.allocator, self.header, frame);
    }
};

/// Read messages from a blocking connection until it fails or the peer
/// closes it, calling `dispatch(ctx, message)` for each one (it returns
/// false to stop).  Reads in chunks, so a burst of small messages costs one
/// read; a large body is read straight into its own buffer.
pub fn receiveLoop(allocator: Allocator, conn: anytype, ctx: anytype, comptime dispatch: anytype) anyerror!void {
    var decoder = FrameDecoder.init(allocator);
    defer decoder.deinit();
    var scratch: [16 * 1024]u8 = undefined;
    while (true) {
        if (try decoder.directBuffer(scratch.len)) |dst| {
            const n = try conn.read(dst);
            if (n == 0) return error.EOF;
            if (try decoder.commit(n)) |message| {
                if (!dispatch(ctx, message)) return error.Stopped;
            }
            conn.noteFrameProgress(decoder.partial());
            continue;
        }
        const n = try conn.read(&scratch);
        if (n == 0) return error.EOF;
        var input: []const u8 = scratch[0..n];
        while (try decoder.next(&input)) |message| {
            if (!dispatch(ctx, message)) return error.Stopped;
        }
        conn.noteFrameProgress(decoder.partial());
    }
}

/// Reads per readiness event before the event loop moves on to other
/// connections.
pub const max_reads_per_wake = 16;

pub const Drained = union(enum) {
    /// Nothing more to read for now; wait for the next readiness event.
    keep,
    /// `dispatch` asked to stop.
    stopped,
    /// The connection failed or the peer closed it (`error.EOF`).
    failed: anyerror,
};

/// Evented counterpart of `receiveLoop`: read what a readable connection
/// has, calling `dispatch(ctx, message)` for each message, and hand the loop
/// back.  It stops after a short read (the socket is drained; level-triggered
/// polling reports anything newer) or after `max_reads_per_wake` reads, unless
/// the connection holds input no readiness event would report (TLS).
pub fn drainReadable(decoder: *FrameDecoder, conn: anytype, scratch: []u8, ctx: anytype, comptime dispatch: anytype) Drained {
    var reads: usize = 0;
    while (true) {
        const direct = decoder.directBuffer(scratch.len) catch |err| return .{ .failed = err };
        const buf = direct orelse scratch;
        const n = conn.readSome(buf) catch |err| switch (err) {
            error.WouldBlock => return .keep,
            else => return .{ .failed = err },
        };
        if (n == 0) return .{ .failed = error.EOF };
        if (direct != null) {
            const done = decoder.commit(n) catch |err| return .{ .failed = err };
            if (done) |message| {
                if (!dispatch(ctx, message)) return .stopped;
            }
        } else {
            var input: []const u8 = buf[0..n];
            while (true) {
                const message = (decoder.next(&input) catch |err| return .{ .failed = err }) orelse break;
                if (!dispatch(ctx, message)) return .stopped;
            }
        }
        conn.noteFrameProgress(decoder.partial());
        reads += 1;
        if ((n < buf.len or reads >= max_reads_per_wake) and !conn.hasPendingInput()) return .keep;
    }
}

test "FrameDecoder budget refuses a large frame and is returned on close" {
    const allocator = std.testing.allocator;
    const saved = max_partial_bytes;
    defer max_partial_bytes = saved;
    max_partial_bytes = 100 * 1024;
    const before = partialBytes();

    const body = try allocator.alloc(u8, 400 * 1024);
    defer allocator.free(body);
    @memset(body, '1');
    const raw = try RawMessage.create(allocator, body, 3, .REQUEST, .JSON, false, true, "tx", "rx", "fn");
    defer allocator.free(raw.data);

    var first = FrameDecoder.init(allocator);
    var input: []const u8 = raw.data[0 .. INITIAL_RECV_CHUNK + 60 * 1024];
    try expect(try first.next(&input) == null);
    try expect(first.partial());
    try expect(partialBytes() - before == 60 * 1024);

    var second = FrameDecoder.init(allocator);
    input = raw.data[0 .. INITIAL_RECV_CHUNK + 60 * 1024];
    try std.testing.expectError(error.FrameBudgetExceeded, second.next(&input));
    second.deinit();
    first.deinit();
    try expect(partialBytes() == before);

    // Within the budget the whole message still arrives.
    max_partial_bytes = 1024 * 1024;
    var third = FrameDecoder.init(allocator);
    defer third.deinit();
    input = raw.data;
    const msg = (try third.next(&input)).?;
    defer msg.deinit();
    try expect(msg.header.uuid == 3);
    try expect(!third.partial());
    try expect(partialBytes() == before);
}

test "FrameDecoder reassembles messages split at arbitrary points" {
    const allocator = std.testing.allocator;
    const payload = "hello evented world";
    const raw1 = try RawMessage.create(allocator, payload, 7, .REQUEST, .PICKLE, false, true, "tx", "rx", "fn");
    defer allocator.free(raw1.data);
    const raw2 = try RawMessage.create(allocator, "second", 8, .REQUEST, .PICKLE, false, true, "tx", "rx", "fn");
    defer allocator.free(raw2.data);
    const stream = try std.mem.concat(allocator, u8, &.{ raw1.data, raw2.data });
    defer allocator.free(stream);

    for (1..stream.len + 1) |step| {
        var decoder = FrameDecoder.init(allocator);
        defer decoder.deinit();
        var got: usize = 0;
        var offset: usize = 0;
        while (offset < stream.len) : (offset += step) {
            var chunk: []const u8 = stream[offset..@min(stream.len, offset + step)];
            while (try decoder.next(&chunk)) |msg| {
                defer msg.deinit();
                try expect(msg.header.uuid == 7 + got);
                got += 1;
            }
        }
        try expect(got == 2);
    }
}

const FakeReadable = struct {
    data: []const u8,
    /// Most bytes one read returns.
    chunk: usize,
    pos: usize = 0,
    reads: usize = 0,
    /// Reads after which `hasPendingInput` still says yes.
    pending: usize = 0,

    fn readSome(self: *FakeReadable, buf: []u8) anyerror!usize {
        self.reads += 1;
        if (self.pos == self.data.len) return error.WouldBlock;
        const n = @min(buf.len, self.chunk, self.data.len - self.pos);
        @memcpy(buf[0..n], self.data[self.pos..][0..n]);
        self.pos += n;
        return n;
    }
    fn noteFrameProgress(_: *FakeReadable, _: bool) void {}
    fn hasPendingInput(self: *FakeReadable) bool {
        if (self.pending == 0) return false;
        self.pending -= 1;
        return true;
    }
};

const Received = struct {
    count: usize = 0,
    body_len: usize = 0,

    fn dispatch(self: *Received, message: *Message) bool {
        self.count += 1;
        self.body_len = message.getData().len;
        message.deinit();
        return true;
    }
};

fn framesOf(allocator: Allocator, body_len: usize, count: usize) ![]u8 {
    const body = try allocator.alloc(u8, body_len);
    defer allocator.free(body);
    @memset(body, 'x');
    const raw = try RawMessage.create(allocator, body, 1, .REQUEST, .OPAQUE, true, false, "tx", "rx", "fn");
    defer allocator.free(raw.data);
    const all = try allocator.alloc(u8, raw.data.len * count);
    for (0..count) |i| @memcpy(all[i * raw.data.len ..][0..raw.data.len], raw.data);
    return all;
}

test "drainReadable yields the loop after max_reads_per_wake full reads" {
    const allocator = std.testing.allocator;
    const data = try framesOf(allocator, 100, 1000);
    defer allocator.free(data);
    var conn = FakeReadable{ .data = data, .chunk = 1024 };
    var decoder = FrameDecoder.init(allocator);
    defer decoder.deinit();
    var scratch: [1024]u8 = undefined;
    var got = Received{};
    try expect(drainReadable(&decoder, &conn, &scratch, &got, Received.dispatch) == .keep);
    try std.testing.expectEqual(@as(usize, max_reads_per_wake), conn.reads);
    try expect(conn.pos < data.len);
}

test "drainReadable stops after a short read without another recv" {
    const allocator = std.testing.allocator;
    const data = try framesOf(allocator, 100, 3);
    defer allocator.free(data);
    var conn = FakeReadable{ .data = data, .chunk = 1024 };
    var decoder = FrameDecoder.init(allocator);
    defer decoder.deinit();
    var scratch: [1024]u8 = undefined;
    var got = Received{};
    try expect(drainReadable(&decoder, &conn, &scratch, &got, Received.dispatch) == .keep);
    try std.testing.expectEqual(@as(usize, 1), conn.reads);
    try std.testing.expectEqual(@as(usize, 3), got.count);
}

test "drainReadable keeps reading while the connection holds pending input" {
    const allocator = std.testing.allocator;
    const data = try framesOf(allocator, 100, 3);
    defer allocator.free(data);
    // Short reads, as from a TLS session with decrypted bytes left over.
    var conn = FakeReadable{ .data = data, .chunk = 50, .pending = 1000 };
    var decoder = FrameDecoder.init(allocator);
    defer decoder.deinit();
    var scratch: [1024]u8 = undefined;
    var got = Received{};
    try expect(drainReadable(&decoder, &conn, &scratch, &got, Received.dispatch) == .keep);
    try std.testing.expectEqual(@as(usize, 3), got.count);
}

test "drainReadable reads a large body in place" {
    const allocator = std.testing.allocator;
    const data = try framesOf(allocator, 3 * INITIAL_RECV_CHUNK, 1);
    defer allocator.free(data);
    var conn = FakeReadable{ .data = data, .chunk = 1 << 20 };
    var decoder = FrameDecoder.init(allocator);
    defer decoder.deinit();
    var scratch: [1024]u8 = undefined;
    var got = Received{};
    while (got.count == 0) {
        try expect(drainReadable(&decoder, &conn, &scratch, &got, Received.dispatch) == .keep);
    }
    try std.testing.expectEqual(@as(usize, 3 * INITIAL_RECV_CHUNK), got.body_len);
    // One small read for the header, then the body straight into place.
    try expect(conn.reads <= 4);
}
