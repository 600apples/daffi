const std = @import("std");
const net = @import("posix_net.zig");
const ascii = std.ascii;
const misc = @import("../misc.zig");
const Mutex = misc.Mutex;
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
    .readSome = readSome,
    .readNoBuffer = readNoBuffer,
    .write = write,
    .writeParts = writeParts,
    .writeNonBlocking = writeNonBlocking,
    .accept = accept,
    .handle = handle,
    .hasPendingInput = hasPendingInput,
    .close = close,
    .destroy = destroy,
    .getAddr = getAddr,
};

pub const ReadError = anyerror;
pub const WriteError = anyerror;

const CLOSE_NORMAL = ([_]u8{ @backingInt(OpCode.close), 2, 3, 232 })[0..]; // code: 1000
const CLOSE_PROTOCOL_ERROR = ([_]u8{ @backingInt(OpCode.close), 2, 3, 234 })[0..]; //code: 1002

buffer_provider: buffer.Provider,
reader: Reader,
stream: net.Stream,
addr: ?net.Address,
allocator: Allocator,
/// Non-null when the WebSocket connection runs over TLS (WSS).
/// The ssl object is owned by this WebConnection and freed in destroy().
ssl: ?*tls_impl.SslConn = null,
/// Set by close() once the socket has been shut down (see ClientConnection).
interrupted: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
/// Keeps frames whole: control frames written by the reader (pong, close)
/// and data frames written by senders share the socket.
write_mutex: Mutex = .{},

pub const Config = struct {};

pub fn init(allocator: Allocator, stream: net.Stream, addr: net.Address, _: Config) !*WebConnection {
    return create(allocator, stream, addr, null);
}

/// Create a WSS (WebSocket Secure) connection from an already-completed TLS handshake.
/// Takes ownership of `ssl`; it will be freed in destroy().
pub fn initWithTls(allocator: Allocator, stream: net.Stream, addr: net.Address, _: Config, ssl: *tls_impl.SslConn) !*WebConnection {
    return create(allocator, stream, addr, ssl);
}

fn create(allocator: Allocator, stream: net.Stream, addr: net.Address, ssl: ?*tls_impl.SslConn) !*WebConnection {
    const self = try allocator.create(WebConnection);
    errdefer allocator.destroy(self);
    // Fields are assigned in place: `reader` keeps a pointer to
    // `buffer_provider`, so both must live in the heap struct.
    self.* = .{
        .buffer_provider = buffer.Provider.initNoPool(allocator),
        .reader = undefined,
        .stream = stream,
        .addr = addr,
        .allocator = allocator,
        .ssl = ssl,
    };
    // Messages larger than the static buffer get a buffer of their own,
    // freed once handled; nothing is reserved up front.
    self.reader = try Reader.init(5120, serde.MAX_BYTES_MESSAGE, &self.buffer_provider);
    return self;
}

pub fn read(_: *anyopaque, _: []u8) !usize {
    @panic("read with buffer not implemented");
}

/// WebSocket sessions run on a blocking-pool thread in the evented model.
pub fn readSome(_: *anyopaque, _: []u8) !usize {
    @panic("readSome not supported for WebSocket connections");
}

pub fn handle(ctx: *anyopaque) std.posix.socket_t {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    return self.stream.handle;
}

/// WebSocket sessions are served by blocking reads, never by the event loop.
pub fn hasPendingInput(_: *anyopaque) bool {
    return false;
}

pub fn readNoBuffer(ctx: *anyopaque) !?[]const u8 {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    return try self.readInternal();
}

pub fn write(ctx: *anyopaque, data: []const u8) !void {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    try self.writeBin(data);
}

/// A frame header is only known for the whole message: always queued.
pub fn writeNonBlocking(_: *anyopaque, _: []const u8) !usize {
    return 0;
}

pub fn writeParts(ctx: *anyopaque, head: []const u8, body: []const u8) !void {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    try self.writeFrameParts(.binary, head, body);
}

