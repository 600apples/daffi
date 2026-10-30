const std = @import("std");
const builtin = @import("builtin");
const network = @import("network.zig");
const handlers = @import("handlers.zig");
const serde = @import("serde.zig");
const store = @import("store.zig");
const runtime = @import("runtime.zig");
const EventLoop = runtime.EventLoop;

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

pub const MessageIdentifier = struct {
    uuid: u16,
    timestamp: i64,
    receiver: []const u8,
};

pub const MessageAndDataIndentifier = struct {
    message: MessageIdentifier,
    data: []const u8,
};

/// Live handles.  A handle is a counter value, never reused, so a stale one
/// cannot reach a newer client that happens to sit at the same address.
const registry_alloc = if (is_wasm) std.heap.wasm_allocator else std.heap.c_allocator;
var registry_lock: misc.RwLock = .{};
var registry: std.AutoHashMapUnmanaged(usize, *ClientEntry) = .empty;
var next_handle: usize = 1;

pub fn resetRegistryAfterFork() void {
    // Child must not run parent dtors (those threads do not exist). Drop
    // the map; parent allocations are leaked in the child.
    registry = .empty;
    next_handle = 1;
    registry_lock = .{};
}

/// Stack for the receiver thread.  It decodes into a 16 KiB buffer and runs
/// no Python code.

pub const Access = enum {
    /// The connection must still be up (sending).
    live,
    /// Also after the connection ended (draining responses and queued
    /// tasks, withdrawing descriptors).
    any,
};

