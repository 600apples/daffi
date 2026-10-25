const std = @import("std");
const misc = @import("misc.zig");
const serde = @import("serde.zig");
const network = @import("network.zig");
const handlers = @import("handlers.zig");
const store = @import("store.zig");
const runtime = @import("runtime.zig");
const EventLoop = runtime.EventLoop;
const posix = std.posix;
const Mutex = misc.Mutex;
const AcceptedConnection = @import("network/connection.zig").AcceptedConnection;
const fmtNetAddr = @import("network/connection.zig").fmtNetAddr;

const Allocator = std.mem.Allocator;
const ServerConnection = network.Connection(.ServerConnectionType);
const ServerHandler = handlers.ServerHandler(.ClientConnectionType);
const MessageHandler = handlers.MessageHandler;
const HandlerMode = handlers.HandlerMode;
const Message = serde.Message;
const MessageFlag = serde.MessageFlag;
const MessagePool = serde.MessagePool;
const log = std.log.scoped(.server);
const MessageDecoder = serde.MessageDecoder;

const MAX_SERVERS = 256;

/// How often the threaded accept loop wakes up to check for shutdown.
const ACCEPT_POLL_MS: c_int = 200;

/// How long stop waits for connections to finish before giving up and
/// leaking the server's memory rather than freeing it under them.
const DRAIN_TIMEOUT_MS: i64 = 10_000;

fn HandlerOf(comptime mode: HandlerMode) type {
    const H = @FieldType(ServerHandler, @tagName(mode));
    return @typeInfo(@TypeOf(H.handler)).@"fn".return_type.?;
}

/// Per-server state shared between the accept side and every connection.
const Runtime = struct {
    allocator: Allocator,
    mode: HandlerMode,
    app_name: []const u8,
    connection: *ServerConnection,
    msgpool: *MessagePool,
    server_handler: *ServerHandler,
    /// Accepted connections currently being served.  Used to interrupt them
    /// (by shutting their sockets down) when the server stops.
    live_mutex: Mutex = .{},
    live: std.ArrayList(*ServerHandler.ConnectionT) = .empty,
    /// Accepted connections whose thread or event source may still touch this
    /// struct.  `stop` waits for it to reach zero before freeing anything.
    active_connections: std.atomic.Value(usize) = .init(0),
    /// Threads model: the accept-loop thread.
    accept_thread: ?std.Thread = null,
    /// Evented model: the listening socket registered on `listener_loop`.
    listener_source: EventLoop.Source = undefined,
    listener_loop: ?*EventLoop = null,

    /// Remember `conn` so shutdown can interrupt it.  Fails if the server is
    /// already stopping, in which case the caller must drop the connection.
    fn registerLive(self: *Runtime, conn: *ServerHandler.ConnectionT) !void {
        self.live_mutex.lock();
        defer self.live_mutex.unlock();
        // Checked under the lock: shutdown sets `suspended` first and then walks
        // `live` under this same lock, so a connection either gets registered
        // before the walk (and is closed by it) or is refused here.
        if (self.connection.isSuspended()) return error.ServerStopping;
        try self.live.append(self.allocator, conn);
    }

    fn unregisterLive(self: *Runtime, conn: *ServerHandler.ConnectionT) void {
        self.live_mutex.lock();
        defer self.live_mutex.unlock();
        for (self.live.items, 0..) |c, i| {
            if (c == conn) {
                _ = self.live.swapRemove(i);
                return;
            }
        }
    }

    fn interruptAllLive(self: *Runtime) void {
        self.live_mutex.lock();
        defer self.live_mutex.unlock();
        for (self.live.items) |c| c.close();
    }

    fn handler(self: *Runtime, comptime mode: HandlerMode) HandlerOf(mode) {
        return @field(self.server_handler, @tagName(mode)).handler();
    }

    fn deinit(self: *Runtime) void {
        self.server_handler.deinit();
        self.connection.destroy();
        self.msgpool.deinit();
        self.live.deinit(self.allocator);
        self.allocator.free(self.app_name);
        self.allocator.destroy(self);
    }
};

