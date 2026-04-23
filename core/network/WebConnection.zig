const std = @import("std");
const net = @import("posix_net.zig");
const ascii = std.ascii;
const misc = @import("../misc.zig");
const Allocator = std.mem.Allocator;
const serde = @import("../serde.zig");
const tls_impl = @import("tls.zig");
pub const Handshake = @import("../network/web/handshake.zig").Handshake;
pub const HandshakePool = @import("../network/web/handshake.zig").Pool;
pub const framing = @import("../network/web/framing.zig");
pub const Fragmented = framing.Fragmented;
pub const Reader = @import("../network/web/reader.zig").Reader;
pub const buffer = @import("../network/web/buffer.zig");
pub const MessageType = @import("../network/web/reader.zig").MessageType;
pub const OpCode = framing.OpCode;
const OperationTable = @import("../network.zig").OperationTable;
const WsMessage = @import("../network/web/reader.zig").Message;

const WebConnection = @This();

pub const op_table = OperationTable{
    .read = read,
    .readNoBuffer = readNoBuffer,
    .write = write,
    .accept = accept,
    .close = close,
    .destroy = destroy,
    .getAddr = getAddr,
};

pub const ReadError = anyerror;
pub const WriteError = anyerror;

const CLOSE_NORMAL = ([_]u8{ @intFromEnum(OpCode.close), 2, 3, 232 })[0..]; // code: 1000
const CLOSE_PROTOCOL_ERROR = ([_]u8{ @intFromEnum(OpCode.close), 2, 3, 234 })[0..]; //code: 1002

buffer_pool: buffer.Pool,
buffer_provider: buffer.Provider,
reader: Reader,
stream: net.Stream,
addr: ?net.Address,
allocator: Allocator,
/// Non-null when the WebSocket connection runs over TLS (WSS).
/// The ssl object is owned by this WebConnection and freed in close().
ssl: ?*tls_impl.SslConn = null,

pub const Config = struct {};

pub fn init(allocator: Allocator, stream: net.Stream, addr: net.Address, _: Config) !*WebConnection {
    const self = try allocator.create(WebConnection);
    errdefer allocator.destroy(self);
    // Assign fields directly into the heap struct so that the internal
    // pointers (buffer_provider.pool → buffer_pool, reader.bp → buffer_provider)
    // reference stable heap addresses rather than local stack variables that
    // would become dangling as soon as this function returns.
    self.allocator = allocator;
    self.stream = stream;
    self.addr = addr;
    self.ssl = null;
    self.buffer_pool = try buffer.Pool.init(allocator, 32, 32768);
    self.buffer_provider = buffer.Provider.init(allocator, &self.buffer_pool, 32768);
    self.reader = try Reader.init(5120, serde.MAX_BYTES_MESSAGE, &self.buffer_provider);
    return self;
}

/// Create a WSS (WebSocket Secure) connection from an already-completed TLS handshake.
/// Takes ownership of `ssl`; it will be freed in close().
pub fn initWithTls(allocator: Allocator, stream: net.Stream, addr: net.Address, _: Config, ssl: *tls_impl.SslConn) !*WebConnection {
    const self = try allocator.create(WebConnection);
    errdefer allocator.destroy(self);
    self.allocator = allocator;
    self.stream = stream;
    self.addr = addr;
    self.ssl = ssl;
    self.buffer_pool = try buffer.Pool.init(allocator, 32, 32768);
    self.buffer_provider = buffer.Provider.init(allocator, &self.buffer_pool, 32768);
    self.reader = try Reader.init(5120, serde.MAX_BYTES_MESSAGE, &self.buffer_provider);
    return self;
}

pub fn read(_: *anyopaque, _: []u8) !usize {
    @panic("read with buffer not implemented");
}

pub fn readNoBuffer(ctx: *anyopaque) !?[]const u8 {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    return try self.readInternal();
}

pub fn write(ctx: *anyopaque, data: []const u8) !void {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    try self.writeBin(data);
}

pub fn accept(_: *anyopaque) !@import("../network/connection.zig").AcceptedConnection {
    @panic("not implemented");
}

pub fn getAddr(ctx: *anyopaque) ?@import("../network/connection.zig").NetAddress {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    if (self.addr) |addr| {
        var na = @import("../network/connection.zig").NetAddress{};
        const len = @min(na.bytes.len, addr.bytes.len);
        @memcpy(na.bytes[0..len], addr.bytes[0..len]);
        return na;
    }
    return null;
}