const ClientEntry = struct {
    connection: *ClientConnection,
    msgpool: *MessagePool,
    client_handler: *ClientHandler,
    /// Last issued request uuid.  Atomic: many Python threads send concurrently.
    uuid: std.atomic.Value(u16) = std.atomic.Value(u16).init(0),
    /// Set once the receiver has stopped for good.
    disconnected: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    /// Callers between `acquire` and `release`.  `destroy` frees nothing
    /// until it drops to zero.
    users: std.atomic.Value(u32) = .init(0),
    users_mutex: misc.Mutex = .{},
    users_cond: misc.Condition = .{},
    /// What reads incoming messages (native targets): a dispatcher thread
    /// (threads model) or an event-loop source (evented model).
    receiver: union(enum) {
        none,
        thread: std.Thread,
        source: *ClientSource,
    } = .none,
    alloc: Allocator,

    /// Resolve a handle received from Python and hold the entry until
    /// `release`.  Stale or bogus handles are rejected, never dereferenced.
    pub fn acquire(conn_num: usize, access: Access) !*ClientEntry {
        const entry = blk: {
            registry_lock.lockShared();
            defer registry_lock.unlockShared();
            const entry = registry.get(conn_num) orelse return error.ClientNotInitialized;
            // Counted under the lock: `destroyClient` removes the handle
            // under the exclusive lock first, then waits for the count.
            _ = entry.users.fetchAdd(1, .acquire);
            break :blk entry;
        };
        if (access == .live) {
            errdefer entry.release();
            if (entry.client_handler.evicted.load(.acquire)) return error.Evicted;
            if (entry.disconnected.load(.acquire)) return error.ClientNotInitialized;
            if (entry.connection.isSuspended()) return error.ConnectionLost;
        }
        return entry;
    }

    pub fn release(self: *ClientEntry) void {
        const n = self.users.fetchSub(1, .release);
        if (n == 1) {
            self.users_mutex.lock();
            self.users_cond.signal();
            self.users_mutex.unlock();
        }
    }

    /// Next request uuid (never 0, wraps at 65535).  With `reply` the uuid is
    /// one no other request still waits on, and it stays taken until its
    /// response is fetched or expired; whatever an earlier owner left behind
    /// is cleared.  uuids whose caller gave up are only reused once no other
    /// one is free.
    pub fn generateUUID(self: *ClientEntry, reply: bool) !u16 {
        if (!reply) {
            while (true) {
                const next = self.uuid.fetchAdd(1, .monotonic) +% 1;
                if (next != 0) return next;
            }
        }
        const msg_store = &self.client_handler.msg_store;
        for ([_]bool{ false, true }) |reuse_expired| {
            if (try msg_store.claimNext(&self.uuid, reuse_expired)) |id| return id;
        }
        return error.TooManyPendingRequests;
    }

    /// Close the connection and free everything.  The handle is already out
    /// of the registry, so no new caller can arrive.
    ///
    /// 1. Wake blocked waiters and interrupt blocked writers.
    /// 2. Wait for the receiver to finish (join the thread, or wait for the
    ///    event source to be removed).
    /// 3. Wait for in-flight callers to release the entry.
    /// 4. Free.
    pub fn destroy(self: *ClientEntry) void {
        if (is_wasm) {
            self.connection.destroy();
            self.msgpool.deinit();
            self.client_handler.deinit();
            self.alloc.destroy(self);
            return;
        }
        self.client_handler.msg_store.close();
        self.connection.close();
        switch (self.receiver) {
            .none => {},
            .thread => |t| t.join(),
            .source => |src| {
                src.done.wait();
                self.alloc.destroy(src);
            },
        }
        self.users_mutex.lock();
        while (self.users.load(.acquire) != 0) self.users_cond.wait(&self.users_mutex);
        self.users_mutex.unlock();
        log.debug("[{s}] destroy: freeing connection", .{self.client_handler.app_name});
        self.connection.destroy();
        self.msgpool.deinit();
        self.client_handler.deinit();
        self.alloc.destroy(self);
    }

    /// Threads model: receive until the connection ends.
    fn messageDispatcherClientEntry(self: *ClientEntry) void {
        log.debug("[{s}] dispatcher started", .{self.client_handler.app_name});
        const msg_handler = self.client_handler.handler();
        const Ctx = struct {
            entry: *ClientEntry,
            handler: @TypeOf(msg_handler),
            fn dispatch(ctx: *const @This(), message: *Message) bool {
                return ctx.entry.dispatch(ctx.handler, message);
            }
        };
        const ctx = Ctx{ .entry = self, .handler = msg_handler };
        const err = serde.receiveLoop(self.alloc, self.connection, &ctx, Ctx.dispatch);
        err catch |e| if (e != error.Stopped) self.connectionEnded(msg_handler, e);
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
            if (!consumed) message.deinit();
            log.warn("[{s}] message handler failed: {}", .{ self.client_handler.app_name, err });
            msg_handler.triggerWakeup();
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

    /// Last step of the receiver: no response can arrive any more.
    fn finishReceiving(self: *ClientEntry, msg_handler: anytype) void {
        log.debug("[{s}] receiver exiting", .{self.client_handler.app_name});
        self.disconnected.store(true, .release);
        self.client_handler.msg_store.close();
        self.client_handler.tasks_queue.triggerDisconnect();
        msg_handler.handleDisconnect(self.connection) catch |err|
            log.warn("[{s}] disconnect handler failed: {}", .{ self.client_handler.app_name, err });
    }

    pub fn createMessageClientEntry(self: *ClientEntry, allocator: Allocator, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8) !MessageAndDataIndentifier {
        const ts = if (is_wasm) 0 else misc.timestamp();
        if (flag == .REQUEST) {
            const actual_receiver = try self.client_handler.findReceiverForMethod(func_name, if (!std.mem.eql(u8, receiver, "")) receiver else null);
            errdefer self.client_handler.allocator.free(actual_receiver);
            const actual_uuid = try self.generateUUID(return_result);
            errdefer if (return_result) self.client_handler.msg_store.unclaim(actual_uuid);
            const msg = try self.msgpool.createMessage(allocator, data, actual_uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, actual_receiver, func_name);
            return .{ .message = .{ .receiver = actual_receiver, .uuid = actual_uuid, .timestamp = ts }, .data = msg };
        } else {
            if (uuid == 0) return error.InvalidUuid;
            const msg = try self.msgpool.createMessage(allocator, data, uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, receiver, func_name);
            return .{ .message = .{ .receiver = receiver, .uuid = uuid, .timestamp = ts }, .data = msg };
        }
    }

    /// For REQUEST the returned receiver is a copy the caller frees with
    /// the handler's allocator.
    pub fn sendMessageClientEntry(self: *ClientEntry, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8) !MessageIdentifier {
        if (flag == .REQUEST) {
            const actual_receiver = try self.client_handler.findReceiverForMethod(func_name, if (!std.mem.eql(u8, receiver, "")) receiver else null);
            errdefer self.client_handler.allocator.free(actual_receiver);
            const actual_uuid = try self.generateUUID(return_result);
            errdefer if (return_result) self.client_handler.msg_store.unclaim(actual_uuid);
            log.debug("[{s}] sendMessage REQUEST func={s} uuid={d} receiver={s}", .{ self.client_handler.app_name, func_name, actual_uuid, actual_receiver });
            try self.msgpool.sendMessage(self.connection, data, actual_uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, actual_receiver, func_name);
            return .{ .receiver = actual_receiver, .uuid = actual_uuid, .timestamp = misc.timestamp() };
        } else {
            if (uuid == 0) return error.InvalidUuid;
            log.debug("[{s}] sendMessage RESPONSE func={s} uuid={d} receiver={s}", .{ self.client_handler.app_name, func_name, uuid, receiver });
            try self.msgpool.sendMessage(self.connection, data, uuid, flag, decoder, is_bytes, return_result, self.client_handler.app_name, receiver, func_name);
            return .{ .receiver = receiver, .uuid = uuid, .timestamp = misc.timestamp() };
        }
    }

    pub fn createHandshakeClientEntry(self: *ClientEntry, allocator: Allocator, methods: []const u8) !MessageAndDataIndentifier {
        try self.client_handler.setClientMethods(methods);
        var handshake = try Handshake.create(allocator, &[_]Handshake.MemberData{.{ .name = self.client_handler.app_name, .methods = methods }}, "client");
        handshake.meta.token = self.client_handler.auth_token;
        const data = try handshake.toJson(allocator);
        const uuid = try self.generateUUID(true);
        errdefer self.client_handler.msg_store.unclaim(uuid);
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
        handshake.meta.token = self.client_handler.auth_token;
        const data = try handshake.toJson(allocator);
        const uuid = try self.generateUUID(true);
        errdefer self.client_handler.msg_store.unclaim(uuid);
        try self.msgpool.sendMessage(self.connection, data, uuid, .HANDSHAKE, .JSON, false, true, self.client_handler.app_name, PLACEHOLDER, PLACEHOLDER);
        return .{
            .receiver = PLACEHOLDER,
            .uuid = uuid,
            .timestamp = misc.timestamp(),
        };
    }

    pub fn getAvailableMembersClientEntry(self: *ClientEntry, allocator: Allocator) ![]const u8 {
        self.client_handler.mutex.lock();
        defer self.client_handler.mutex.unlock();
        const all_chans = self.client_handler.chan_mapper.allChannels();
        // Always return allocator-owned memory so the CFFI caller can safely
        // call allocator.free() on the result.
        if (all_chans.len == 0) return allocator.dupe(u8, PLACEHOLDER);
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();
        var memberdata = try arena.allocator().alloc(Handshake.MemberData, all_chans.len);
        for (all_chans, 0..) |*c, idx| {
            memberdata[idx] = .{ .name = c.connection_name, .methods = try c.joinedMethods(arena.allocator(), serde.UNIT_SEPARATOR) };
        }
        var handshake = try Handshake.create(arena.allocator(), memberdata, null);
        return try allocator.dupe(u8, try handshake.toJson(arena.allocator()));
    }
};

fn sleepMs(ms: u32) void {
    const ts = std.c.timespec{ .sec = @intCast(ms / 1000), .nsec = @intCast((ms % 1000) * std.time.ns_per_ms) };
    _ = std.c.nanosleep(&ts, null);
}

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

    fn onReadable(source: *EventLoop.Source, scratch: []u8) EventLoop.Action {
        const self: *ClientSource = @alignCast(@fieldParentPtr("source", source));
        const entry = self.entry;
        const msg_handler = entry.client_handler.handler();
        const Ctx = struct {
            entry: *ClientEntry,
            handler: @TypeOf(msg_handler),
            fn dispatch(ctx: *const @This(), message: *Message) bool {
                return ctx.entry.dispatch(ctx.handler, message);
            }
        };
        const ctx = Ctx{ .entry = entry, .handler = msg_handler };
        switch (serde.drainReadable(&self.decoder, entry.connection, scratch, &ctx, Ctx.dispatch)) {
            .keep => return .keep,
            .stopped => return .remove,
            .failed => |err| {
                entry.connectionEnded(msg_handler, err);
                return .remove;
            },
        }
    }

    fn onRemoved(source: *EventLoop.Source) void {
        const self: *ClientSource = @alignCast(@fieldParentPtr("source", source));
        self.entry.finishReceiving(self.entry.client_handler.handler());
        self.decoder.deinit();
        self.done.set();
    }
};

