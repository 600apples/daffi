const std = @import("std");
const misc = @import("misc.zig");
const serde = @import("serde.zig");
const network = @import("network.zig");
const handlers = @import("handlers.zig");
const store = @import("store.zig");
const posix = std.posix;

const Allocator = std.mem.Allocator;
const ServerConnection = network.Connection(.ServerConnectionType);
const ServerHandler = handlers.ServerHandler(.ClientConnectionType);
const MessageHandler = handlers.MessageHandler;
const Message = serde.Message;
const MessageFlag = serde.MessageFlag;
const MessagePool = serde.MessagePool;
const MessageDecoder = serde.MessageDecoder;

/// Replacement for std.BoundedArray (removed in Zig 0.16).
const ServerEntryArray = struct {
    buffer: [256]?ServerEntry = [_]?ServerEntry{null} ** 256,
    len: usize = 0,

    pub fn get(self: *const @This(), idx: usize) ServerEntry {
        return self.buffer[idx].?;
    }

    pub fn set(self: *@This(), idx: usize, val: ServerEntry) void {
        self.buffer[idx] = val;
        if (idx >= self.len) self.len = idx + 1;
    }

    pub fn popOrNull(self: *@This()) ?ServerEntry {
        if (self.len == 0) return null;
        self.len -= 1;
        const entry = self.buffer[self.len];
        self.buffer[self.len] = null;
        return entry;
    }
};

var serverEntries: ?ServerEntryArray = null;
/// Per-slot ready flag.  Set to true (with release ordering) by the dispatcher
/// thread after it has written the ServerEntry into serverEntries.  Polled
/// (with acquire ordering) by startServer() so it can return only after the
/// slot is safe for Python to use.
var serverReady: [256]std.atomic.Value(bool) = blk: {
    var arr: [256]std.atomic.Value(bool) = undefined;
    for (&arr) |*v| v.* = std.atomic.Value(bool).init(false);
    break :blk arr;
};