/// Write data through TLS if this is a WSS connection, otherwise plain TCP.
fn writeAllBuf(self: *WebConnection, data: []const u8) !void {
    if (self.ssl) |ssl| return tls_impl.sslWrite(ssl, data);
    return self.stream.writeAll(data);
}

/// Read the next WebSocket message, dispatching through TLS when ssl != null.
fn readMessageFromStream(self: *WebConnection) !WsMessage {
    if (self.ssl) |ssl| {
        return self.reader.readMessage(tls_impl.TlsStream{ .ssl = ssl });
    }
    return self.reader.readMessage(self.stream);
}

fn readInternal(self: *WebConnection) !?[]const u8 {
    const message = self.readMessageFromStream() catch |err| {
        switch (err) {
            error.LargeControl => try self.writeAllBuf(CLOSE_PROTOCOL_ERROR),
            error.ReservedFlags => try self.writeAllBuf(CLOSE_PROTOCOL_ERROR),
            else => {},
        }
        return null;
    };
    switch (message.type) {
        .text, .binary => {
            self.reader.handled();
            return message.data;
        },
        .pong => {
            // Unsolicited pong from the browser — ignore silently.
        },
        .ping => {
            // Respond to keep-alive pings from the browser.
            const data = message.data;
            if (data.len > 0) {
                try self.writeFrame(.pong, data);
            }
        },
        .close => {
            // Browser initiated close handshake: validate the payload and echo
            // back an appropriate close frame, then return null so the receive
            // loop breaks and triggers the normal disconnect path.
            const data = message.data;
            const l = data.len;
            if (l == 0) {
                self.writeClose() catch {};
                return null;
            }
            if (l == 1) {
                // close payload must be either empty or at least 2 bytes (status code)
                self.writeAllBuf(CLOSE_PROTOCOL_ERROR) catch {};
                return null;
            }
            const code = @as(u16, @intCast(data[1])) | (@as(u16, @intCast(data[0])) << 8);
            if (code < 1000 or code == 1004 or code == 1005 or code == 1006 or (code > 1013 and code < 3000)) {
                self.writeAllBuf(CLOSE_PROTOCOL_ERROR) catch {};
                return null;
            }
            if (l == 2) {
                self.writeAllBuf(CLOSE_NORMAL) catch {};
                return null;
            }
            const payload = data[2..];
            if (!std.unicode.utf8ValidateSlice(payload)) {
                self.writeAllBuf(CLOSE_PROTOCOL_ERROR) catch {};
                return null;
            }
            self.writeClose() catch {};
            return null;
        },
    }
    return null;
}

fn writeBin(self: *WebConnection, data: []const u8) !void {
    return self.writeFrame(.binary, data);
}

fn writeText(self: *WebConnection, data: []const u8) !void {
    return self.writeFrame(.text, data);
}

fn writeClose(self: *WebConnection) !void {
    return self.writeAllBuf(CLOSE_NORMAL);
}

fn writeCloseWithCode(self: *WebConnection, code: u16) !void {
    var buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &buf, code, .Big);
    return self.writeFrame(.close, &buf);
}

fn writeFrame(self: *WebConnection, op_code: WebConnection.OpCode, data: []const u8) !void {
    const l = data.len;

    // maximum possible prefix length. op_code + length_type + 8byte length
    var buf: [10]u8 = undefined;
    buf[0] = @intFromEnum(op_code);

    if (l <= 125) {
        buf[1] = @intCast(l);
        try self.writeAllBuf(buf[0..2]);
    } else if (l < 65536) {
        buf[1] = 126;
        buf[2] = @intCast((l >> 8) & 0xFF);
        buf[3] = @intCast(l & 0xFF);
        try self.writeAllBuf(buf[0..4]);
    } else {
        buf[1] = 127;
        buf[2] = @intCast((l >> 56) & 0xFF);
        buf[3] = @intCast((l >> 48) & 0xFF);
        buf[4] = @intCast((l >> 40) & 0xFF);
        buf[5] = @intCast((l >> 32) & 0xFF);
        buf[6] = @intCast((l >> 24) & 0xFF);
        buf[7] = @intCast((l >> 16) & 0xFF);
        buf[8] = @intCast((l >> 8) & 0xFF);
        buf[9] = @intCast(l & 0xFF);
        try self.writeAllBuf(buf[0..]);
    }
    if (l > 0) {
        try self.writeAllBuf(data);
    }
}

pub fn deinit(self: *WebConnection) void {
    self.reader.deinit();
    self.buffer_pool.deinit();
    self.allocator.destroy(self);
}

pub fn close(ctx: *anyopaque) void {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| {
        tls_impl.sslClose(ssl);
        self.ssl = null;
    }
    self.stream.close();
}

