const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const os = std.os;
const posix = std.posix;
const network = @import("network.zig");
const handlers = @import("handlers.zig");
const serde = @import("serde.zig");
const repository = @import("repository.zig");

const assert = std.debug.assert;
const MessageFlag = serde.MessageFlag;
const Message = serde.Message;
const Handshake = serde.Handshake;
const MessagePool = serde.MessagePool;
const MessageDecoder = serde.MessageDecoder;
const ClientConnection = network.Connection(.ClientConnectionType);
const ClientHandler = handlers.ClientHandler;
const MessageHandler = handlers.MessageHandler;
const ClientMessageStore = repository.ClientMessageStore;
const PLACEHOLDER = serde.PLACEHOLDER;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const misc = @import("misc.zig");
const print = misc.print;
const is_wasm = misc.is_wasm;

const Client = @This();

/// Replacement for std.BoundedArray (removed in 0.16) — fixed 256-slot array.
const ClientEntryArray = struct {
    buffer: [256]?*ClientEntry = [_]?*ClientEntry{null} ** 256,
    len: usize = 256,

    pub fn init() @This() {
        return .{};
    }

    pub fn get(self: *const @This(), idx: usize) ?*ClientEntry {
        return self.buffer[idx];
    }

    pub fn set(self: *@This(), idx: usize, val: ?*ClientEntry) void {
        self.buffer[idx] = val;
    }
};

var clientEntries: ?ClientEntryArray = null;