pub fn accept(_: *anyopaque, _: c_int) !@import("../network/connection.zig").AcceptedConnection {
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

/// Next text or binary message, or null once the peer closed.  Pings are
/// answered and pongs skipped without ending the session.  The message
/// stays valid until the next call: a fragmented one lives in the
/// reassembly buffer, which is only freed then.
fn readInternal(self: *WebConnection) !?[]const u8 {
    self.reader.handled();
    while (true) {
        const message = self.readMessageFromStream() catch |err| {
            switch (err) {
                error.LargeControl, error.ReservedFlags => self.writeRaw(CLOSE_PROTOCOL_ERROR) catch {},
                else => {},
            }
            return null;
        };
        switch (message.type) {
            .text, .binary => return message.data,
            .pong => {},
            .ping => try self.writeFrame(.pong, message.data),
            .close => {
                self.answerClose(message.data);
                return null;
            },
        }
    }
}

/// Echo the close handshake the browser started, with the status RFC 6455
/// asks for.
fn answerClose(self: *WebConnection, data: []const u8) void {
    const l = data.len;
    if (l == 0) {
        self.writeClose() catch {};
        return;
    }
    // A close payload is either empty or starts with a 2-byte status code.
    if (l == 1) {
        self.writeRaw(CLOSE_PROTOCOL_ERROR) catch {};
        return;
    }
    const code = @as(u16, @intCast(data[1])) | (@as(u16, @intCast(data[0])) << 8);
    if (code < 1000 or code == 1004 or code == 1005 or code == 1006 or (code > 1013 and code < 3000)) {
        self.writeRaw(CLOSE_PROTOCOL_ERROR) catch {};
        return;
    }
    if (l == 2) {
        self.writeRaw(CLOSE_NORMAL) catch {};
        return;
    }
    if (!std.unicode.utf8ValidateSlice(data[2..])) {
        self.writeRaw(CLOSE_PROTOCOL_ERROR) catch {};
        return;
    }
    self.writeClose() catch {};
}

fn writeBin(self: *WebConnection, data: []const u8) !void {
    return self.writeFrame(.binary, data);
}

fn writeText(self: *WebConnection, data: []const u8) !void {
    return self.writeFrame(.text, data);
}

fn writeClose(self: *WebConnection) !void {
    return self.writeRaw(CLOSE_NORMAL);
}

/// Write one pre-built frame.
fn writeRaw(self: *WebConnection, frame: []const u8) !void {
    self.write_mutex.lock();
    defer self.write_mutex.unlock();
    try self.writeAllBuf(frame);
}

fn writeCloseWithCode(self: *WebConnection, code: u16) !void {
    var buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &buf, code, .big);
    return self.writeFrame(.close, &buf);
}

/// Frames up to this size go out in a single write.
const coalesce_limit: usize = 16 * 1024;

fn writeFrame(self: *WebConnection, op_code: WebConnection.OpCode, data: []const u8) !void {
    return self.writeFrameParts(op_code, data, "");
}

/// One frame whose payload is `first` followed by `second`.
fn writeFrameParts(self: *WebConnection, op_code: WebConnection.OpCode, first: []const u8, second: []const u8) !void {
    const l = first.len + second.len;

    // maximum possible prefix length. op_code + length_type + 8byte length
    var head: [10]u8 = undefined;
    head[0] = @backingInt(op_code);
    const head_len: usize = if (l <= 125) blk: {
        head[1] = @intCast(l);
        break :blk 2;
    } else if (l < 65536) blk: {
        head[1] = 126;
        std.mem.writeInt(u16, head[2..4], @intCast(l), .big);
        break :blk 4;
    } else blk: {
        head[1] = 127;
        std.mem.writeInt(u64, head[2..10], l, .big);
        break :blk 10;
    };

    self.write_mutex.lock();
    defer self.write_mutex.unlock();
    if (l <= coalesce_limit) {
        var frame: [head.len + coalesce_limit]u8 = undefined;
        @memcpy(frame[0..head_len], head[0..head_len]);
        @memcpy(frame[head_len..][0..first.len], first);
        @memcpy(frame[head_len + first.len ..][0..second.len], second);
        return self.writeAllBuf(frame[0 .. head_len + l]);
    }
    if (first.len <= coalesce_limit) {
        var lead: [head.len + coalesce_limit]u8 = undefined;
        @memcpy(lead[0..head_len], head[0..head_len]);
        @memcpy(lead[head_len..][0..first.len], first);
        try self.writeAllBuf(lead[0 .. head_len + first.len]);
    } else {
        try self.writeAllBuf(head[0..head_len]);
        try self.writeAllBuf(first);
    }
    try self.writeAllBuf(second);
}

