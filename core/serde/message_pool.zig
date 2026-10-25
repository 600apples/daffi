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

pub const StreamReadError = error{
    IncompleteMessage,
    EOF,
};

/// Read exactly buf.len bytes from reader, looping over partial reads.
/// A single read() syscall on a TCP socket may return fewer bytes than
/// requested even on localhost at high message rates.  The original
/// single-read implementation would leave the tail of buf uninitialised,
/// causing Header.fromBytes() to parse garbage and eventually leading to
/// an enormous alloc() → OutOfMemory → ConnectionLost chain.
fn mustRead(reader: anytype, buf: []u8) !void {
    var total: usize = 0;
    while (total < buf.len) {
        const n = try reader.read(buf[total..]);
        if (n == 0) return StreamReadError.EOF;
        total += n;
    }
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
        const raw_message = try RawMessage.create(self.allocator, data, uuid, flag, decoder, is_bytes, return_result, transmitter, receiver, func_name);
        defer self.allocator.free(raw_message.data);
        try raw_message.sendTo(writer);
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

    /// Receive one framed message from `reader`.
    ///
    /// The header comes from an untrusted peer, so it is validated before it is
    /// used (`Header.parse`), and the payload buffer is only sized from the
    /// claimed `msg_len` once the first `INITIAL_RECV_CHUNK` bytes have arrived.
    /// Otherwise any peer that can reach the port could make us reserve up to
    /// 32 MiB per connection just by sending a 9-byte header.
    pub fn receiveMessage(self: *Self, reader: anytype) !*Message {
        var header_buf: [serde.HEADER_SIZE]u8 = undefined;
        try mustRead(reader, &header_buf);
        const header = try Header.parse(&header_buf);
        const total: usize = @as(usize, serde.HEADER_SIZE) + header.msg_len;

        var buf = try self.allocator.alloc(u8, @min(total, INITIAL_RECV_CHUNK));
        errdefer self.allocator.free(buf);
        @memcpy(buf[0..header_buf.len], &header_buf);
        var filled: usize = header_buf.len;
        while (filled < total) {
            if (filled == buf.len) {
                buf = try self.allocator.realloc(buf, total);
            }
            try mustRead(reader, buf[filled..]);
            filled = buf.len;
        }
        return try Message.create(self.allocator, header, buf);
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

/// Push-based counterpart of `MessagePool.receiveMessage` for the evented
/// model: bytes are fed as they arrive and complete messages come out.  Same
/// guarantees — the header is validated before anything is allocated and the
/// body buffer is sized from it only after `INITIAL_RECV_CHUNK` bytes arrived.
pub const FrameDecoder = struct {
    allocator: Allocator,
    header_buf: [serde.HEADER_SIZE]u8 = undefined,
    header_filled: usize = 0,
    header: Header = undefined,
    /// Whole frame (header included) once the header is parsed.
    frame: []u8 = &.{},
    filled: usize = 0,

    pub fn init(allocator: Allocator) FrameDecoder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FrameDecoder) void {
        if (self.frame.len != 0) self.allocator.free(self.frame);
        self.* = undefined;
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
        }

        const frame = self.frame;
        self.frame = &.{};
        self.header_filled = 0;
        self.filled = 0;
        errdefer self.allocator.free(frame);
        return try Message.create(self.allocator, self.header, frame);
    }
};

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
