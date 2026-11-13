const std = @import("std");
const net = @import("posix_net.zig");
const ascii = std.ascii;
const misc = @import("../misc.zig");
const Mutex = misc.Mutex;
const Allocator = std.mem.Allocator;
const serde = @import("../serde.zig");
const tls_impl = @import("tls.zig");
pub const Handshake = @import("../network/web/handshake.zig").Handshake;
const KeyValue = @import("../network/web/handshake.zig").KeyValue;
pub const framing = @import("../network/web/framing.zig");
pub const Fragmented = framing.Fragmented;
const reader_mod = @import("../network/web/reader.zig");
pub const Reader = reader_mod.Reader;
pub const buffer = @import("../network/web/buffer.zig");
pub const MessageType = @import("../network/web/reader.zig").MessageType;
pub const OpCode = framing.OpCode;
const OperationTable = @import("../network.zig").OperationTable;

const WebConnection = @This();

pub const op_table = OperationTable{
    .read = read,
    .readSome = readSome,
    .readNoBuffer = readNoBuffer,
    .write = write,
    .writeParts = writeParts,
    .writeNonBlocking = writeNonBlocking,
    .writeNonBlockingParts = writeNonBlockingParts,
    .writeVec = writeVec,
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

const CLOSE_GOING_AWAY: u16 = 1001;
const CLOSE_PROTOCOL: u16 = 1002;
const CLOSE_INVALID_DATA: u16 = 1007;
const CLOSE_TOO_BIG: u16 = 1009;
const CLOSE_INTERNAL: u16 = 1011;

/// A session that hears nothing for this long is pinged, and closed if it
/// stays silent as long again (browsers answer pings on their own).
pub const IDLE_PING_MS: u32 = 30_000;

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
/// The reader pinged a silent peer and waits for any reply.
ping_sent: bool = false,

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

/// Start serving an upgraded session: reads give up after `IDLE_PING_MS`
/// (see `SessionStream`) and the time a message has been stuck half-read
/// goes to `progress`, so the server can close a stalled session.
pub fn startSession(self: *WebConnection, progress: *std.atomic.Value(i64)) void {
    self.reader.progress = progress;
    if (self.ssl) |ssl| {
        tls_impl.setReadTimeout(ssl, IDLE_PING_MS);
    } else {
        self.stream.setReadTimeout(IDLE_PING_MS);
    }
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

pub fn writeNonBlockingParts(_: *anyopaque, _: []const u8, _: []const u8) !usize {
    return 0;
}

/// Each queued message is its own frame.
pub fn writeVec(_: *anyopaque, _: []const []const u8) !bool {
    return false;
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

/// What the reader reads from: the TLS session or the socket.  A read that
/// times out pings the peer; the next one ends the session.
const SessionStream = struct {
    conn: *WebConnection,

    pub fn read(self: SessionStream, buf: []u8) !usize {
        const conn = self.conn;
        while (true) {
            const result = if (conn.ssl) |ssl| tls_impl.sslRead(ssl, buf) else conn.stream.read(buf);
            const n = result catch |err| {
                if (err != error.Timeout) return err;
                if (conn.ping_sent) return error.IdleTimeout;
                conn.ping_sent = true;
                try conn.writeFrame(.ping, "");
                continue;
            };
            if (n > 0) conn.ping_sent = false;
            return n;
        }
    }
};

/// The close status for a session that fails with `err`, if the peer
/// should get one.
fn closeCodeFor(err: anyerror) ?u16 {
    return switch (err) {
        error.TooLarge => CLOSE_TOO_BIG,
        error.FrameBudgetExceeded => CLOSE_INTERNAL,
        error.IdleTimeout => CLOSE_GOING_AWAY,
        error.UnmaskedFrame,
        error.InvalidMessageType,
        error.ReservedFlags,
        error.LargeControl,
        error.FragmentedControl,
        error.NestedFragment,
        error.UnfragmentedContinuation,
        => CLOSE_PROTOCOL,
        else => null,
    };
}

/// Next text or binary message, or null once the peer closed.  Pings are
/// answered and pongs skipped without ending the session.  The message
/// stays valid until the next call: a fragmented one lives in the
/// reassembly buffer, which is only freed then.
fn readInternal(self: *WebConnection) !?[]const u8 {
    self.reader.handled();
    while (true) {
        const message = self.reader.readMessage(SessionStream{ .conn = self }) catch |err| {
            if (closeCodeFor(err)) |code| self.writeCloseWithCode(code) catch {};
            return null;
        };
        switch (message.type) {
            .binary => return message.data,
            .text => {
                if (!std.unicode.utf8ValidateSlice(message.data)) {
                    self.writeCloseWithCode(CLOSE_INVALID_DATA) catch {};
                    return null;
                }
                return message.data;
            },
            .pong => {},
            .ping => try self.writeFrame(.pong, message.data),
            .close => {
                self.answerClose(message.data);
                return null;
            },
        }
    }
}

/// Status codes a peer may close with (RFC 6455 7.4, IANA registry).
fn validCloseCode(code: u16) bool {
    return switch (code) {
        1000...1003, 1007...1014, 3000...4999 => true,
        else => false,
    };
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
    const code = std.mem.readInt(u16, data[0..2], .big);
    if (!validCloseCode(code)) {
        self.writeRaw(CLOSE_PROTOCOL_ERROR) catch {};
        return;
    }
    if (l == 2) {
        self.writeRaw(CLOSE_NORMAL) catch {};
        return;
    }
    if (!std.unicode.utf8ValidateSlice(data[2..])) {
        self.writeCloseWithCode(CLOSE_INVALID_DATA) catch {};
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

    // One gathered send (plain) or full TLS records: a frame header never
    // goes out on its own.
    const parts = [_][]const u8{ head[0..head_len], first, second };
    self.write_mutex.lock();
    defer self.write_mutex.unlock();
    if (self.ssl) |ssl| return tls_impl.sslWriteParts(ssl, &parts);
    return self.stream.writeAllVec(&parts);
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
    /// Monotonic ms by which the probe (and an HTTP upgrade) must be done.
    deadline: i64,
    /// Newline-separated origins a browser upgrade may come from; empty
    /// allows any.  Not owned.
    websocket_allowed_origins: []const u8,

    pub fn init(deadline: i64, websocket_allowed_origins: []const u8) SynParser {
        return .{ .deadline = deadline, .websocket_allowed_origins = websocket_allowed_origins };
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
            var handshake_buffer: [8192]u8 = undefined;
            var keys: [32][]const u8 = undefined;
            var values: [32][]const u8 = undefined;
            var headers = KeyValue{ .len = 0, .keys = &keys, .values = &values };

            @memcpy(handshake_buffer[0..buf.len], &buf);
            const request = self.readHandshakeRequest(stream, &handshake_buffer, serde.HEADER_SIZE) catch |err| {
                const s: []const u8 = switch (err) {
                    error.Invalid => "HTTP/1.1 400 Invalid\r\nerror: invalid\r\ncontent-length: 0\r\n\r\n",
                    error.TooLarge => "HTTP/1.1 400 Invalid\r\nerror: too large\r\ncontent-length: 0\r\n\r\n",
                    error.Timeout => "HTTP/1.1 400 Invalid\r\nerror: timeout\r\ncontent-length: 0\r\n\r\n",
                    else => "HTTP/1.1 400 Invalid\r\nerror: unknown\r\ncontent-length: 0\r\n\r\n",
                };
                _ = try stream.write(s);
                return error.HandshakeFailed;
            };

            const h = WebConnection.Handshake.parse(request, &headers) catch |err| {
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

/// An upgraded session on one end of a socketpair; the test is the browser.
const TestSession = struct {
    const pc = @import("posix_c");

    web: *WebConnection,
    progress: std.atomic.Value(i64) = .init(0),
    peer: c_int,

    fn open() !*TestSession {
        var fds: [2]c_int = undefined;
        try std.testing.expectEqual(@as(c_int, 0), pc.socketpair(pc.AF_UNIX, pc.SOCK_STREAM, 0, &fds));
        // Stream.close() releases a descriptor this socketpair never counted.
        @import("../nofile.zig").acquire(1);
        const self = try std.testing.allocator.create(TestSession);
        self.* = .{ .web = try init(std.testing.allocator, .{ .handle = fds[0] }, .{}, .{}), .peer = fds[1] };
        self.web.startSession(&self.progress);
        // A broken test fails instead of waiting for the idle ping.
        self.web.stream.setReadTimeout(2000);
        return self;
    }

    fn close(self: *TestSession) void {
        destroy(self.web);
        _ = pc.close(self.peer);
        std.testing.allocator.destroy(self);
    }

    /// Send one masked client frame.
    fn send(self: *TestSession, first_byte: u8, payload: []const u8) !void {
        var frame: std.ArrayList(u8) = .empty;
        defer frame.deinit(std.testing.allocator);
        const a = std.testing.allocator;
        try frame.append(a, first_byte);
        if (payload.len < 126) {
            try frame.append(a, 0x80 | @as(u8, @intCast(payload.len)));
        } else {
            try frame.append(a, 0x80 | 126);
            try frame.appendSlice(a, &std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(payload.len))));
        }
        const mask = [4]u8{ 1, 2, 3, 4 };
        try frame.appendSlice(a, &mask);
        for (payload, 0..) |b, i| try frame.append(a, b ^ mask[i % 4]);
        try self.sendRaw(frame.items);
    }

    fn sendRaw(self: *TestSession, bytes: []const u8) !void {
        try (net.Stream{ .handle = self.peer }).writeAll(bytes);
    }

    /// The next server frame: opcode byte and payload (unmasked, short).
    fn receive(self: *TestSession, payload: []u8) !struct { u8, []u8 } {
        var head: [2]u8 = undefined;
        try self.readExact(&head);
        const len = head[1] & 127;
        try self.readExact(payload[0..len]);
        return .{ head[0], payload[0..len] };
    }

    fn readExact(self: *TestSession, buf: []u8) !void {
        var at: usize = 0;
        while (at < buf.len) {
            const n = pc.read(self.peer, buf[at..].ptr, buf.len - at);
            if (n <= 0) return error.EndOfStream;
            at += @intCast(n);
        }
    }

    /// The session ends (readInternal returns null) with close `code`.
    fn expectClosedWith(self: *TestSession, code: u16) !void {
        try std.testing.expectEqual(@as(?[]const u8, null), try self.web.readInternal());
        var payload: [125]u8 = undefined;
        const op, const data = try self.receive(&payload);
        try std.testing.expectEqual(@backingInt(OpCode.close), op);
        try std.testing.expectEqual(@as(usize, 2), data.len);
        try std.testing.expectEqual(code, std.mem.readInt(u16, data[0..2], .big));
    }
};

test "WebSocket protocol errors close with the RFC 6455 status" {
    const Case = struct { first: u8, payload: []const u8, masked: bool = true, code: u16 };
    const cases = [_]Case{
        .{ .first = 0x82, .payload = "x", .masked = false, .code = CLOSE_PROTOCOL },
        .{ .first = 0x83, .payload = "x", .code = CLOSE_PROTOCOL }, // reserved opcode
        .{ .first = 0xC2, .payload = "x", .code = CLOSE_PROTOCOL }, // RSV1
        .{ .first = 0x80, .payload = "x", .code = CLOSE_PROTOCOL }, // continuation of nothing
        .{ .first = 0x09, .payload = "x", .code = CLOSE_PROTOCOL }, // fragmented ping
        .{ .first = 0x81, .payload = "\xc3\x28", .code = CLOSE_INVALID_DATA },
        .{ .first = 0x88, .payload = &.{ 0x13, 0x88 }, .code = CLOSE_PROTOCOL }, // 5000
        .{ .first = 0x88, .payload = &.{ 0x03, 0xED }, .code = CLOSE_PROTOCOL }, // 1005
        .{ .first = 0x88, .payload = &.{ 0x03, 0xF7 }, .code = CLOSE_PROTOCOL }, // 1015
        .{ .first = 0x88, .payload = &.{ 0x03, 0xE7 }, .code = CLOSE_PROTOCOL }, // 999
        .{ .first = 0x88, .payload = &.{ 0x03, 0xE8, 0xff }, .code = CLOSE_INVALID_DATA },
        .{ .first = 0x88, .payload = &.{ 0x0F, 0xA0 }, .code = 1000 }, // 4000 is fine
    };
    for (cases) |case| {
        const s = try TestSession.open();
        defer s.close();
        if (case.masked) {
            try s.send(case.first, case.payload);
        } else {
            try s.sendRaw(&.{ case.first, @intCast(case.payload.len) });
            try s.sendRaw(case.payload);
        }
        try s.expectClosedWith(case.code);
    }
}

test "a WebSocket message over the size limit closes with 1009" {
    const s = try TestSession.open();
    defer s.close();
    // Declares 2^40 bytes; nothing is allocated for it.
    try s.sendRaw(&.{ 0x82, 0x80 | 127, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 3, 4 });
    try s.expectClosedWith(CLOSE_TOO_BIG);
    try std.testing.expectEqual(@as(usize, 0), reader_mod.partialBytes());
}

test "valid text and binary messages pass" {
    const s = try TestSession.open();
    defer s.close();
    try s.send(0x81, "h\xc3\xa9llo");
    try std.testing.expectEqualSlices(u8, "h\xc3\xa9llo", (try s.web.readInternal()).?);
    try s.send(0x82, "\xff\xfe");
    try std.testing.expectEqualSlices(u8, "\xff\xfe", (try s.web.readInternal()).?);
}

test "a silent WebSocket peer is pinged, then closed with 1001" {
    const s = try TestSession.open();
    defer s.close();
    s.web.stream.setReadTimeout(100);
    try std.testing.expectEqual(@as(?[]const u8, null), try s.web.readInternal());
    var payload: [125]u8 = undefined;
    const ping, _ = try s.receive(&payload);
    try std.testing.expectEqual(@backingInt(OpCode.ping), ping);
    const close_op, const data = try s.receive(&payload);
    try std.testing.expectEqual(@backingInt(OpCode.close), close_op);
    try std.testing.expectEqual(CLOSE_GOING_AWAY, std.mem.readInt(u16, data[0..2], .big));
}

test "an answered ping keeps the WebSocket session open" {
    const s = try TestSession.open();
    defer s.close();
    s.web.stream.setReadTimeout(200);
    const Peer = struct {
        fn run(session: *TestSession) void {
            var payload: [125]u8 = undefined;
            const op, _ = session.receive(&payload) catch return;
            if (op != @backingInt(OpCode.ping)) return;
            session.send(0x8A, "") catch return; // pong
            session.send(0x82, "after") catch return;
        }
    };
    const t = try std.Thread.spawn(.{}, Peer.run, .{s});
    defer t.join();
    try std.testing.expectEqualSlices(u8, "after", (try s.web.readInternal()).?);
}

test "a half-read WebSocket message is reported as in progress" {
    const s = try TestSession.open();
    defer s.close();
    const payload = "0123456789";
    var frame: [2 + 4 + payload.len]u8 = undefined;
    frame[0] = 0x82;
    frame[1] = 0x80 | payload.len;
    @memset(frame[2..6], 0);
    @memcpy(frame[6..], payload);
    try s.sendRaw(frame[0..5]);
    const Peer = struct {
        fn run(session: *TestSession, rest: []const u8, seen: *i64) void {
            const deadline = misc.monotonicMs() + 2000;
            while (session.progress.load(.monotonic) == 0 and misc.monotonicMs() < deadline) std.Thread.yield() catch {};
            seen.* = session.progress.load(.monotonic);
            session.sendRaw(rest) catch {};
        }
    };
    var seen: i64 = 0;
    const t = try std.Thread.spawn(.{}, Peer.run, .{ s, frame[5..], &seen });
    const message = try s.web.readInternal();
    t.join();
    try std.testing.expect(seen != 0);
    try std.testing.expectEqualSlices(u8, payload, message.?);
    try std.testing.expectEqual(@as(i64, 0), s.progress.load(.monotonic));
}

test "WebSocket messages past the process budget are refused" {
    const saved = reader_mod.max_partial_bytes;
    defer reader_mod.max_partial_bytes = saved;
    reader_mod.max_partial_bytes = 8 * 1024;

    const s = try TestSession.open();
    defer s.close();
    const big = try std.testing.allocator.alloc(u8, 10 * 1024);
    defer std.testing.allocator.free(big);
    @memset(big, 'a');
    try s.send(0x82, big);
    try s.expectClosedWith(CLOSE_INTERNAL);
    try std.testing.expectEqual(@as(usize, 0), reader_mod.partialBytes());

    // A fragmented message is held in the budget until it is handled.
    const f = try TestSession.open();
    defer f.close();
    try f.send(0x02, big[0..3000]);
    try f.send(0x80, big[0..100]);
    try std.testing.expectEqual(@as(usize, 3100), (try f.web.readInternal()).?.len);
    try std.testing.expect(reader_mod.partialBytes() > 0);
    f.web.reader.handled();
    try std.testing.expectEqual(@as(usize, 0), reader_mod.partialBytes());
}