/// Free the reader, buffer pool and the struct.  Does not touch the socket or
/// TLS session — see destroy().
pub fn deinit(self: *WebConnection) void {
    self.reader.deinit();
    self.allocator.destroy(self);
}

/// Interrupt the connection (see ClientConnection.close): shut the socket down
/// so blocked readers/writers return, but free nothing.  Idempotent.
pub fn close(ctx: *anyopaque) void {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    self.interrupted.store(true, .release);
    self.stream.shutdown();
}

/// Release the TLS session, the socket descriptor and all memory.  Called once,
/// when the last reference to the connection is dropped.
pub fn destroy(ctx: *anyopaque) void {
    const self: *WebConnection = @ptrCast(@alignCast(ctx));
    if (self.ssl) |ssl| {
        tls_impl.sslClose(ssl, !self.interrupted.load(.acquire));
        self.ssl = null;
    }
    self.stream.close();
    self.deinit();
}

pub const SynParser = struct {
    allocator: Allocator,
    /// Monotonic ms by which the probe (and an HTTP upgrade) must be done.
    deadline: i64,
    /// Only browsers need it, so it is created on the first "GET".
    handshake_pool: ?*HandshakePool = null,
    /// Newline-separated origins a browser upgrade may come from; empty
    /// allows any.  Not owned.
    websocket_allowed_origins: []const u8,

    pub fn init(allocator: Allocator, deadline: i64, websocket_allowed_origins: []const u8) SynParser {
        return .{ .allocator = allocator, .deadline = deadline, .websocket_allowed_origins = websocket_allowed_origins };
    }

    pub fn deinit(self: *SynParser) void {
        if (self.handshake_pool) |pool| pool.deinit();
    }

    fn checkDeadline(self: *const SynParser) !void {
        if (misc.monotonicMs() > self.deadline) return error.Timeout;
    }

    /// Read the full HTTP upgrade request from `stream`, starting at
    /// `initial_pos` in `buf`.  Each read is bounded by the socket timeout
    /// (plain) or the session deadline (TLS); the whole request by
    /// `self.deadline`.
    fn readHandshakeRequest(self: *SynParser, stream: anytype, buf: []u8, initial_pos: usize) ![]u8 {
        var total: usize = initial_pos;
        while (true) {
            if (total == buf.len) return error.TooLarge;
            const n = try stream.read(buf[total..]);
            if (n == 0) return error.Invalid;
            total += n;
            const request = buf[0..total];
            if (std.mem.endsWith(u8, request, "\r\n\r\n")) return request;
            try self.checkDeadline();
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

        // A single read() may return fewer than HEADER_SIZE bytes; the rest of
        // `buf` would then be uninitialised stack memory and the "GET"/SYN
        // decision would be made on garbage.  Insist on the full probe, and
        // treat an early close as a failed connection attempt.
        var got: usize = 0;
        while (got < buf.len) {
            const n = try stream.read(buf[got..]);
            if (n == 0) return error.EOF;
            got += n;
            if (got < buf.len) try self.checkDeadline();
        }
        if (ascii.startsWithIgnoreCase(&buf, "get")) {
            // 8 KiB is enough for any real browser upgrade request.
            // Chrome sends Sec-Fetch-* headers that push the total well past 512 B.
            const pool = self.handshake_pool orelse blk: {
                const created = try HandshakePool.init(self.allocator, 1, 8192, 32);
                self.handshake_pool = created;
                break :blk created;
            };
            var handshake_state = try pool.acquire();
            defer pool.release(handshake_state);

            var handshake_buffer = handshake_state.buffer;
            @memcpy(handshake_buffer[0..buf.len], &buf);
            const request = self.readHandshakeRequest(stream, handshake_buffer, serde.HEADER_SIZE) catch |err| {
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
            if (!h.originAllowed(self.websocket_allowed_origins)) {
                try WebConnection.Handshake.refuseOrigin(stream);
                return error.OriginNotAllowed;
            }
            try h.reply(stream);
            return true;
        }
        return false;
    }
};
