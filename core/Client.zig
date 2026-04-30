const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const os = std.os;
const posix = std.posix;
const network = @import("network.zig");
const handlers = @import("handlers.zig");
const serde = @import("serde.zig");
const store = @import("store.zig");

const assert = std.debug.assert;
const MessageFlag = serde.MessageFlag;
const Message = serde.Message;
const Handshake = serde.Handshake;
const MessagePool = serde.MessagePool;
const MessageDecoder = serde.MessageDecoder;
const ClientConnection = network.Connection(.ClientConnectionType);
const ClientHandler = handlers.ClientHandler;
const MessageHandler = handlers.MessageHandler;
const ClientMessageStore = store.ClientMessageStore;
const PLACEHOLDER = serde.PLACEHOLDER;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const misc = @import("misc.zig");
const log = std.log.scoped(.client);
const is_wasm = misc.is_wasm;

const Client = @This();


fn setSignalHandler() !void {
    const internal_handler = struct {
        fn internal_handler(_: posix.SIG) callconv(.c) void {
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
    /// Set to true (with release ordering) by the dispatcher thread after it
    /// has freed connection/msgpool resources.  Python reads this (acquire) to
    /// detect a dead connection before calling stopClient(), which frees the
    /// ClientEntry itself.
    disconnected: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    /// Allocator used to create this entry; stored so stopClient can free it.
    alloc: Allocator,

    pub fn get(conn_num: usize) !*ClientEntry {
        if (conn_num == 0) return error.ClientNotInitialized;
        const entry: *ClientEntry = @ptrFromInt(conn_num);
        if (entry.disconnected.load(.acquire)) return error.ClientNotInitialized;
        if (entry.connection.suspended) return error.ConnectionLost;
        return entry;
    }

    pub fn generateUUID(self: *ClientEntry) u16 {
        const ov = @addWithOverflow(self.uuid, 1);
        if (ov[1] != 0) self.uuid = 1 // skip 0
        else self.uuid = ov[0];
        return self.uuid;
    }

    /// Close the connection and free all associated resources.
    ///
    /// For native targets this is a two-phase shutdown that eliminates the race
    /// between the Zig dispatcher thread freeing shared resources and Python
    /// worker threads that are still inside sendMessageClientEntry / msgpool:
    ///
    ///   Phase 1 — signal & wait
    ///     If the dispatcher is still running (disconnected == false), close the
    ///     connection socket so the dispatcher's receiveMessage returns with EOF.
    ///     Then spin until the dispatcher has set disconnected = true.  At that
    ///     point the dispatcher has exited its receive loop and will never touch
    ///     connection or msgpool again.
    ///
    ///   Phase 2 — free resources
    ///     destroy() is always called by Python *after* stop_for_connection()
    ///     has joined all task-dispatcher worker threads.  So by the time we
    ///     arrive here, no Python thread is executing inside sendMessageClientEntry
    ///     either.  It is therefore safe to free connection and msgpool.
    ///
    ///   Why not free in the dispatcher's defer?
    ///     When the router crashes the disconnect watcher wakes first (from
    ///     triggerDisconnect), schedules client.stop() which joins the 100 Python
    ///     worker threads, and then calls stopClient/destroy().  If the dispatcher
    ///     freed msgpool in its defer immediately after triggerDisconnect(), those
    ///     100 workers could still be in the middle of msgpool.sendMessage → SIGABRT
    ///     (from the Zig assert in destroyChannelLocked) or SIGSEGV.
    ///
    /// For WASM: no dispatcher thread exists, so resources are freed directly.
    pub fn destroy(self: *ClientEntry) void {
        if (is_wasm) {
            self.connection.destroy();
            self.msgpool.deinit();
            self.client_handler.deinit();
            self.alloc.destroy(self);
            return;
        }
        // Phase 1 — wait for the dispatcher thread to exit its receive loop.
        if (!self.disconnected.load(.acquire)) {
            log.debug("[{s}] destroy phase-1: closing connection, waiting for dispatcher", .{self.client_handler.app_name});
            self.connection.close();
            var spins: usize = 0;
            while (!self.disconnected.load(.acquire)) {
                const ts = std.c.timespec{ .sec = 0, .nsec = 1_000_000 };
                _ = std.c.nanosleep(&ts, null);
                spins += 1;
                if (spins % 500 == 0)
                    log.warn("[{s}] destroy phase-1: still waiting for dispatcher after ~{d}ms", .{ self.client_handler.app_name, spins });
            }
            log.debug("[{s}] destroy phase-1: dispatcher exited after ~{d}ms", .{ self.client_handler.app_name, spins });
        } else {
            log.debug("[{s}] destroy phase-1: dispatcher already exited (disconnected=true)", .{self.client_handler.app_name});
        }
        // Phase 2 — safe to free: dispatcher is done, Python workers are joined.
        log.debug("[{s}] destroy phase-2: freeing connection + msgpool", .{self.client_handler.app_name});
        self.connection.destroy();
        self.msgpool.deinit();
        self.client_handler.deinit();
        self.alloc.destroy(self);
    }

    fn messageDispatcherClientEntry(self: *ClientEntry) !void {
        // Only set the flag — connection and msgpool are freed by destroy()
        // after Python has joined all worker threads (see destroy() doc above).
        log.debug("[{s}] dispatcher started", .{self.client_handler.app_name});
        defer {
            log.debug("[{s}] dispatcher exiting — setting disconnected=true", .{self.client_handler.app_name});
            self.disconnected.store(true, .release);
        }
        var msg_handler = self.client_handler.handler();
        while (true) {
            const message = self.msgpool.receiveMessage(self.connection) catch |err| {
                if (!self.connection.suspended) {
                    log.warn("[{s}] connection lost: {}", .{ self.client_handler.app_name, err });
                } else {
                    log.debug("[{s}] connection closed intentionally", .{self.client_handler.app_name});
                }
                try msg_handler.handleErr(self.connection, err);
                break;
            };
            // `consumed` is set to true by the handler when it transfers ownership
            // of the message to a store/queue.  After handle() returns we must NOT
            // read any field of `message` when consumed==true — Python may have
            // already popped and freed the message (use-after-free).
            var consumed = false;
            try msg_handler.handle(self.connection, message, &consumed);
            if (!consumed) message.deinit();
            msg_handler.triggerWakeup();
        }
        // Notify Python that this connection is dead so AutoReconnect can
        // react immediately without polling.  Must happen before the defer
        // frees resources so wakeup/disconnect fds are still valid.
        log.debug("[{s}] triggering disconnect fd", .{self.client_handler.app_name});
        self.client_handler.tasks_queue.triggerDisconnect();
        try msg_handler.handleDisconnect(self.connection);
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
            log.debug("[{s}] sendMessage REQUEST func={s} uuid={d} receiver={s}", .{ self.client_handler.app_name, func_name, actual_uuid, actual_receiver });
            try self.msgpool.sendMessage(self.connection, data, actual_uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, actual_receiver, func_name);
            return .{ .receiver = actual_receiver, .uuid = actual_uuid, .timestamp = misc.timestamp() };
        } else {
            std.debug.assert(uuid != 0);
            log.debug("[{s}] sendMessage RESPONSE func={s} uuid={d} receiver={s}", .{ self.client_handler.app_name, func_name, uuid, receiver });
            try self.msgpool.sendMessage(self.connection, data, uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, receiver, func_name);
            return .{ .receiver = receiver, .uuid = uuid, .timestamp = misc.timestamp() };
        }
    }

    pub fn createHandshakeClientEntry(self: *ClientEntry, allocator: Allocator, methods: []const u8) !MessageAndDataIndentifier {
        try self.client_handler.setClientMethods(methods);
        var handshake = try Handshake.create(allocator, &[_]Handshake.MemberData{.{ .name = self.client_handler.app_name, .methods = methods }}, "client");
        const data = try handshake.toJson(allocator);
        const uuid = self.generateUUID();
        const msg = try self.msgpool.createMessage(allocator, data, uuid, .HANDSHAKE, .JSON, false, true, self.client_handler.app_name, PLACEHOLDER, PLACEHOLDER);
        const ts = if (is_wasm) 0 else misc.timestamp();
        return .{ .message = .{ .receiver = PLACEHOLDER, .uuid = uuid, .timestamp = ts }, .data = msg };
    }

    pub fn sendHandshakeClientEntry(self: *ClientEntry, methods: []const u8) !MessageIdentifier {
        var arena = ArenaAllocator.init(std.heap.c_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        try self.client_handler.setClientMethods(methods);
        var handshake = try Handshake.create(allocator, &[_]Handshake.MemberData{.{ .name = self.client_handler.app_name, .methods = methods }}, "client");
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

    pub fn setRequestFdClientEntry(self: *ClientEntry, fd: i32) void {
        log.debug("[{s}] setRequestFd fd={d}", .{ self.client_handler.app_name, fd });
        self.client_handler.tasks_queue.request_fd = fd;
    }

    pub fn setResponseFdClientEntry(self: *ClientEntry, fd: i32) void {
        log.debug("[{s}] setResponseFd fd={d}", .{ self.client_handler.app_name, fd });
        self.client_handler.msg_store.response_fd = fd;
    }

    pub fn setLifecycleFdClientEntry(self: *ClientEntry, fd: i32) void {
        log.debug("[{s}] setLifecycleFd fd={d}", .{ self.client_handler.app_name, fd });
        self.client_handler.tasks_queue.lifecycle_fd = fd;
    }

    pub fn getAvailableMembersClientEntry(self: *ClientEntry, allocator: Allocator) ![]const u8 {
        self.client_handler.mutex.lock();
        defer self.client_handler.mutex.unlock();
        const all_chans = self.client_handler.chan_mapper.allChannels();
        // Always return allocator-owned memory so the CFFI caller can safely
        // call allocator.free() on the result.  The arena used for building the
        // JSON is local to this function and is freed before we return, so we
        // must copy the final JSON string into the caller's allocator first.
        if (all_chans.len == 0) return allocator.dupe(u8, PLACEHOLDER);
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();
        var memberdata = try arena.allocator().alloc(Handshake.MemberData, all_chans.len);
        for (all_chans, 0..) |*c, idx| {
            memberdata[idx] = .{ .name = c.connection_name, .methods = try c.joinedMethods(arena.allocator(), serde.UNIT_SEPARATOR) };
        }
        var handshake = try Handshake.create(arena.allocator(), memberdata, null);
        // Copy into the caller's allocator BEFORE defer arena.deinit() fires.
        return try allocator.dupe(u8, try handshake.toJson(arena.allocator()));
    }
};

fn messageDispatcher(conn_num: usize) !void {
    var entry = try ClientEntry.get(conn_num);
    try entry.messageDispatcherClientEntry();
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
    cl_entry.* = ClientEntry{ .connection = conn, .msgpool = msgpool, .client_handler = client_handler, .alloc = allocator };
    // The heap address of the ClientEntry is the connection number: unbounded,
    // unique, and O(1) to resolve — just @ptrFromInt(conn_num).
    const conn_num: usize = @intFromPtr(cl_entry);
    log.debug("[{s}] client init  conn_num=0x{x}", .{ app_name, conn_num });
    if (!is_wasm) _ = try std.Thread.spawn(.{}, messageDispatcher, .{conn_num});
    return conn_num;
}

pub fn desctroyClient(conn_num: usize) !void {
    if (conn_num == 0) return error.ClientNotInitialized;
    const entry: *ClientEntry = @ptrFromInt(conn_num);
    log.debug("[{s}] stopClient called  conn_num=0x{x}", .{ entry.client_handler.app_name, conn_num });
    entry.destroy();
    log.debug("stopClient complete  conn_num=0x{x}", .{conn_num});
}

pub fn createMessage(allocator: Allocator, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8, conn_num: usize) !MessageAndDataIndentifier {
    var entry = try ClientEntry.get(conn_num);
    return try entry.createMessageClientEntry(allocator, data, uuid, flag, decoder, is_bytes, return_result, receiver, func_name);
}

pub fn sendMessage(data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8, conn_num: usize) !MessageIdentifier {
    var entry = try ClientEntry.get(conn_num);
    return entry.sendMessageClientEntry(data, uuid, flag, decoder, is_bytes, return_result, receiver, func_name);
}

pub fn createHandshake(allocator: Allocator, methods: []const u8, conn_num: usize) !MessageAndDataIndentifier {
    var entry = try ClientEntry.get(conn_num);
    return try entry.createHandshakeClientEntry(allocator, methods);
}

pub fn sendHandshake(conn_num: usize, methods: []const u8) !MessageIdentifier {
    var entry = try ClientEntry.get(conn_num);
    return try entry.sendHandshakeClientEntry(methods);
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
pub fn setRequestFd(conn_num: usize, fd: i32) !void {
    var entry = try ClientEntry.get(conn_num);
    entry.setRequestFdClientEntry(fd);
}

/// Register the eventfd (or pipe write-end) that the native layer signals
/// whenever a new response is inserted into the client message store.
/// Used by every Client connection so blocking RPC waiters
/// (``RpcResult.result``) don't have to poll the store.
pub fn setResponseFd(conn_num: usize, fd: i32) !void {
    var entry = try ClientEntry.get(conn_num);
    entry.setResponseFdClientEntry(fd);
}

/// Register the pipe write-end that the native layer writes to once when the
/// connection is lost (EOF / error).  Python's task dispatcher selects on the
/// read end so AutoReconnect can react without a polling thread.
pub fn setLifecycleFd(conn_num: usize, fd: i32) !void {
    var entry = try ClientEntry.get(conn_num);
    entry.setLifecycleFdClientEntry(fd);
}

pub fn getClientEntry(conn_num: usize) !*ClientEntry {
    // Handle message outside of client connection loop (for wasm)
    return try ClientEntry.get(conn_num);
}