fn setSignalHandler() !void {
    const internal_handler = struct {
        fn internal_handler(_: posix.SIG) callconv(.c) void {
            if (serverEntries) |*entries| {
                while (entries.popOrNull()) |entry| {
                    entry.connection.close();
                }
            }
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

const ServerEntry = struct {
    connection: *ServerConnection,
    msgpool: *MessagePool,
    server_handler: *ServerHandler,

    pub fn sendMessageServerEntry(self: ServerEntry, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8) !MessageIdentifier {
        // TODO: send messages to WebMessagePool
        switch (self.server_handler.*) {
            .Service => |*s| {
                std.debug.assert(uuid != 0);
                const chan = try s.chan_mapper.getChannel(receiver);
                try self.msgpool.sendMessage(chan.conn, data, uuid, flag, decoder, is_bytes, return_result, s.app_name, receiver, func_name);
                return .{ .receiver = receiver, .uuid = uuid, .timestamp = misc.timestamp() };
            },
            .Router => return error.MessagesNotSupported,
        }
    }

    pub fn getMessageForServerWorkerServerEntry(self: ServerEntry) !?*Message {
        switch (self.server_handler.*) {
            .Service => |*s| return s.tasks_queue.getMessageFromQueue(),
            .Router => return error.QueueNotSupported,
        }
    }

    pub fn setServiceMethodsServerEntry(self: ServerEntry, methods: []const u8) !void {
        try switch (self.server_handler.*) {
            .Service => |*s| s.setServiceMethods(methods),
            .Router => error.MethodsNotSupported,
        };
    }
};

/// Returns true once the dispatcher thread for conn_num has finished
/// initialising and written its ServerEntry.  Used by startServer() to
/// avoid returning to Python before the entry is safe to call.
pub fn isReady(conn_num: usize) bool {
    return serverReady[conn_num].load(.acquire);
}

/// Register the eventfd (or pipe write-end) that the native layer should
/// signal whenever a message is pushed onto the Service task queue for
/// conn_num.  Must be called after startServer() returns and before any
/// client can send messages (i.e. before the handshake advertises methods).
pub fn setWakeupFd(conn_num: usize, fd: i32) void {
    if (serverEntries) |*entries| {
        if (entries.buffer[conn_num]) |*entry| {
            switch (entry.server_handler.*) {
                .Service => |*s| s.tasks_queue.wakeup_fd = fd,
                .Router => {}, // routers have no task queue
            }
        }
    }
}

pub fn messageDispatcher(allocator: Allocator, app_name: []const u8, config: ServerConnection.Config, conn_num: usize) !void {
    // Entry point for server. It creates connection and message pool and starts server loop.
    try setSignalHandler();
    var msgpool: *MessagePool = try MessagePool.init(allocator);
    const conn: *ServerConnection = try ServerConnection.init(allocator, config);
    var server_handler = try ServerHandler.init(config.mode, allocator, app_name);
    defer server_handler.deinit();
    if (serverEntries == null) {
        serverEntries = ServerEntryArray{};
    }
    const server_entry = ServerEntry{ .connection = conn, .msgpool = msgpool, .server_handler = server_handler };
    serverEntries.?.set(conn_num, server_entry);
    serverReady[conn_num].store(true, .release);
    // Conection normally should be closed by destroyConnection method.
    // msgpool.deinit should happen after connection is closed.
    defer msgpool.deinit();
    while (!conn.suspended) {
        if (conn.accept()) |client_conn| {
            // Pass handler BY VALUE so std.Thread.spawn copies it into the thread's
            // own argument storage.  Taking &server_handler.X.handler() would capture
            // the address of a temporary that is destroyed before the new thread runs.
            var th = if (client_conn.is_websocket)
                switch (config.mode) {
                    .Service => try std.Thread.spawn(.{}, serverWsLoop, .{ client_conn, msgpool, server_handler.Service.handler() }),
                    .Router => try std.Thread.spawn(.{}, serverWsLoop, .{ client_conn, msgpool, server_handler.Router.handler() }),
                }
            else switch (config.mode) {
                .Service => try std.Thread.spawn(.{}, serverLoop, .{ client_conn, msgpool, server_handler.Service.handler() }),
                .Router => try std.Thread.spawn(.{}, serverLoop, .{ client_conn, msgpool, server_handler.Router.handler() }),
            };
            th.detach();
        } else |err| {
            std.debug.print("failed to accept connection {}\n", .{err});
        }
    }
}

fn serverLoop(conn: *ServerHandler.ConnectionT, msgpool: *MessagePool, msg_handler: anytype) !void {
    defer {
        if (comptime @import("builtin").mode == .Debug)
            if (conn.peer_addr) |addr|
                std.debug.print("connection closed from {f}\n", .{@import("network/connection.zig").fmtNetAddr(addr)});
        conn.destroy();
    }
    while (msgpool.receiveMessage(conn)) |message| {
        // OWNERSHIP PROTOCOL
        // ------------------
        // handle() may call onRequest() which:
        //   1. Sets message.metadata.durable = true
        //   2. Pushes the message into the TasksQueue
        //
        // Previously, TasksQueue.pushMessageToQueue() immediately wrote to the
        // eventfd, which could wake the Python poller *before* this thread
        // reached the old `defer message.deinit()`.  The poller would then call
        // undurableAndDeinit() — setting durable=false and freeing the message —
        // while this thread still had a live pointer to it, causing a use-after-
        // free when the defer later read `metadata.durable` from freed memory.
        //
        // Fix: pushMessageToQueue() no longer signals the wakeup.  We check
        // `metadata.durable` here (safe: no Python thread is awake yet), free
        // the message if this thread still owns it, and THEN call triggerWakeup()
        // so the Python poller can safely take ownership of queued messages.
        msg_handler.handle(conn, message) catch |err| {
            // handle() failed before (or during) ownership transfer.  The
            // message was never successfully pushed, so we own it and must free.
            // Force-clear durable in case setDurable() was called before the
            // failing pushMessageToQueue().
            message.metadata.durable = false;
            message.deinit();
            // Still flush any wakeup that a prior successful push may have
            // set before the error occurred.
            msg_handler.triggerWakeup();
            try msg_handler.handleErr(conn, err);
            return;
        };
        // handle() succeeded.  No Python thread has been notified yet.
        // Safe to inspect (and possibly act on) message.metadata.durable.
        if (!message.metadata.durable) message.deinit();
        // NOW wake the Python poller.  From this point the Python side may
        // dequeue and free any durable messages.
        msg_handler.triggerWakeup();
    } else |err| try msg_handler.handleErr(conn, err);
    try msg_handler.handleDisconnect(conn);
    // Wake the Python poller so it can pick up the "disconnected" event message
    // that handleDisconnect() pushed onto the task queue.
    msg_handler.triggerWakeup();
}

fn serverWsLoop(conn: *ServerHandler.ConnectionT, msgpool: *MessagePool, msg_handler: anytype) !void {
    defer {
        if (comptime @import("builtin").mode == .Debug)
            if (conn.peer_addr) |addr|
                std.debug.print("connection closed from {f}\n", .{@import("network/connection.zig").fmtNetAddr(addr)});
        conn.destroy();
    }
    while (msgpool.receiveWsMessage(conn)) |maybe_message| {
        var message = maybe_message orelse break;
        // Apply the same ownership protocol as serverLoop (see detailed comment
        // there).  WebSocket messages follow identical lifetime rules.
        msg_handler.handle(conn, message) catch |err| {
            message.metadata.durable = false;
            message.deinit();
            msg_handler.triggerWakeup();
            try msg_handler.handleErr(conn, err);
            return;
        };
        if (!message.metadata.durable) message.deinit();
        msg_handler.triggerWakeup();
    } else |err| try msg_handler.handleErr(conn, err);
    try msg_handler.handleDisconnect(conn);
    // Same as above: wake the Python poller after pushing the disconnect event.
    msg_handler.triggerWakeup();
}

pub fn sendMessage(data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8, conn_num: usize) !MessageIdentifier {
    if (serverEntries) |entries| return try entries.get(conn_num).sendMessageServerEntry(data, uuid, flag, decoder, is_bytes, return_result, receiver, func_name);
    return error.ServerNotInitialized;
}

pub fn destroyHandler(conn_num: usize) void {
    if (serverEntries) |entries| entries.get(conn_num).connection.destroy();
}

pub fn getMessageForServerWorker(conn_num: usize) !?*Message {
    if (serverEntries) |entries| return try entries.get(conn_num).getMessageForServerWorkerServerEntry();
    return error.ServerNotInitialized;
}

pub fn setServiceMethods(methods: []const u8, conn_num: usize) !void {
    if (serverEntries) |entries| return try entries.get(conn_num).setServiceMethodsServerEntry(methods);
    return error.ServerNotInitialized;
}