pub fn init(allocator: std.mem.Allocator, app_name: []const u8, config: ClientConnection.Config, auth_token: ?[]const u8) !usize {
    const conn = try ClientConnection.init(allocator, config);
    errdefer conn.destroy();
    const msgpool = try MessagePool.init(allocator);
    errdefer msgpool.deinit();
    const client_handler = try ClientHandler.init(allocator, app_name, auth_token);
    errdefer client_handler.deinit();
    if (!is_wasm) {
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
    if (!is_wasm) {
        cl_entry.receiver = switch (runtime.model()) {
            .threads => .{ .thread = try std.Thread.spawn(.{ .stack_size = misc.thread_stack_size }, ClientEntry.messageDispatcherClientEntry, .{cl_entry}) },
            .evented => .{ .source = try ClientSource.start(cl_entry) },
        };
    }
    errdefer if (!is_wasm) {
        conn.close();
        switch (cl_entry.receiver) {
            .none => {},
            .thread => |t| t.join(),
            .source => |src| {
                src.done.wait();
                allocator.destroy(src);
            },
        }
    };
    registry_lock.lock();
    defer registry_lock.unlock();
    const conn_num = next_handle;
    try registry.put(registry_alloc, conn_num, cl_entry);
    next_handle += 1;
    log.debug("[{s}] client init  conn_num={d}", .{ app_name, conn_num });
    return conn_num;
}

pub fn destroyClient(conn_num: usize) !void {
    // Withdraw the handle before anything is freed; a second destroy of the
    // same handle is then a harmless error instead of a double free.
    const entry = blk: {
        registry_lock.lock();
        defer registry_lock.unlock();
        const kv = registry.fetchRemove(conn_num) orelse return error.ClientNotInitialized;
        break :blk kv.value;
    };
    log.debug("[{s}] stopClient called  conn_num={d}", .{ entry.client_handler.app_name, conn_num });
    entry.destroy();
}

pub fn createMessage(allocator: Allocator, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8, conn_num: usize) !MessageAndDataIndentifier {
    const entry = try ClientEntry.acquire(conn_num, .live);
    defer entry.release();
    return try entry.createMessageClientEntry(allocator, data, uuid, flag, decoder, is_bytes, return_result, receiver, func_name);
}

pub fn sendMessage(data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8, conn_num: usize) !MessageIdentifier {
    const entry = try ClientEntry.acquire(conn_num, .live);
    defer entry.release();
    return entry.sendMessageClientEntry(data, uuid, flag, decoder, is_bytes, return_result, receiver, func_name);
}

pub fn createHandshake(allocator: Allocator, methods: []const u8, conn_num: usize) !MessageAndDataIndentifier {
    const entry = try ClientEntry.acquire(conn_num, .live);
    defer entry.release();
    return try entry.createHandshakeClientEntry(allocator, methods);
}

pub fn sendHandshake(conn_num: usize, methods: []const u8) !MessageIdentifier {
    const entry = try ClientEntry.acquire(conn_num, .live);
    defer entry.release();
    return try entry.sendHandshakeClientEntry(methods);
}

/// Take the response for `uuid` if it already arrived.
pub fn getMessageByUuid(uuid: u16, conn_num: usize) !?*Message {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    return entry.client_handler.msg_store.fetch(uuid);
}

/// uuids of responses parked since the last drain.  The messages stay in
/// the store until `getMessageByUuid`.
pub fn drainParked(conn_num: usize, out: *std.ArrayList(u16), out_alloc: std.mem.Allocator) !void {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    try entry.client_handler.msg_store.drainParked(out, out_alloc);
}

pub const WaitOutcome = union(enum) {
    message: *Message,
    timeout,
    disconnected,
    evicted,
};

/// Block until the response for `uuid` arrives, `timeout_ms` passes, or the
/// connection ends.
pub fn waitMessage(uuid: u16, timeout_ms: u32, conn_num: usize) WaitOutcome {
    const entry = ClientEntry.acquire(conn_num, .any) catch return .disconnected;
    defer entry.release();
    const result = entry.client_handler.msg_store.wait(uuid, timeout_ms) catch return .timeout;
    return switch (result) {
        .message => |m| .{ .message = m },
        .timeout => .timeout,
        .closed => if (entry.client_handler.evicted.load(.acquire)) .evicted else .disconnected,
    };
}

/// The caller stopped waiting for `uuid`: a response that arrives later is
/// dropped.
pub fn expireMessage(uuid: u16, conn_num: usize) !void {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    try entry.client_handler.msg_store.expire(uuid);
}

pub fn getMessageForClientWorker(conn_num: usize) !?*Message {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    return entry.client_handler.tasks_queue.getMessageFromQueue();
}

pub fn getAvailableMembers(allocator: Allocator, conn_num: usize) ![]const u8 {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    return entry.getAvailableMembersClientEntry(allocator);
}

/// Whether a peer named `name` is connected.
pub fn hasMember(conn_num: usize, name: []const u8) !bool {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    return entry.client_handler.chan_mapper.hasChannel(name);
}

/// Install (or with -1, withdraw) the descriptor signalled when the task
/// queue gets work.
pub fn setRequestFd(conn_num: usize, fd: i32) !void {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    entry.client_handler.tasks_queue.setRequestFd(fd);
}

/// Install (or with -1, withdraw) the descriptor signalled when a response
/// is parked for an asyncio waiter.
pub fn setResponseFd(conn_num: usize, fd: i32) !void {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    entry.client_handler.msg_store.setResponseFd(fd);
}

/// Install (or with -1, withdraw) the pipe that gets one byte per
/// lifecycle change (disconnect, eviction).
pub fn setLifecycleFd(conn_num: usize, fd: i32) !void {
    const entry = try ClientEntry.acquire(conn_num, .any);
    defer entry.release();
    entry.client_handler.tasks_queue.setLifecycleFd(fd);
}

/// Hold the entry for a message handled outside the receive loop (wasm).
/// The caller must `release` it.
pub fn acquireClientEntry(conn_num: usize) !*ClientEntry {
    return try ClientEntry.acquire(conn_num, .any);
}
