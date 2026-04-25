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
        const fulfillment: [serde.HEADER_SIZE]u8 = [_]u8{ascii.control_code.us} ** serde.HEADER_SIZE;
        _ = try writer.write(&fulfillment);
    }

    pub fn receiveMessage(self: *Self, reader: anytype) !*Message {
        var header_buf: [serde.HEADER_SIZE]u8 = undefined;
        try mustRead(reader, &header_buf);
        const header = Header.fromBytes(&header_buf);
        const msg_len = header.msg_len + header_buf.len;
        const data_buf = try self.allocator.alloc(u8, msg_len);
        errdefer self.allocator.free(data_buf);
        @memcpy(data_buf[0..header_buf.len], &header_buf);
        try mustRead(reader, data_buf[header_buf.len..]);
        return try Message.create(self.allocator, header, data_buf);
    }

    pub fn receiveWsMessage(self: *Self, reader: anytype) !?*Message {
        const data = (try reader.readNoBuffer()) orelse return null;
        return try self.buildWsMessage(data);
    }

    pub fn buildWsMessage(self: *Self, data: []const u8) !*Message {
        const header = Header.fromBytes(data[0..serde.HEADER_SIZE]);
        const data_buf = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(data_buf);
        return try Message.create(self.allocator, header, data_buf);
    }
};