fn setSignalHandler() !void {
    const internal_handler = struct {
        fn internal_handler(_: posix.SIG) callconv(.c) void {
            std.debug.print("Exiting...\n", .{});
            std.process.exit(0);
        }
    }.internal_handler;
    const act = posix.Sigaction{
        .handler = .{ .handler = internal_handler },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    posix.sigaction(posix.SIG.INT, &act, null);
    posix.sigaction(posix.SIG.TERM, &act, null);
}

pub const MessageIdentifier = struct {
    uuid: u16,
    timestamp: i64,
    receiver: []const u8,
};

pub const MessageAndDataIndentifier = struct {
    message: MessageIdentifier,
    data: []const u8,
};

const ClientEntry = struct {
    connection: *ClientConnection,
    msgpool: *MessagePool,
    client_handler: *ClientHandler,
    uuid: u16 = 0,

    pub fn get(conn_num: usize) !*ClientEntry {
        if (clientEntries) |entries| {
            if (entries.get(conn_num)) |client_entry| {
                if (!client_entry.connection.suspended) return client_entry;
                return error.ConnectionLost;
            }
        }
        return error.ClientNotInitialized;
    }

    pub fn generateUUID(self: *ClientEntry) u16 {
        const ov = @addWithOverflow(self.uuid, 1);
        if (ov[1] != 0) self.uuid = 1 // skip 0
        else self.uuid = ov[0];
        return self.uuid;
    }

    pub fn desctroyClientEntry(self: *const ClientEntry) void {
        // Only close the socket so the dispatcher thread can detect disconnect and exit.
        // The Connection struct and msgpool are freed by messageDispatcherClientEntry
        // after the thread finishes, avoiding use-after-free races.
        self.connection.close();
    }

    fn messageDispatcherClientEntry(self: *ClientEntry, conn_num: usize) !void {
        var msg_handler = self.client_handler.handler();
        while (self.msgpool.receiveMessage(self.connection)) |message| {
            try msg_handler.handle(self.connection, message);
            // Notify the Python task dispatcher that a new task-queue message
            // may be waiting.  This eliminates the 1 ms fallback poll delay for
            // Client connections used as workers in a router topology.
            // ClientHandler always marks inbound messages as durable (they go
            // into msg_store or tasks_queue), so there is no double-free risk
            // — unlike serverLoop, this loop has no defer message.deinit().
            msg_handler.triggerWakeup();
        } else |err| {
            print("exit client connection with error: {}\n", .{err});
            try msg_handler.handleErr(self.connection, err);
        }
        try msg_handler.handleDisconnect(self.connection);
        { const ts = std.c.timespec{ .sec = 0, .nsec = 5000 }; _ = std.c.nanosleep(&ts, null); }
        if (clientEntries) |*entries| entries.set(conn_num, null);
        // Now safe to free: no Python thread or Zig code references this connection.
        self.connection.destroy();
        self.msgpool.deinit();
    }

    pub fn createMessageClientEntry(self: *ClientEntry, allocator: Allocator, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8) !MessageAndDataIndentifier {
        const ts = if (is_wasm) 0 else misc.timestamp();
        if (flag == .REQUEST) {
            // Find intersection between provided receiver and available receivers
            const actual_receiver = try self.client_handler.findReceiverForMethod(func_name, if (!std.mem.eql(u8, receiver, "")) receiver else null);
            const actual_uuid = self.generateUUID();
            const msg = try self.msgpool.createMessage(allocator, data, actual_uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, actual_receiver, func_name);
            return .{ .message = .{ .receiver = actual_receiver, .uuid = actual_uuid, .timestamp = ts }, .data = msg };
        } else {
            std.debug.assert(uuid != 0);
            const msg = try self.msgpool.createMessage(allocator, data, uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, receiver, func_name);
            return .{ .message = .{ .receiver = receiver, .uuid = uuid, .timestamp = ts }, .data = msg };
        }
    }

    pub fn sendMessageClientEntry(self: *ClientEntry, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8) !MessageIdentifier {
        if (flag == .REQUEST) {
            // Find intersection between provided receiver and available receivers
            const actual_receiver = try self.client_handler.findReceiverForMethod(func_name, if (!std.mem.eql(u8, receiver, "")) receiver else null);
            const actual_uuid = self.generateUUID();
            try self.msgpool.sendMessage(self.connection, data, actual_uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, actual_receiver, func_name);
            return .{ .receiver = actual_receiver, .uuid = actual_uuid, .timestamp = misc.timestamp() };
        } else {
            std.debug.assert(uuid != 0);
            try self.msgpool.sendMessage(self.connection, data, uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, receiver, func_name);
            return .{ .receiver = receiver, .uuid = uuid, .timestamp = misc.timestamp() };
        }
    }

    pub fn createHandshakeClientEntry(self: *ClientEntry, allocator: Allocator, password: []const u8, methods: []const u8) !MessageAndDataIndentifier {
        try self.client_handler.setClientMethods(methods);
        var handshake = try Handshake.create(allocator, &[_]Handshake.MemberData{.{ .name = self.client_handler.app_name, .methods = methods }}, password, "client");
        const data = try handshake.toJson(allocator);
        const uuid = self.generateUUID();
        const msg = try self.msgpool.createMessage(allocator, data, uuid, .HANDSHAKE, .JSON, false, true, self.client_handler.app_name, PLACEHOLDER, PLACEHOLDER);
        const ts = if (is_wasm) 0 else misc.timestamp();
        return .{ .message = .{ .receiver = PLACEHOLDER, .uuid = uuid, .timestamp = ts }, .data = msg };
    }

    pub fn sendHandshakeClientEntry(self: *ClientEntry, password: []const u8, methods: []const u8) !MessageIdentifier {
        var arena = ArenaAllocator.init(std.heap.c_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        try self.client_handler.setClientMethods(methods);
        var handshake = try Handshake.create(allocator, &[_]Handshake.MemberData{.{ .name = self.client_handler.app_name, .methods = methods }}, password, "client");
        const data = try handshake.toJson(allocator);
        const uuid = self.generateUUID();
        try self.msgpool.sendMessage(self.connection, data, uuid, .HANDSHAKE, .JSON, false, true, self.client_handler.app_name, PLACEHOLDER, PLACEHOLDER);
        return .{
            .receiver = PLACEHOLDER,
            .uuid = uuid,
            .timestamp = misc.timestamp(),
        };
    }

    pub fn getMessageByUuidClientEntry(self: *ClientEntry, uuid: u16) ?*Message {
        return self.client_handler.msg_store.fetch(uuid);
    }

    pub fn setTimeoutErrorClientEntry(self: *ClientEntry, uuid: u16) !void {
        try self.client_handler.msg_store.setTimeoutError(uuid);
    }

    pub fn getMessageForClientWorkerClientEntry(self: *ClientEntry) ?*Message {
        return self.client_handler.tasks_queue.getMessageFromQueue();
    }

    pub fn setWakeupFdClientEntry(self: *ClientEntry, fd: i32) void {
        self.client_handler.tasks_queue.wakeup_fd = fd;
    }

    pub fn getAvailableMembersClientEntry(self: *ClientEntry, allocator: Allocator) ![]const u8 {
        const chan_count = self.client_handler.chan_mapper.ChannelsCount();
        // Always return allocator-owned memory so the CFFI caller can safely
        // call allocator.free() on the result.  The arena used for building the
        // JSON is local to this function and is freed before we return, so we
        // must copy the final JSON string into the caller's allocator first.
        if (chan_count == 0) return allocator.dupe(u8, PLACEHOLDER);
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();
        const this_name = try std.fmt.allocPrint(arena.allocator(), "{s} (this app)", .{self.client_handler.app_name});
        var memberdata = try arena.allocator().alloc(Handshake.MemberData, chan_count);
        for (self.client_handler.chan_mapper.allChannels(), 0..) |*c, idx| {
            const name = if (std.mem.eql(u8, c.connection_name, self.client_handler.app_name)) this_name else c.connection_name;
            memberdata[idx] = .{ .name = name, .methods = try c.joinedMethods(arena.allocator(), serde.UNIT_SEPARATOR) };
        }
        var handshake = try Handshake.create(arena.allocator(), memberdata, null, null);
        // Copy into the caller's allocator BEFORE defer arena.deinit() fires.
        return try allocator.dupe(u8, try handshake.toJson(arena.allocator()));
    }
};

fn messageDispatcher(conn_num: usize) !void {
    var entry = try ClientEntry.get(conn_num);
    try entry.messageDispatcherClientEntry(conn_num);
}

pub fn init(allocator: std.mem.Allocator, app_name: []const u8, config: ClientConnection.Config) !usize {
    const conn = try ClientConnection.init(allocator, config);
    var msgpool = try MessagePool.init(allocator);
    const client_handler = try ClientHandler.init(allocator, app_name);
    if (!is_wasm) {
        try setSignalHandler();
        // The SYN probe is sent by every daffi TCP client (plain and TLS alike).
        // On the server side tryWebSocket() reads these bytes to distinguish a
        // native daffi connection (SYN = 0x1F × HEADER_SIZE) from a browser
        // WebSocket upgrade (starts with "GET").  Without SYN a TLS-TCP client
        // would have its first real HANDSHAKE bytes consumed by tryWebSocket and
        // the message framing would be corrupted.
        try msgpool.sendSynMessage(conn);
    }
    const cl_entry = try allocator.create(ClientEntry);
    cl_entry.* = ClientEntry{ .connection = conn, .msgpool = msgpool, .client_handler = client_handler };
    if (clientEntries == null) {
        clientEntries = ClientEntryArray.init();
    }
    const conn_num: usize = @rem(clientEntries.?.len, 256);
    clientEntries.?.set(conn_num, cl_entry);
    if (!is_wasm) _ = try std.Thread.spawn(.{}, messageDispatcher, .{conn_num});
    return conn_num;
}

pub fn desctroyClient(conn_num: usize) !void {
    var entry = try ClientEntry.get(conn_num);
    entry.desctroyClientEntry();
}

pub fn createMessage(allocator: Allocator, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8, conn_num: usize) !MessageAndDataIndentifier {
    var entry = try ClientEntry.get(conn_num);
    return try entry.createMessageClientEntry(allocator, data, uuid, flag, decoder, is_bytes, return_result, receiver, func_name);
}

pub fn sendMessage(data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8, conn_num: usize) !MessageIdentifier {
    var entry = try ClientEntry.get(conn_num);
    return entry.sendMessageClientEntry(data, uuid, flag, decoder, is_bytes, return_result, receiver, func_name);
}

pub fn createHandshake(allocator: Allocator, password: []const u8, methods: []const u8, conn_num: usize) !MessageAndDataIndentifier {
    var entry = try ClientEntry.get(conn_num);
    return try entry.createHandshakeClientEntry(allocator, password, methods);
}

pub fn sendHandshake(conn_num: usize, password: []const u8, methods: []const u8) !MessageIdentifier {
    var entry = try ClientEntry.get(conn_num);
    return try entry.sendHandshakeClientEntry(password, methods);
}

pub fn getMessageByUuid(uuid: u16, conn_num: usize) !?*Message {
    var entry = try ClientEntry.get(conn_num);
    return entry.getMessageByUuidClientEntry(uuid);
}

pub fn setTimeoutError(uuid: u16, conn_num: usize) !void {
    var entry = try ClientEntry.get(conn_num);
    try entry.setTimeoutErrorClientEntry(uuid);
}

pub fn getMessageForClientWorker(conn_num: usize) !?*Message {
    var entry = ClientEntry.get(conn_num) catch return null;
    return entry.getMessageForClientWorkerClientEntry();
}

pub fn getAvailableMembers(allocator: Allocator, conn_num: usize) ![]const u8 {
    var entry = try ClientEntry.get(conn_num);
    return entry.getAvailableMembersClientEntry(allocator);
}

/// Register the eventfd (or pipe write-end) that the native layer signals
/// whenever a new task-queue message is available for conn_num.
/// Used by client connections acting as workers in a router topology.
pub fn setWakeupFd(conn_num: usize, fd: i32) !void {
    var entry = try ClientEntry.get(conn_num);
    entry.setWakeupFdClientEntry(fd);
}

pub fn getClientEntry(conn_num: usize) !*ClientEntry {
    // Handle message outside of client connection loop (for wasm)
    return try ClientEntry.get(conn_num);
}
