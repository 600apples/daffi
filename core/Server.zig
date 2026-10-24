const std = @import("std");
const misc = @import("misc.zig");
const serde = @import("serde.zig");
const network = @import("network.zig");
const handlers = @import("handlers.zig");
const store = @import("store.zig");
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

/// Per-server runtime state shared between the dispatcher (accept-loop) thread
/// and the per-connection threads it spawns.
const Runtime = struct {
    allocator: Allocator,
    connection: *ServerConnection,
    msgpool: *MessagePool,
    server_handler: *ServerHandler,
    /// Accepted connections whose thread is currently running.  Used to wake
    /// those threads (by shutting their sockets down) when the server stops.
    live_mutex: Mutex = .{},
    live: std.ArrayList(*ServerHandler.ConnectionT) = .empty,
    /// Number of connection threads that may still touch this struct.  The
    /// accept loop waits for it to reach zero before freeing anything.
    active_threads: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

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

/// Slot table.  A slot is claimed by `acquireSlot`, filled in by the dispatcher
/// thread, and returned by `releaseSlot` once the dispatcher has fully exited,
/// so slots are reused instead of being exhausted after 256 starts.
var slots_mutex: Mutex = .{};
var slot_used: [MAX_SERVERS]bool = [_]bool{false} ** MAX_SERVERS;
var slot_entries: [MAX_SERVERS]?ServerEntry = [_]?ServerEntry{null} ** MAX_SERVERS;

/// Per-slot ready flag.  Set to true (with release ordering) by the dispatcher
/// thread after it has written the ServerEntry into the slot.  Polled
/// (with acquire ordering) by startServer() so it can return only after the
/// slot is safe for Python to use.
var serverReady: [MAX_SERVERS]std.atomic.Value(bool) = blk: {
    var arr: [MAX_SERVERS]std.atomic.Value(bool) = undefined;
    for (&arr) |*v| v.* = std.atomic.Value(bool).init(false);
    break :blk arr;
};

/// Set to true when the dispatcher thread fails during initialisation.
/// Checked by startServer() so it can return None to Python instead of
/// silently handing back a conn_num that will never be usable.
var serverFailed: [MAX_SERVERS]std.atomic.Value(bool) = blk: {
    var arr: [MAX_SERVERS]std.atomic.Value(bool) = undefined;
    for (&arr) |*v| v.* = std.atomic.Value(bool).init(false);
    break :blk arr;
};

/// Claim a free slot, or null if all MAX_SERVERS are in use.
pub fn acquireSlot() ?usize {
    slots_mutex.lock();
    defer slots_mutex.unlock();
    for (&slot_used, 0..) |*used, i| {
        if (!used.*) {
            used.* = true;
            slot_entries[i] = null;
            serverReady[i].store(false, .release);
            serverFailed[i].store(false, .release);
            return i;
        }
    }
    return null;
}

pub fn releaseSlot(conn_num: usize) void {
    if (conn_num >= MAX_SERVERS) return;
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

pub fn hasFailed(conn_num: usize) bool {
    return serverFailed[conn_num].load(.acquire);
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
pub fn setServiceRequestFd(conn_num: usize, fd: i32) void {
    const entry = getEntry(conn_num) catch return;
    switch (entry.server_handler.*) {
        .Service => |*s| s.tasks_queue.request_fd = fd,
        .Router => {}, // routers have no task queue
    }
}

pub fn messageDispatcher(allocator: Allocator, app_name: []const u8, config: ServerConnection.Config, conn_num: usize) void {
    messageDispatcherImpl(allocator, app_name, config, conn_num) catch |err| {
        // Signal failure so startServer() returns None to Python.
        // Suppress the raw `error: X` line on stderr — Python will raise a
        // descriptive InitializationError instead.
        log.err("{s}[{s}] failed to start: {}", .{ @tagName(config.mode), app_name, err });
        serverFailed[conn_num].store(true, .release);
    };
}

/// How long stop waits for connection threads to finish before giving up and
/// leaking the server's memory rather than freeing it under them.
const DRAIN_TIMEOUT_MS: i64 = 10_000;

fn messageDispatcherImpl(allocator: Allocator, app_name_arg: []const u8, config: ServerConnection.Config, conn_num: usize) !void {
    // Entry point for server. It creates connection and message pool and starts server loop.
    try setSignalHandler();

    // The caller's strings (Python str buffers) are only guaranteed to live until
    // startServer() returns; the handler keeps `app_name` for the server's lifetime.
    const app_name = try allocator.dupe(u8, app_name_arg);
    var app_name_live = true;
    defer if (app_name_live) allocator.free(app_name);

    const msgpool: *MessagePool = try MessagePool.init(allocator);
    var msgpool_live = true;
    defer if (msgpool_live) msgpool.deinit();
    const conn: *ServerConnection = try ServerConnection.init(allocator, config);
    var conn_live = true;
    defer if (conn_live) conn.destroy();
    const server_handler = try ServerHandler.init(config.mode, allocator, app_name);
    var handler_live = true;
    defer if (handler_live) server_handler.deinit();
    const rt = try allocator.create(Runtime);
    rt.* = .{ .allocator = allocator, .connection = conn, .msgpool = msgpool, .server_handler = server_handler };
    var rt_live = true;
    defer if (rt_live) {
        rt.live.deinit(allocator);
        allocator.destroy(rt);
    };

    {
        slots_mutex.lock();
        defer slots_mutex.unlock();
        slot_entries[conn_num] = .{ .connection = conn, .msgpool = msgpool, .server_handler = server_handler, .runtime = rt };
    }
    serverReady[conn_num].store(true, .release);
    log.debug("{s}[{s}] listening on {s}:{d} conn_num={d}", .{
        @tagName(config.mode),
        app_name,
        config.host orelse "0.0.0.0",
        config.port,
        conn_num,
    });

    while (!conn.isSuspended()) {
        const raw = conn.acceptRaw(0) catch |err| {
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
        // The per-connection thread does the protocol probe / TLS handshake so a
        // silent peer cannot stall this loop.  Count it first so shutdown never
        // frees `rt` while the thread is still starting up.
        _ = rt.active_threads.fetchAdd(1, .acq_rel);
        const spawned = switch (config.mode) {
            .Service => std.Thread.spawn(.{}, serviceConnectionMain, .{ rt, raw }),
            .Router => std.Thread.spawn(.{}, routerConnectionMain, .{ rt, raw }),
        };
        if (spawned) |th| {
            th.detach();
        } else |err| {
            log.warn("failed to start connection thread: {}", .{err});
            _ = rt.active_threads.fetchSub(1, .acq_rel);
            (@import("network/posix_net.zig").Stream{ .handle = raw.fd }).close();
        }
    }

    // ---- shutdown -------------------------------------------------------
    log.debug("{s}[{s}] accept-loop exiting conn_num={d}", .{ @tagName(config.mode), app_name, conn_num });
    // Stop new users first, then wake the connection threads and wait for them.
    {
        slots_mutex.lock();
        slot_entries[conn_num] = null;
        slots_mutex.unlock();
    }
    rt.interruptAllLive();
    const deadline = misc.milliTimestamp() + DRAIN_TIMEOUT_MS;
    while (rt.active_threads.load(.acquire) != 0) {
        if (misc.milliTimestamp() > deadline) {
            // Freeing now would hand the stragglers dangling pointers.  Leaking a
            // few structs is the lesser evil.
            log.err("{s}[{s}] {d} connection thread(s) did not exit; leaking server state", .{ @tagName(config.mode), app_name, rt.active_threads.load(.acquire) });
            msgpool_live = false;
            conn_live = false;
            handler_live = false;
            rt_live = false;
            app_name_live = false;
            return;
        }
        rt.interruptAllLive();
        sleepMs(5);
    }
}

fn sleepMs(ms: u32) void {
    const ts = std.c.timespec{ .sec = @intCast(ms / 1000), .nsec = @intCast((ms % 1000) * std.time.ns_per_ms) };
    _ = std.c.nanosleep(&ts, null);
}

fn serviceConnectionMain(rt: *Runtime, raw: AcceptedConnection) void {
    connectionMain(.Service, rt, raw);
}

fn routerConnectionMain(rt: *Runtime, raw: AcceptedConnection) void {
    connectionMain(.Router, rt, raw);
}

/// Body of every per-connection thread: finish the accept (TLS + protocol
/// detection), run the receive loop, then release the connection.
fn connectionMain(comptime mode: HandlerMode, rt: *Runtime, raw: AcceptedConnection) void {
    // Must be the last thing to run: once the count hits zero the accept loop is
    // free to release `rt`, the message pool and the handler.
    defer _ = rt.active_threads.fetchSub(1, .release);

    const client = rt.connection.upgradeAccepted(raw) catch |err| {
        // upgradeAccepted already closed the descriptor.
        log.debug("rejected incoming connection: {}", .{err});
        return;
    };
    rt.registerLive(client) catch {
        client.destroy();
        return;
    };
    defer {
        rt.unregisterLive(client);
        // Drops the owner reference.  The socket is closed (and the struct freed)
        // when the last reference goes — channels in the router/service map hold
        // their own until the disconnect handler removes them.
        client.destroy();
    }

    const handler = switch (mode) {
        .Service => rt.server_handler.Service.handler(),
        .Router => rt.server_handler.Router.handler(),
    };
    if (client.is_websocket) {
        serverWsLoop(client, rt.msgpool, handler);
    } else {
        serverLoop(client, rt.msgpool, handler);
    }
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

/// Ask the server in `conn_num` to stop.  Returns immediately; the dispatcher
/// thread then wakes its connection threads, drains them and frees everything.
/// The caller should join that thread (see cffi `stopServer`).
pub fn destroyHandler(conn_num: usize) void {
    const entry = getEntry(conn_num) catch return;
    entry.connection.close();
}

pub fn getMessageForServerWorker(conn_num: usize) !?*Message {
    return try (try getEntry(conn_num)).getMessageForServerWorkerServerEntry();
}

pub fn setServiceMethods(methods: []const u8, conn_num: usize) !void {
    return try (try getEntry(conn_num)).setServiceMethodsServerEntry(methods);
}