const ServerEntry = struct {
    connection: *ServerConnection,
    msgpool: *MessagePool,
    server_handler: *ServerHandler,
    runtime: *Runtime,

    pub fn sendMessageServerEntry(self: ServerEntry, data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8) !MessageIdentifier {
        // TODO: send messages to WebMessagePool
        switch (self.server_handler.*) {
            .Service => |*s| {
                std.debug.assert(uuid != 0);
                // Hold a reference for the duration of the write: the channel (and
                // the connection behind it) may be torn down by another thread as
                // soon as the map lock is dropped.
                const peer = try s.chan_mapper.retainConn(receiver);
                defer peer.release();
                try self.msgpool.sendMessage(peer, data, uuid, flag, decoder, is_bytes, return_result, s.app_name, receiver, func_name);
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

/// Slot table.  `start` claims a slot and publishes the server in it; `stop`
/// withdraws the server and frees the slot for reuse.
var slots_mutex: Mutex = .{};
var slot_used: [MAX_SERVERS]bool = @splat(false);
var slot_entries: [MAX_SERVERS]?ServerEntry = @splat(null);

fn acquireSlot() ?usize {
    slots_mutex.lock();
    defer slots_mutex.unlock();
    for (&slot_used, 0..) |*used, i| {
        if (!used.*) {
            used.* = true;
            slot_entries[i] = null;
            return i;
        }
    }
    return null;
}

fn releaseSlot(conn_num: usize) void {
    slots_mutex.lock();
    defer slots_mutex.unlock();
    slot_entries[conn_num] = null;
    slot_used[conn_num] = false;
}

fn getEntry(conn_num: usize) !ServerEntry {
    if (conn_num >= MAX_SERVERS) return error.ServerNotInitialized;
    slots_mutex.lock();
    defer slots_mutex.unlock();
    return slot_entries[conn_num] orelse error.ServerNotInitialized;
}

/// SIGINT/SIGTERM handler.  Only async-signal-safe calls are allowed here: the
/// previous version walked the entry table, closed sockets and called
/// `exit()`, which runs atexit handlers and may take locks the interrupted
/// thread already holds.
fn setSignalHandler() !void {
    const internal_handler = struct {
        fn internal_handler(_: posix.SIG) callconv(.c) void {
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

/// Register the eventfd (or pipe write-end) that the native layer should
/// signal whenever a message is pushed onto the Service task queue for
/// conn_num.  Must be called after start() returns and before any
/// client can send messages (i.e. before the handshake advertises methods).
pub fn setServiceRequestFd(conn_num: usize, fd: i32) void {
    const entry = getEntry(conn_num) catch return;
    switch (entry.server_handler.*) {
        .Service => |*s| s.tasks_queue.request_fd = fd,
        .Router => {}, // routers have no task queue
    }
}

/// Bind, start accepting and return the server's handle (conn_num).  Accepting
/// runs on a dedicated thread or on an event loop depending on the execution
/// model; either way the server is fully usable once this returns.
pub fn start(allocator: Allocator, app_name: []const u8, config: ServerConnection.Config) !usize {
    return startImpl(allocator, app_name, config) catch |err| {
        log.err("{s}[{s}] failed to start: {}", .{ @tagName(config.mode), app_name, err });
        return err;
    };
}

fn startImpl(allocator: Allocator, app_name_arg: []const u8, config: ServerConnection.Config) !usize {
    try setSignalHandler();
    const conn_num = acquireSlot() orelse return error.TooManyServers;
    errdefer releaseSlot(conn_num);

    // The caller's strings (Python str buffers) are only guaranteed to live until
    // start() returns; the handler keeps `app_name` for the server's lifetime.
    const app_name = try allocator.dupe(u8, app_name_arg);
    errdefer allocator.free(app_name);
    const msgpool = try MessagePool.init(allocator);
    errdefer msgpool.deinit();
    const conn = try ServerConnection.init(allocator, config);
    errdefer conn.destroy();
    const server_handler = try ServerHandler.init(config.mode, allocator, app_name);
    errdefer server_handler.deinit();
    const rt = try allocator.create(Runtime);
    errdefer allocator.destroy(rt);
    rt.* = .{
        .allocator = allocator,
        .mode = config.mode,
        .app_name = app_name,
        .connection = conn,
        .msgpool = msgpool,
        .server_handler = server_handler,
    };

    switch (runtime.model()) {
        .threads => rt.accept_thread = try std.Thread.spawn(.{}, acceptLoop, .{rt}),
        .evented => {
            const loop = try runtime.loop();
            rt.listener_source = .{ .fd = conn.handle(), .onReadable = onListenerReadable, .onRemoved = onListenerRemoved };
            try loop.register(&rt.listener_source);
            rt.listener_loop = loop;
        },
    }

    {
        slots_mutex.lock();
        defer slots_mutex.unlock();
        slot_entries[conn_num] = .{ .connection = conn, .msgpool = msgpool, .server_handler = server_handler, .runtime = rt };
    }
    log.debug("{s}[{s}] listening on {s}:{d} conn_num={d} model={s}", .{
        @tagName(config.mode),
        app_name,
        config.host orelse "0.0.0.0",
        config.port,
        conn_num,
        @tagName(runtime.model()),
    });
    return conn_num;
}

/// Stop the server: stop accepting, interrupt every connection, wait until
/// none of them can touch the server any more, then free everything and
/// release the slot.  Blocks until done, so the port can be rebound at once.
pub fn stop(conn_num: usize) void {
    if (conn_num >= MAX_SERVERS) return;
    const rt = blk: {
        slots_mutex.lock();
        defer slots_mutex.unlock();
        const entry = slot_entries[conn_num] orelse return;
        // Withdraw the entry first so no new caller picks the server up.
        slot_entries[conn_num] = null;
        break :blk entry.runtime;
    };
    defer releaseSlot(conn_num);

    rt.connection.close();
    if (rt.accept_thread) |t| t.join();
    if (rt.listener_loop) |loop| loop.detach(&rt.listener_source);
    log.debug("{s}[{s}] stopped accepting conn_num={d}", .{ @tagName(rt.mode), rt.app_name, conn_num });

    rt.interruptAllLive();
    const deadline = misc.milliTimestamp() + DRAIN_TIMEOUT_MS;
    while (rt.active_connections.load(.acquire) != 0) {
        if (misc.milliTimestamp() > deadline) {
            // Freeing now would hand the stragglers dangling pointers.  Leaking a
            // few structs is the lesser evil.
            log.err("{s}[{s}] {d} connection(s) did not finish; leaking server state", .{ @tagName(rt.mode), rt.app_name, rt.active_connections.load(.acquire) });
            return;
        }
        rt.interruptAllLive();
        sleepMs(5);
    }
    rt.deinit();
}

fn sleepMs(ms: u32) void {
    const ts = std.c.timespec{ .sec = @intCast(ms / 1000), .nsec = @intCast((ms % 1000) * std.time.ns_per_ms) };
    _ = std.c.nanosleep(&ts, null);
}

/// Threads model: accept until the server is stopped.
fn acceptLoop(rt: *Runtime) void {
    while (!rt.connection.isSuspended()) {
        const raw = rt.connection.acceptRaw(ACCEPT_POLL_MS) catch |err| {
            switch (err) {
                // Periodic wake-up to re-check the shutdown flag.
                error.Timeout => {},
                else => {
                    log.warn("failed to accept connection: {}", .{err});
                    // Avoid a hot loop if accept keeps failing (e.g. EMFILE).
                    sleepMs(50);
                },
            }
            continue;
        };
        admit(rt, raw);
    }
}

/// Evented model: drain the pending connections of a readable listener.
fn onListenerReadable(source: *EventLoop.Source, _: []u8) EventLoop.Action {
    const rt: *Runtime = @alignCast(@fieldParentPtr("listener_source", source));
    while (true) {
        const raw = rt.connection.acceptRaw(0) catch |err| {
            if (err != error.Timeout) log.warn("failed to accept connection: {}", .{err});
            return .keep;
        };
        admit(rt, raw);
    }
}

/// The listener never removes itself; `stop` detaches it.
fn onListenerRemoved(_: *EventLoop.Source) void {}

/// Hand an accepted descriptor to its own thread (threads model) or to the
/// blocking pool (evented model) for the protocol probe / TLS handshake, so a
/// silent peer cannot stall accepting.
fn admit(rt: *Runtime, raw: AcceptedConnection) void {
    // Counted first so stop never frees `rt` while the connection starts up.
    _ = rt.active_connections.fetchAdd(1, .acq_rel);
    const started = switch (rt.mode) {
        .Service => startConnection(.Service, rt, raw),
        .Router => startConnection(.Router, rt, raw),
    };
    started catch |err| {
        log.warn("failed to start connection: {}", .{err});
        _ = rt.active_connections.fetchSub(1, .acq_rel);
        (@import("network/posix_net.zig").Stream{ .handle = raw.fd }).close();
    };
}

fn startConnection(comptime mode: HandlerMode, rt: *Runtime, raw: AcceptedConnection) !void {
    const main = struct {
        fn main(r: *Runtime, a: AcceptedConnection) void {
            connectionMain(mode, r, a);
        }
    }.main;
    switch (runtime.model()) {
        .threads => (try std.Thread.spawn(.{}, main, .{ rt, raw })).detach(),
        .evented => try runtime.spawnBlocking(main, .{ rt, raw }),
    }
}

/// Finish the accept (TLS + protocol detection), then serve the connection:
/// on this thread in the threads model, and also for WebSocket sessions;
/// otherwise as an event-loop source.
fn connectionMain(comptime mode: HandlerMode, rt: *Runtime, raw: AcceptedConnection) void {
    const client = rt.connection.upgradeAccepted(raw) catch |err| {
        // upgradeAccepted already closed the descriptor.
        log.debug("rejected incoming connection: {}", .{err});
        _ = rt.active_connections.fetchSub(1, .release);
        return;
    };
    rt.registerLive(client) catch {
        client.destroy();
        _ = rt.active_connections.fetchSub(1, .release);
        return;
    };
    if (runtime.model() == .evented and !client.is_websocket) {
        if (ConnectionSource(mode).attach(rt, client)) return else |err|
            log.warn("cannot attach connection to an event loop ({}); serving it on a blocking thread", .{err});
    }

    const handler = rt.handler(mode);
    if (client.is_websocket) {
        serverWsLoop(client, rt.msgpool, handler);
    } else {
        serverLoop(client, rt.msgpool, handler);
    }
    releaseConnection(rt, client);
}

/// Last step for every accepted connection.  Decrementing the counter must be
/// the very last access to `rt`: once it hits zero, stop may free it.
fn releaseConnection(rt: *Runtime, client: *ServerHandler.ConnectionT) void {
    rt.unregisterLive(client);
    // Drops the owner reference.  The socket is closed (and the struct freed)
    // when the last reference goes — channels in the router/service map hold
    // their own until the disconnect handler removes them.
    client.destroy();
    _ = rt.active_connections.fetchSub(1, .release);
}

/// Evented model: a native connection served by an event loop.  Incoming bytes
/// are decoded incrementally and each complete message is dispatched on the
/// loop thread.
fn ConnectionSource(comptime mode: HandlerMode) type {
    return struct {
        source: EventLoop.Source,
        rt: *Runtime,
        conn: *ServerHandler.ConnectionT,
        decoder: serde.FrameDecoder,

        const Self = @This();

        fn attach(rt: *Runtime, conn: *ServerHandler.ConnectionT) !void {
            const loop = try runtime.loop();
            const self = try rt.allocator.create(Self);
            errdefer rt.allocator.destroy(self);
            self.* = .{
                .source = .{ .fd = conn.handle(), .onReadable = onReadable, .onRemoved = onRemoved },
                .rt = rt,
                .conn = conn,
                .decoder = .init(rt.allocator),
            };
            try loop.register(&self.source);
        }

        /// Reads until the socket is drained: a TLS session may hold decrypted
        /// bytes that no further socket readiness would report.
        fn onReadable(source: *EventLoop.Source, scratch: []u8) EventLoop.Action {
            const self: *Self = @alignCast(@fieldParentPtr("source", source));
            const handler = self.rt.handler(mode);
            while (true) {
                const n = self.conn.readSome(scratch) catch |err| switch (err) {
                    error.WouldBlock => return .keep,
                    else => {
                        if (self.conn.peer_addr) |addr| log.warn("recv error from {f}: {}", .{ fmtNetAddr(addr), err });
                        handler.handleErr(self.conn, err) catch {};
                        return .remove;
                    },
                };
                if (n == 0) {
                    if (self.conn.peer_addr) |addr| log.debug("peer disconnected from {f}", .{fmtNetAddr(addr)});
                    handler.handleErr(self.conn, error.EOF) catch {};
                    return .remove;
                }
                var input: []const u8 = scratch[0..n];
                while (true) {
                    const message = (self.decoder.next(&input) catch |err| {
                        handler.handleErr(self.conn, err) catch {};
                        return .remove;
                    }) orelse break;
                    if (!dispatchMessage(self.conn, message, handler)) return .remove;
                }
            }
        }

        fn onRemoved(source: *EventLoop.Source) void {
            const self: *Self = @alignCast(@fieldParentPtr("source", source));
            const rt = self.rt;
            const conn = self.conn;
            finishConnection(conn, rt.handler(mode));
            self.decoder.deinit();
            rt.allocator.destroy(self);
            releaseConnection(rt, conn);
        }
    };
}

/// Run the handler for one decoded message, honouring the ownership protocol.
///
/// OWNERSHIP PROTOCOL
/// ------------------
/// handle() transfers ownership via the `consumed` out-parameter: if
/// consumed=true the handler (e.g. onRequest) owns the message and will free it
/// later (via deinit()); we must not touch it again.  Returns false when the
/// connection should be dropped.
fn dispatchMessage(conn: *ServerHandler.ConnectionT, message: *Message, msg_handler: anytype) bool {
    var consumed = false;
    msg_handler.handle(conn, message, &consumed) catch |err| {
        // handle() failed before (or during) ownership transfer.
        // If not consumed, this thread still owns the message and must free it.
        if (!consumed) message.deinit();
        // Still flush any wakeup that a prior successful push may have set.
        msg_handler.triggerWakeup();
        msg_handler.handleErr(conn, err) catch {};
        return false;
    };
    // Do NOT read message fields when consumed==true — Python may have
    // already freed it.
    if (!consumed) message.deinit();
    // NOW wake the Python poller.  From this point the Python side may
    // dequeue and free any consumed messages.
    msg_handler.triggerWakeup();
    return true;
}

fn serverLoop(conn: *ServerHandler.ConnectionT, msgpool: *MessagePool, msg_handler: anytype) void {
    if (conn.peer_addr) |addr|
        log.debug("serverLoop started for {f}", .{fmtNetAddr(addr)});
    defer if (conn.peer_addr) |addr| log.debug("serverLoop exiting for {f}", .{fmtNetAddr(addr)});

    while (true) {
        const message = msgpool.receiveMessage(conn) catch |err| {
            if (conn.peer_addr) |addr| {
                // Clean peer hang-up (short-lived clients) is expected — debug only.
                // Unexpected recv failures stay at warn.
                switch (err) {
                    error.EOF => log.debug("serverLoop peer disconnected from {f}", .{fmtNetAddr(addr)}),
                    else => log.warn("serverLoop recv error from {f}: {}", .{ fmtNetAddr(addr), err }),
                }
            }
            msg_handler.handleErr(conn, err) catch {};
            break;
        };
        if (!dispatchMessage(conn, message, msg_handler)) break;
    }
    finishConnection(conn, msg_handler);
}

fn serverWsLoop(conn: *ServerHandler.ConnectionT, msgpool: *MessagePool, msg_handler: anytype) void {
    defer if (conn.peer_addr) |addr| log.debug("ws connection closed from {f}", .{fmtNetAddr(addr)});
    while (true) {
        const maybe_message = msgpool.receiveWsMessage(conn) catch |err| {
            msg_handler.handleErr(conn, err) catch {};
            break;
        };
        const message = maybe_message orelse break;
        if (!dispatchMessage(conn, message, msg_handler)) break;
    }
    finishConnection(conn, msg_handler);
}

/// Common tail of every receive loop.  The disconnect handler MUST run on every
/// exit path (it removes the connection from the channel map); it used to be
/// skipped when a handler returned an error, leaving a dangling entry behind.
fn finishConnection(conn: *ServerHandler.ConnectionT, msg_handler: anytype) void {
    msg_handler.handleDisconnect(conn) catch |err| log.warn("disconnect handler failed: {}", .{err});
    // Wake the Python poller so it can pick up the "disconnected" event message
    // that handleDisconnect() pushed onto the task queue.
    msg_handler.triggerWakeup();
}

pub fn sendMessage(data: []const u8, uuid: u16, flag: MessageFlag, decoder: MessageDecoder, is_bytes: bool, return_result: bool, receiver: []const u8, func_name: []const u8, conn_num: usize) !MessageIdentifier {
    return try (try getEntry(conn_num)).sendMessageServerEntry(data, uuid, flag, decoder, is_bytes, return_result, receiver, func_name);
}

pub fn getMessageForServerWorker(conn_num: usize) !?*Message {
    return try (try getEntry(conn_num)).getMessageForServerWorkerServerEntry();
}

pub fn setServiceMethods(methods: []const u8, conn_num: usize) !void {
    return try (try getEntry(conn_num)).setServiceMethodsServerEntry(methods);
}