pub fn destroy(ctx: *anyopaque) void {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    self.deinit();
}

pub const SynParser = struct {
    handshake_pool: *HandshakePool,

    pub fn init(allocator: Allocator) !SynParser {
        const handshake_pool = try HandshakePool.init(allocator, 1, 512, 10);
        return .{
            .handshake_pool = handshake_pool,
        };
    }

    pub fn deinit(self: *SynParser) void {
        self.handshake_pool.deinit();
    }

    /// Read the full HTTP upgrade request from `stream`, starting at `initial_pos` in `buf`.
    ///
    /// Works with any stream that provides `.read([]u8) !usize`.
    /// Socket-level timeouts (SO_RCVTIMEO) are only set when the stream has a `.handle`
    /// field (plain `net.Stream`); TLS streams rely on the underlying TCP timeout instead.
    fn readHandshakeRequest(_: *SynParser, stream: anytype, buf: []u8, initial_pos: usize, timeout: ?u32) ![]u8 {
        const StreamT = @TypeOf(stream);
        var deadline: ?i64 = null;
        var read_timeout: ?[@sizeOf(std.posix.timeval)]u8 = null;
        if (timeout) |ms| {
            if (comptime @hasField(StreamT, "handle")) {
                read_timeout = std.mem.toBytes(std.posix.timeval{
                    .sec = @intCast(@divTrunc(ms, 1000)),
                    .usec = @intCast(@mod(ms, 1000) * 1000),
                });
            }
            deadline = misc.milliTimestamp() + ms;
        }

        var total: usize = initial_pos;
        while (true) {
            if (total == buf.len) {
                return error.TooLarge;
            }

            if (comptime @hasField(StreamT, "handle")) {
                if (read_timeout) |to| {
                    try std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, &to);
                }
            }
            const n = try stream.read(buf[total..]);
            if (n == 0) {
                return error.Invalid;
            }
            total += n;
            const request = buf[0..total];
            if (std.mem.endsWith(u8, request, "\r\n\r\n")) {
                if (comptime @hasField(StreamT, "handle")) {
                    if (read_timeout != null) {
                        const read_no_timeout = std.mem.toBytes(std.posix.timeval{ .sec = 0, .usec = 0 });
                        try std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, &read_no_timeout);
                    }
                }
                return request;
            }

            if (deadline) |dl| {
                if (misc.milliTimestamp() > dl) {
                    return error.Timeout;
                }
            }
        }
    }

    /// Detect whether the incoming connection is a WebSocket upgrade request.
    ///
    /// Reads exactly `HEADER_SIZE` bytes from `stream`.  If they start with "GET",
    /// the full HTTP upgrade handshake is completed in place and `true` is returned.
    /// Otherwise those bytes were the daffi SYN probe and `false` is returned.
    ///
    /// `stream` can be a plain `net.Stream` *or* a `tls_impl.TlsStream` — anything
    /// that provides `.read([]u8) !usize`, `.write([]const u8) !usize`, and
    /// `.writeAll([]const u8) !void`.
    pub fn tryWebSocket(self: *SynParser, stream: anytype) !bool {
        var buf: [serde.HEADER_SIZE]u8 = undefined;

        _ = try stream.read(&buf);
        if (ascii.startsWithIgnoreCase(&buf, "get")) {
            var handshake_state = try self.handshake_pool.acquire();
            defer self.handshake_pool.release(handshake_state);

            var handshake_buffer = handshake_state.buffer;
            @memcpy(handshake_buffer[0..buf.len], &buf);
            const request = self.readHandshakeRequest(stream, handshake_buffer, serde.HEADER_SIZE, 5000) catch |err| {
                const s: []const u8 = switch (err) {
                    error.Invalid => "HTTP/1.1 400 Invalid\r\nerror: invalid\r\ncontent-length: 0\r\n\r\n",
                    error.TooLarge => "HTTP/1.1 400 Invalid\r\nerror: too large\r\ncontent-length: 0\r\n\r\n",
                    error.Timeout => "HTTP/1.1 400 Invalid\r\nerror: timeout\r\ncontent-length: 0\r\n\r\n",
                    else => "HTTP/1.1 400 Invalid\r\nerror: unknown\r\ncontent-length: 0\r\n\r\n",
                };
                _ = try stream.write(s);
                return error.HandshakeFailed;
            };

            const h = WebConnection.Handshake.parse(request, &handshake_state.headers) catch |err| {
                try WebConnection.Handshake.close(stream, err);
                return error.HandshakeFailed;
            };
            try h.reply(stream);
            return true;
        }
        return false;
    }
};
