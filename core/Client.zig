const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const network = @import("network.zig");
const handlers = @import("handlers.zig");
const serde = @import("serde.zig");
const store = @import("store.zig");
const runtime = @import("runtime.zig");
const EventLoop = runtime.EventLoop;

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
            // Async-signal-safe termination only; exit() would run atexit
            // handlers from inside a signal context.
            std.c._exit(0);
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

/// Live ClientEntry handles (see ClientEntry.get).
const registry_alloc = if (is_wasm) std.heap.wasm_allocator else std.heap.c_allocator;
var registry_mutex: misc.Mutex = .{};
var registry: std.AutoHashMapUnmanaged(usize, void) = .empty;

const ClientEntry = struct {
    connection: *ClientConnection,
    msgpool: *MessagePool,
    client_handler: *ClientHandler,
    /// Last issued request uuid.  Atomic: many Python threads send concurrently.
    uuid: std.atomic.Value(u16) = std.atomic.Value(u16).init(0),
    /// Set to true (with release ordering) once the receiver has stopped for
    /// good.  Python reads this (acquire) to detect a dead connection before
    /// calling stopClient(), which frees the ClientEntry itself.
    disconnected: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    /// What reads incoming messages (native targets): a dispatcher thread
    /// (threads model) or an event-loop source (evented model).
    receiver: union(enum) {
        none,
        thread: std.Thread,
        source: *ClientSource,
    } = .none,
    /// Allocator used to create this entry; stored so stopClient can free it.
    alloc: Allocator,

    /// Resolve a handle received from Python.  Only handles that were issued by
    /// `init` and not yet destroyed are accepted; the previous version
    /// dereferenced whatever integer it was given, so a stale or bogus handle
    /// was a use-after-free (or a wild read).
    pub fn get(conn_num: usize) !*ClientEntry {
        if (conn_num == 0) return error.ClientNotInitialized;
        registry_mutex.lock();
        const known = registry.contains(conn_num);
        registry_mutex.unlock();
        if (!known) return error.ClientNotInitialized;
        const entry: *ClientEntry = @ptrFromInt(conn_num);
        if (entry.disconnected.load(.acquire)) return error.ClientNotInitialized;
        if (entry.connection.isSuspended()) return error.ConnectionLost;
        return entry;
    }

    /// Next request uuid (never 0, wraps at 65535).  A uuid that was timed out
    /// earlier is "un-expired" so its new owner's response is not discarded.
    pub fn generateUUID(self: *ClientEntry) u16 {
        while (true) {
            const next = self.uuid.fetchAdd(1, .monotonic) +% 1;
            if (next == 0) continue; // 0 is reserved
            self.client_handler.msg_store.clearExpired(next);
            return next;
        }
    }

    /// Close the connection and free all associated resources.
    ///
    /// For native targets this is a two-phase shutdown that eliminates the race
    /// between the Zig dispatcher thread freeing shared resources and Python
    /// worker threads that are still inside sendMessageClientEntry / msgpool:
    ///
    ///   Phase 1 — signal & wait
    ///     If the receiver is still running (disconnected == false), close the
    ///     connection socket so it sees EOF, then wait until it has finished
    ///     (join the dispatcher thread, or wait for the event source to be
    ///     removed).  From then on it never touches connection or msgpool again.
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
        if (self.receiver != .none) {
            if (!self.disconnected.load(.acquire)) {
                log.debug("[{s}] destroy phase-1: closing connection, waiting for receiver", .{self.client_handler.app_name});
                self.connection.close();
            } else {
                log.debug("[{s}] destroy phase-1: receiver already exited (disconnected=true)", .{self.client_handler.app_name});
            }
            switch (self.receiver) {
                .none => unreachable,
                .thread => |t| t.join(),
                .source => |src| {
                    src.done.wait();
                    self.alloc.destroy(src);
                },
            }
            log.debug("[{s}] destroy phase-1: receiver finished", .{self.client_handler.app_name});
        }
        // Phase 2 — safe to free: dispatcher is done, Python workers are joined.
        log.debug("[{s}] destroy phase-2: freeing connection + msgpool", .{self.client_handler.app_name});
        self.connection.destroy();
        self.msgpool.deinit();
        self.client_handler.deinit();
        self.alloc.destroy(self);
    }

    /// Threads model: receive until the connection ends.
    fn messageDispatcherClientEntry(self: *ClientEntry) void {
        log.debug("[{s}] dispatcher started", .{self.client_handler.app_name});
        const msg_handler = self.client_handler.handler();
        while (true) {
            const message = self.msgpool.receiveMessage(self.connection) catch |err| {
                self.connectionEnded(msg_handler, err);
                break;
            };
            if (!self.dispatch(msg_handler, message)) break;
        }
        self.finishReceiving(msg_handler);
    }

    /// Run the handler for one received message.  Returns false when the
    /// connection should be dropped.
    fn dispatch(self: *ClientEntry, msg_handler: anytype, message: *Message) bool {
        // `consumed` is set to true by the handler when it transfers ownership
        // of the message to a store/queue.  After handle() returns we must NOT
        // read any field of `message` when consumed==true — Python may have
        // already popped and freed the message (use-after-free).
        var consumed = false;
        msg_handler.handle(self.connection, message, &consumed) catch |err| {
            // Don't skip the disconnect notification: Python is waiting for it.
            // Treat a failing handler as a broken stream.
            if (!consumed) message.deinit();
            log.warn("[{s}] message handler failed: {}", .{ self.client_handler.app_name, err });
            msg_handler.handleErr(self.connection, err) catch {};
            return false;
        };
        if (!consumed) message.deinit();
        msg_handler.triggerWakeup();
        return true;
    }

    fn connectionEnded(self: *ClientEntry, msg_handler: anytype, err: anyerror) void {
        if (!self.connection.isSuspended()) {
            log.debug("[{s}] connection lost: {}", .{ self.client_handler.app_name, err });
        } else {
            log.debug("[{s}] connection closed intentionally", .{self.client_handler.app_name});
        }
        msg_handler.handleErr(self.connection, err) catch {};
    }

    /// Last step of the receiver.  Only sets the flag — connection and msgpool
    /// are freed by destroy() after Python has joined all worker threads (see
    /// destroy() doc above).
    fn finishReceiving(self: *ClientEntry, msg_handler: anytype) void {
        // Notify Python that this connection is dead so AutoReconnect can
        // react immediately without polling.
        log.debug("[{s}] receiver exiting — triggering disconnect fd", .{self.client_handler.app_name});
        self.client_handler.tasks_queue.triggerDisconnect();
        msg_handler.handleDisconnect(self.connection) catch |err|
            log.warn("[{s}] disconnect handler failed: {}", .{ self.client_handler.app_name, err });
        self.disconnected.store(true, .release);
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

/// Evented model: the client's connection served by an event loop.
const ClientSource = struct {
    source: EventLoop.Source,
    entry: *ClientEntry,
    decoder: serde.FrameDecoder,
    /// Set once the source is removed and the entry is never touched again.
    done: misc.Event = .{},

    fn start(entry: *ClientEntry) !*ClientSource {
        const loop = try runtime.loop();
        const self = try entry.alloc.create(ClientSource);
        errdefer entry.alloc.destroy(self);
        self.* = .{
            .source = .{ .fd = entry.connection.handle(), .onReadable = onReadable, .onRemoved = onRemoved },
            .entry = entry,
            .decoder = .init(entry.alloc),
        };
        try loop.register(&self.source);
        return self;
    }

    /// Reads until the socket is drained: a TLS session may hold decrypted
    /// bytes that no further socket readiness would report.
    fn onReadable(source: *EventLoop.Source, scratch: []u8) EventLoop.Action {
        const self: *ClientSource = @alignCast(@fieldParentPtr("source", source));
        const entry = self.entry;
        const msg_handler = entry.client_handler.handler();
        while (true) {
            const n = entry.connection.readSome(scratch) catch |err| switch (err) {
                error.WouldBlock => return .keep,
                else => {
                    entry.connectionEnded(msg_handler, err);
                    return .remove;
                },
            };
            if (n == 0) {
                entry.connectionEnded(msg_handler, error.EOF);
                return .remove;
            }
            var input: []const u8 = scratch[0..n];
            while (true) {
                const message = (self.decoder.next(&input) catch |err| {
                    entry.connectionEnded(msg_handler, err);
                    return .remove;
                }) orelse break;
                if (!entry.dispatch(msg_handler, message)) return .remove;
            }
        }
    }

    fn onRemoved(source: *EventLoop.Source) void {
        const self: *ClientSource = @alignCast(@fieldParentPtr("source", source));
        self.entry.finishReceiving(self.entry.client_handler.handler());
        self.decoder.deinit();
        self.done.set();
    }
};

pub fn init(allocator: std.mem.Allocator, app_name: []const u8, config: ClientConnection.Config) !usize {
    const conn = try ClientConnection.init(allocator, config);
    errdefer conn.destroy();
    const msgpool = try MessagePool.init(allocator);
    errdefer msgpool.deinit();
    const client_handler = try ClientHandler.init(allocator, app_name);
    errdefer client_handler.deinit();
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
    errdefer allocator.destroy(cl_entry);
    cl_entry.* = ClientEntry{ .connection = conn, .msgpool = msgpool, .client_handler = client_handler, .alloc = allocator };
    // The heap address of the ClientEntry is the connection number: unbounded
    // and unique.  It is also recorded in `registry` so stale handles can be
    // rejected instead of dereferenced.
    const conn_num: usize = @intFromPtr(cl_entry);
    {
        registry_mutex.lock();
        defer registry_mutex.unlock();
        try registry.put(registry_alloc, conn_num, {});
    }
    errdefer {
        registry_mutex.lock();
        _ = registry.remove(conn_num);
        registry_mutex.unlock();
    }
    log.debug("[{s}] client init  conn_num=0x{x}", .{ app_name, conn_num });
    if (!is_wasm) {
        cl_entry.receiver = switch (runtime.model()) {
            .threads => .{ .thread = try std.Thread.spawn(.{}, ClientEntry.messageDispatcherClientEntry, .{cl_entry}) },
            .evented => .{ .source = try ClientSource.start(cl_entry) },
        };
    }
    return conn_num;
}

pub fn destroyClient(conn_num: usize) !void {
    if (conn_num == 0) return error.ClientNotInitialized;
    // Invalidate the handle before anything is freed; also makes a second
    // destroy of the same handle a harmless error instead of a double free.
    registry_mutex.lock();
    const was_live = registry.remove(conn_num);
    registry_mutex.unlock();
    if (!was_live) return error.ClientNotInitialized;
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
