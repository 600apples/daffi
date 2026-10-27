const std = @import("std");
const builtin = @import("builtin");
const misc = @import("misc.zig");
const serde = @import("serde.zig");
const network = @import("network.zig");
const handlers = @import("handlers.zig");
const store = @import("store.zig");
const runtime = @import("runtime.zig");
const EventLoop = runtime.EventLoop;
const posix = std.posix;
const net = @import("network/posix_net.zig");
const nofile = @import("nofile.zig");
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

/// Pause a listener this long after `accept` fails (for example EMFILE), so
/// one stuck listener cannot spin its thread or event loop.  The others keep
/// accepting.
const ACCEPT_BACKOFF_MS: u32 = 50;

/// How often a server checks that its Unix socket files are still linked.
/// A missing file is bound again; a file that belongs to someone else is left
/// alone.
const UNIX_RESTORE_MS: c_int = 500;

/// How long stop waits for connections to finish before giving up and
/// leaking the server's memory rather than freeing it under them.
const DRAIN_TIMEOUT_MS: i64 = 10_000;

fn HandlerOf(comptime mode: HandlerMode) type {
    const H = @FieldType(ServerHandler, @tagName(mode));
    return @typeInfo(@TypeOf(H.handler)).@"fn".return_type.?;
}

/// One listening socket of a server.  Lives in `Runtime.listeners`, a slice
/// that never moves, because the event loop holds a pointer to `source`.
const Listener = struct {
    connection: *ServerConnection,
    source: EventLoop.Source = undefined,
    /// Event loop watching this listener, when the evented model is in use.
    loop: ?*EventLoop = null,
    /// Owned copy of the socket path.  Null for TCP listeners.
    unix_path: ?[:0]u8 = null,
    /// Identity of the directory entry bound at start (or after a restore).
    /// `fstat` on the socket itself does not report it.
    bound_id: ?FileId = null,
    /// Logged once while some other process holds `unix_path`.
    path_taken: bool = false,
    /// Logged once while rebinding `unix_path` keeps failing.
    rebind_logged: bool = false,
    /// The socket was replaced but its event-loop registration did not stick.
    unwatched: bool = false,
    /// Evented model: 1 while a back-off is due to re-arm this listener.
    /// `stop` waits for it to drop before freeing the listener.
    backoff: std.atomic.Value(u8) = .init(0),
    runtime: *Runtime,

    /// Accept every connection already queued on the socket.  Returns false
    /// if accepting failed for a reason other than "none left".
    fn drain(self: *Listener) bool {
        while (true) {
            const raw = self.connection.acceptRaw(0) catch |err| {
                if (err == error.Timeout) return true;
                log.warn("failed to accept connection: {}", .{err});
                return false;
            };
            admit(self.runtime, self.connection, raw);
        }
    }
};

/// What watches a server's listeners for new connections.  One watcher covers
/// all of them, so they start and stop accepting at the same moment.
const Acceptor = union(enum) {
    /// Threads model: one thread polls every listener plus a wake-up pipe
    /// (`pollfds[0]`) that `stop` writes to.
    thread: struct {
        handle: std.Thread,
        pollfds: []net.PollFd,
        /// Per listener: ignore that socket until this timestamp after a
        /// failed accept.  Zero means it is being polled.
        quiet_until: []i64,
        wake_write: c_int,
    },
    /// Evented model: every listener is a source on this one loop.
    loop: struct {
        loop: *EventLoop,
        sources: []*EventLoop.Source,
    },
};

/// Per-server state shared between every listener and every accepted connection.
const Runtime = struct {
    allocator: Allocator,
    mode: HandlerMode,
    app_name: []const u8,
    msgpool: *MessagePool,
    server_handler: *ServerHandler,
    /// Listening sockets, all equal.  They admit into this one runtime, so
    /// peers that arrive on different TCP ports or Unix sockets share one
    /// membership.
    listeners: []Listener,
    acceptor: ?Acceptor = null,
    /// Wakes `unixWatch`, which restores Unix socket files that were deleted.
    unix_watch: ?std.Thread = null,
    unix_wake_read: c_int = -1,
    unix_wake_write: c_int = -1,
    /// Accepted connections currently being served.  Used to interrupt them
    /// (by shutting their sockets down) when the server stops.
    live_mutex: Mutex = .{},
    live: std.ArrayList(*ServerHandler.ConnectionT) = .empty,
    /// Set under `live_mutex` before listeners are closed.  Accept paths that
    /// already passed `accept` refuse the connection instead of joining a
    /// server that is going away.
    stopping: bool = false,
    /// Accepted connections whose thread or event source may still touch this
    /// struct.  `stop` waits for it to reach zero before freeing anything.
    active_connections: std.atomic.Value(usize) = .init(0),

    /// Remember `conn` so shutdown can interrupt it.  Fails if the server is
    /// already stopping, in which case the caller must drop the connection.
    fn registerLive(self: *Runtime, conn: *ServerHandler.ConnectionT) !void {
        self.live_mutex.lock();
        defer self.live_mutex.unlock();
        // Checked under the lock: shutdown sets `stopping` first and then walks
        // `live` under this same lock, so a connection either gets registered
        // before the walk (and is closed by it) or is refused here.
        if (self.stopping) return error.ServerStopping;
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

    /// Start watching every listener.  All or nothing: on failure none of
    /// them is watched.
    fn startAccepting(self: *Runtime) !void {
        errdefer self.stopAccepting();
        switch (runtime.model()) {
            .threads => try self.startThreadedAccept(),
            .evented => try self.startEventedAccept(),
        }
        if (self.hasUnixPath()) {
            self.rememberUnixPaths();
            // The threaded acceptor checks the paths itself between polls.
            // The evented one is blocked in kqueue, so a helper thread does it.
            if (runtime.model() == .evented) try self.startUnixWatch();
        }
    }

    /// Errdefers here cover only this function.  Once `acceptor` is set, the
    /// thread owns the arrays and `stopAccepting` frees them.
    fn startThreadedAccept(self: *Runtime) !void {
        const pollfds = try self.allocator.alloc(net.PollFd, self.listeners.len + 1);
        errdefer self.allocator.free(pollfds);
        const quiet = try self.allocator.alloc(i64, self.listeners.len);
        errdefer self.allocator.free(quiet);
        @memset(quiet, 0);
        var wake: [2]c_int = undefined;
        nofile.acquire(2);
        if (std.c.pipe(&wake) != 0) {
            nofile.release(2);
            return error.PipeFailed;
        }
        errdefer {
            for (wake) |fd| _ = std.c.close(fd);
            nofile.release(2);
        }
        for (wake) |fd| _ = std.c.fcntl(fd, std.c.F.SETFD, @as(c_int, std.c.FD_CLOEXEC));
        pollfds[0] = .{ .fd = wake[0], .events = net.WAIT_READ, .revents = 0 };
        for (pollfds[1..], self.listeners) |*p, *listener|
            p.* = .{ .fd = listener.connection.handle(), .events = net.WAIT_READ, .revents = 0 };
        const handle = try std.Thread.spawn(.{}, acceptLoop, .{ self, pollfds, quiet });
        self.acceptor = .{ .thread = .{ .handle = handle, .pollfds = pollfds, .quiet_until = quiet, .wake_write = wake[1] } };
    }

    fn startEventedAccept(self: *Runtime) !void {
        const loop = try runtime.loop();
        const sources = try self.allocator.alloc(*EventLoop.Source, self.listeners.len);
        errdefer self.allocator.free(sources);
        for (self.listeners, sources) |*listener, *source| {
            listener.loop = loop;
            listener.source = .{ .fd = listener.connection.handle(), .onReadable = onListenerReadable, .onRemoved = onListenerRemoved };
            source.* = &listener.source;
        }
        // One step on the loop thread, so no listener accepts a peer before
        // every listener is watched.
        try loop.registerAll(sources);
        self.acceptor = .{ .loop = .{ .loop = loop, .sources = sources } };
    }

    fn hasUnixPath(self: *const Runtime) bool {
        for (self.listeners) |listener| if (listener.unix_path != null) return true;
        return false;
    }

    fn rememberUnixPaths(self: *Runtime) void {
        for (self.listeners) |*listener| {
            const path = listener.unix_path orelse continue;
            listener.bound_id = fileIdOfPath(path) catch null;
        }
    }

    fn startUnixWatch(self: *Runtime) !void {
        var wake: [2]c_int = undefined;
        nofile.acquire(2);
        if (std.c.pipe(&wake) != 0) {
            nofile.release(2);
            return error.PipeFailed;
        }
        errdefer {
            for (wake) |fd| _ = std.c.close(fd);
            nofile.release(2);
        }
        for (wake) |fd| _ = std.c.fcntl(fd, std.c.F.SETFD, @as(c_int, std.c.FD_CLOEXEC));
        self.unix_wake_read = wake[0];
        self.unix_wake_write = wake[1];
        self.unix_watch = try std.Thread.spawn(.{}, unixWatch, .{self});
    }

    /// Stop the Unix-socket watchdog, then stop watching every listener at
    /// once and wait until no accept is in progress.  The sockets stay open:
    /// connections still being upgraded use their TLS context.
    fn stopAccepting(self: *Runtime) void {
        if (self.unix_watch) |thread| {
            const byte = [1]u8{1};
            _ = std.c.write(self.unix_wake_write, &byte, byte.len);
            thread.join();
            self.unix_watch = null;
            _ = std.c.close(self.unix_wake_read);
            _ = std.c.close(self.unix_wake_write);
            nofile.release(2);
            self.unix_wake_read = -1;
            self.unix_wake_write = -1;
        }
        const acceptor = self.acceptor orelse return;
        self.acceptor = null;
        switch (acceptor) {
            .thread => |t| {
                const byte = [1]u8{1};
                _ = std.c.write(t.wake_write, &byte, byte.len);
                t.handle.join();
                _ = std.c.close(t.pollfds[0].fd);
                _ = std.c.close(t.wake_write);
                nofile.release(2);
                self.allocator.free(t.pollfds);
                self.allocator.free(t.quiet_until);
            },
            .loop => |l| {
                l.loop.detach(l.sources);
                self.allocator.free(l.sources);
            },
        }
    }

    /// Block until every evented accept back-off has finished touching its
    /// listener.  `stopping` is already set, so none of them re-arms.
    fn waitBackoffs(self: *Runtime) void {
        for (self.listeners) |*listener| {
            while (listener.backoff.load(.acquire) != 0) sleepMs(1);
        }
    }

    fn deinit(self: *Runtime) void {
        destroyListeners(self.allocator, self.listeners);
        self.server_handler.deinit();
        self.msgpool.deinit();
        self.live.deinit(self.allocator);
        self.allocator.free(self.app_name);
        self.allocator.destroy(self);
    }
};

const ServerEntry = struct {
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

/// Bind every listener in `configs` and return the server's single handle
/// (conn_num).  All or nothing: if one listener cannot be bound, none stays
/// bound and `failed` holds its index.  Sockets are not accepting yet;
/// `startServer` (the native entry of that name) starts them all at once.
pub fn start(allocator: Allocator, mode: HandlerMode, app_name: []const u8, configs: []const ServerConnection.Config, failed: *?usize) !usize {
    failed.* = null;
    return startImpl(allocator, mode, app_name, configs, failed) catch |err| {
        if (failed.*) |i| {
            log.err("{s}[{s}] failed to start on {s}:{d}: {}", .{ @tagName(mode), app_name, hostOf(configs[i]), configs[i].port, err });
        } else {
            log.err("{s}[{s}] failed to start: {}", .{ @tagName(mode), app_name, err });
        }
        return err;
    };
}

fn startImpl(allocator: Allocator, mode: HandlerMode, app_name_arg: []const u8, configs: []const ServerConnection.Config, failed: *?usize) !usize {
    if (configs.len == 0) return error.NoListeners;
    for (configs, 0..) |config, i| {
        for (configs[0..i]) |earlier| {
            if (sameAddress(config, earlier)) {
                failed.* = i;
                return error.DuplicateListener;
            }
        }
    }
    try setSignalHandler();
    const conn_num = acquireSlot() orelse return error.TooManyServers;
    errdefer releaseSlot(conn_num);

    const listeners = try bindAll(allocator, configs, failed);

    // The caller's strings (Python str buffers) are only guaranteed to live until
    // start() returns; the handler keeps `app_name` for the server's lifetime.
    // A successful block transfers those allocations (and the listeners) to the
    // runtime: its errdefers do not run, and `rt.deinit` is the single owner
    // afterwards.
    const rt = blk: {
        errdefer destroyListeners(allocator, listeners);
        const app_name = try allocator.dupe(u8, app_name_arg);
        errdefer allocator.free(app_name);
        const msgpool = try MessagePool.init(allocator);
        errdefer msgpool.deinit();
        const server_handler = try ServerHandler.init(mode, allocator, app_name);
        errdefer server_handler.deinit();
        const created = try allocator.create(Runtime);
        created.* = .{
            .allocator = allocator,
            .mode = mode,
            .app_name = app_name,
            .msgpool = msgpool,
            .server_handler = server_handler,
            .listeners = listeners,
        };
        for (listeners) |*listener| listener.runtime = created;
        break :blk created;
    };
    errdefer rt.deinit();
    // Publish the slot before anyone can connect.  Accepting starts later,
    // from `startServer`, once a Service has installed its task fd and
    // advertised its callbacks.  A client that connected in between would
    // otherwise finish the handshake with an empty method list.
    {
        slots_mutex.lock();
        defer slots_mutex.unlock();
        slot_entries[conn_num] = .{ .msgpool = rt.msgpool, .server_handler = rt.server_handler, .runtime = rt };
    }
    for (configs) |config| {
        log.debug("{s}[{s}] listening on {s}:{d} conn_num={d} model={s}", .{
            @tagName(mode),
            rt.app_name,
            hostOf(config),
            config.port,
            conn_num,
            @tagName(runtime.model()),
        });
    }
    return conn_num;
}

fn hostOf(config: ServerConnection.Config) []const u8 {
    return config.host orelse "0.0.0.0";
}

/// Two configs that would fight over one socket.  TCP port 0 asks for an
/// ephemeral port, so those never clash; Unix sockets always carry port 0.
fn sameAddress(a: ServerConnection.Config, b: ServerConnection.Config) bool {
    const host = hostOf(a);
    if (a.port != b.port or !std.mem.eql(u8, host, hostOf(b))) return false;
    return a.port != 0 or std.mem.indexOfScalar(u8, host, '/') != null;
}

/// Bind every listener at once, one thread each.  All or nothing: on failure
/// the sockets that did bind are closed again and `failed` names the first
/// listener that could not.  The returned listeners still need a runtime.
fn bindAll(allocator: Allocator, configs: []const ServerConnection.Config, failed: *?usize) ![]Listener {
    const Bind = struct {
        result: anyerror!*ServerConnection = error.NotBound,
        thread: ?std.Thread = null,

        fn run(self: *@This(), a: Allocator, config: ServerConnection.Config) void {
            self.result = ServerConnection.init(a, config);
        }
    };
    const listeners = try allocator.alloc(Listener, configs.len);
    errdefer allocator.free(listeners);
    const binds = try allocator.alloc(Bind, configs.len);
    defer allocator.free(binds);

    for (binds, configs) |*bind, config| {
        bind.* = .{};
        // A lone listener, or one no thread could be spawned for, binds inline.
        if (configs.len > 1) bind.thread = std.Thread.spawn(.{}, Bind.run, .{ bind, allocator, config }) catch null;
        if (bind.thread == null) bind.run(allocator, config);
    }
    for (binds) |bind| if (bind.thread) |thread| thread.join();

    for (binds, 0..) |bind, i| {
        _ = bind.result catch |err| {
            failed.* = i;
            for (binds) |other| {
                if (other.result) |conn| conn.destroy() else |_| {}
            }
            return err;
        };
    }
    var filled: usize = 0;
    errdefer {
        for (listeners[0..filled]) |listener| {
            if (listener.unix_path) |path| allocator.free(path);
        }
        for (binds) |bind| {
            if (bind.result) |conn| conn.destroy() else |_| {}
        }
    }
    for (listeners, binds, configs) |*listener, bind, config| {
        listener.* = .{
            .connection = bind.result catch unreachable,
            .unix_path = try duplicateUnixPath(allocator, config),
            .runtime = undefined,
        };
        filled += 1;
    }
    return listeners;
}

fn duplicateUnixPath(allocator: Allocator, config: ServerConnection.Config) !?[:0]u8 {
    const host = config.host orelse return null;
    if (std.mem.indexOfScalar(u8, host, '/') == null) return null;
    return try allocator.dupeSentinel(u8, host, 0);
}

fn destroyListeners(allocator: Allocator, listeners: []Listener) void {
    for (listeners) |listener| {
        if (listener.unix_path) |path| allocator.free(path);
        listener.connection.destroy();
    }
    allocator.free(listeners);
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

    rt.live_mutex.lock();
    rt.stopping = true;
    rt.live_mutex.unlock();
    rt.stopAccepting();
    rt.waitBackoffs();
    log.debug("{s}[{s}] stopped accepting on {d} listener(s) conn_num={d}", .{ @tagName(rt.mode), rt.app_name, rt.listeners.len, conn_num });

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

/// True when this server has a Unix socket, so the accept thread must wake
/// periodically.  When the interval has elapsed, rebuild any deleted socket
/// before the next poll.
fn restoreDue(rt: *Runtime, now: i64, last: *i64) bool {
    var unix = false;
    for (rt.listeners) |listener| if (listener.unix_path != null) {
        unix = true;
        break;
    };
    if (!unix) return false;
    if (now - last.* >= UNIX_RESTORE_MS) {
        for (rt.listeners) |*listener| if (listener.unix_path != null) restoreUnixListener(listener);
        last.* = misc.milliTimestamp();
    }
    return true;
}

/// Threads model: wait on every listener at once until `stop` writes to the
/// wake-up pipe in `pollfds[0]`.  A listener whose accept fails is left out
/// of the poll for `ACCEPT_BACKOFF_MS`; the others are not.
fn acceptLoop(rt: *Runtime, pollfds: []net.PollFd, quiet_until: []i64) void {
    var unix_checked = misc.milliTimestamp();
    while (true) {
        var timeout: c_int = -1;
        const now = misc.milliTimestamp();
        // Restore while not inside poll: dup2 replaces the file a blocked
        // poll is watching, and that poll would never see the new socket.
        if (restoreDue(rt, now, &unix_checked)) timeout = UNIX_RESTORE_MS;
        for (pollfds[1..], quiet_until, rt.listeners) |*pfd, *until, *listener| {
            if (until.* > now) {
                // poll ignores a negative fd, so this listener waits out its
                // back-off without delaying the others.
                pfd.fd = -1;
                const wait: c_int = @intCast(@min(until.* - now, std.math.maxInt(c_int)));
                if (timeout < 0 or wait < timeout) timeout = wait;
            } else {
                pfd.fd = listener.connection.handle();
                until.* = 0;
            }
        }
        if (net.poll(pollfds.ptr, @intCast(pollfds.len), timeout) < 0) {
            // EINTR, or a transient failure: retry without spinning.
            sleepMs(10);
            continue;
        }
        if (pollfds[0].revents != 0) return;
        for (pollfds[1..], quiet_until, rt.listeners) |pfd, *until, *listener| {
            if (pfd.fd < 0 or pfd.revents == 0) continue;
            if (!listener.drain()) until.* = misc.milliTimestamp() + ACCEPT_BACKOFF_MS;
        }
    }
}

/// Evented model: drain the pending connections of a readable listener.
/// A failed accept parks just this listener for `ACCEPT_BACKOFF_MS`.
fn onListenerReadable(source: *EventLoop.Source, _: []u8) EventLoop.Action {
    const listener: *Listener = @alignCast(@fieldParentPtr("source", source));
    if (listener.drain()) return .keep;
    // Already parked: this delivery was queued before the disarm.
    if (listener.backoff.swap(1, .acq_rel) != 0) return .keep;
    const loop = listener.loop orelse {
        listener.backoff.store(0, .release);
        return .keep;
    };
    loop.disarm(source);
    const thread = std.Thread.spawn(.{}, rearmListener, .{listener}) catch {
        sleepMs(ACCEPT_BACKOFF_MS);
        listener.backoff.store(0, .release);
        loop.register(source) catch |err| log.warn("listener stayed paused: {}", .{err});
        return .keep;
    };
    thread.detach();
    return .keep;
}

/// Re-arm a parked listener after the back-off.  Runs off the loop thread;
/// the actual re-arm is bounced onto the loop so it cannot land after `stop`
/// has freed the listener.
fn rearmListener(listener: *Listener) void {
    sleepMs(ACCEPT_BACKOFF_MS);
    const Rearm = struct {
        listener: *Listener,
        fn run(ctx: *anyopaque) void {
            const l: *Listener = @as(*@This(), @ptrCast(@alignCast(ctx))).listener;
            l.runtime.live_mutex.lock();
            const stopping = l.runtime.stopping;
            l.runtime.live_mutex.unlock();
            if (!stopping) {
                if (l.loop) |loop| {
                    loop.register(&l.source) catch |err| log.warn("listener stayed paused: {}", .{err});
                }
            }
            l.backoff.store(0, .release);
        }
    };
    var ctx = Rearm{ .listener = listener };
    if (listener.loop) |loop| {
        loop.call(Rearm.run, &ctx);
    } else {
        listener.backoff.store(0, .release);
    }
}

/// Replace a deleted Unix socket file, unless another process now owns the
/// path.  Existing connections ride on the old socket and are not touched.
fn unixWatch(rt: *Runtime) void {
    var pfd = net.PollFd{ .fd = rt.unix_wake_read, .events = net.WAIT_READ, .revents = 0 };
    while (true) {
        pfd.revents = 0;
        if (net.poll(@as([*]net.PollFd, @ptrCast(&pfd)), 1, UNIX_RESTORE_MS) > 0) return;
        rt.live_mutex.lock();
        const stopping = rt.stopping;
        rt.live_mutex.unlock();
        if (stopping) return;
        for (rt.listeners) |*listener| {
            if (listener.unix_path != null) restoreUnixListener(listener);
        }
    }
}

const PathState = enum { ours, absent, taken, unknown };

/// `fstat` of a Unix socket does not return the directory entry's identity
/// (on macOS the device comes back as -1), so the entry is remembered when
/// the socket is bound and compared with `stat` of the path afterwards.
fn unixPathState(listener: *Listener) PathState {
    const path = listener.unix_path orelse return .unknown;
    const at_path = fileIdOfPath(path) catch |err| switch (err) {
        error.Absent => return .absent,
        error.StatFailed => return .unknown,
    };
    const bound = listener.bound_id orelse {
        listener.bound_id = at_path;
        return .ours;
    };
    return if (at_path.eql(bound)) .ours else .taken;
}

fn rememberBoundPath(listener: *Listener) void {
    const path = listener.unix_path orelse return;
    listener.bound_id = fileIdOfPath(path) catch null;
}

const FileId = struct {
    dev: u64,
    ino: u64,

    fn eql(self: FileId, other: FileId) bool {
        return self.dev == other.dev and self.ino == other.ino;
    }
};

fn fileIdOfPath(path: [:0]const u8) error{ Absent, StatFailed }!FileId {
    if (comptime builtin.os.tag == .linux) return linuxFileId(std.os.linux.AT.FDCWD, path, 0);
    var st: std.c.Stat = undefined;
    if (std.c.stat(path.ptr, &st) != 0) {
        if (std.c._errno().* == @intFromEnum(std.c.E.NOENT)) return error.Absent;
        return error.StatFailed;
    }
    return .{ .dev = @intCast(st.dev), .ino = st.ino };
}

fn linuxFileId(dirfd: std.os.linux.fd_t, path: [*:0]const u8, flags: u32) error{ Absent, StatFailed }!FileId {
    var stx = std.mem.zeroes(std.os.linux.Statx);
    const rc = std.os.linux.statx(dirfd, path, flags, .{ .INO = true }, &stx);
    const signed: isize = @bitCast(rc);
    if (signed < 0) {
        if (signed == -@as(isize, @intFromEnum(std.os.linux.E.NOENT))) return error.Absent;
        return error.StatFailed;
    }
    return .{ .dev = (@as(u64, stx.dev_major) << 32) | stx.dev_minor, .ino = stx.ino };
}

fn restoreUnixListener(listener: *Listener) void {
    const path = listener.unix_path orelse return;
    if (listener.unwatched) {
        rewatchUnixListener(listener);
        if (listener.unwatched) return;
    }
    switch (unixPathState(listener)) {
        .ours => {
            listener.path_taken = false;
            listener.rebind_logged = false;
            return;
        },
        .unknown => return,
        .taken => {
            if (!listener.path_taken) {
                listener.path_taken = true;
                log.warn("unix listener {s} belongs to another process; leaving it alone", .{@as([]const u8, path)});
            }
            return;
        },
        .absent => {},
    }
    const new_fd = bindUnix(path) catch |err| {
        if (!listener.rebind_logged) {
            listener.rebind_logged = true;
            log.warn("unix listener {s} is gone and rebinding failed: {}", .{ @as([]const u8, path), err });
        }
        return;
    };
    if (listener.loop) |loop| {
        var swap = UnixSwap{ .listener = listener, .new_fd = new_fd };
        loop.call(UnixSwap.run, &swap);
        if (swap.new_fd >= 0) _ = std.c.close(swap.new_fd);
    } else if (replaceListeningFd(listener.connection.handle(), new_fd)) {
        rememberBoundPath(listener);
        listener.path_taken = false;
        listener.rebind_logged = false;
        log.info("restored unix listener {s}", .{@as([]const u8, path)});
    } else {
        _ = std.c.close(new_fd);
        if (!listener.rebind_logged) {
            listener.rebind_logged = true;
            log.warn("unix listener {s} is gone and replacing its socket failed", .{@as([]const u8, path)});
        }
    }
}

fn bindUnix(path: [:0]const u8) !c_int {
    const addr = try net.Address.initUnix(path);
    // The file is absent (the caller checked), so this does not unlink
    // anything a new owner may have just created: bind fails instead.
    return (try addr.listen(.{ .kernel_backlog = 512 })).handle;
}

const UnixSwap = struct {
    listener: *Listener,
    new_fd: c_int,

    fn run(ctx: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        const listener = self.listener;
        const loop = listener.loop orelse return;
        const path = listener.unix_path orelse return;
        const current = listener.connection.handle();
        // The kqueue entry watches the old socket, not the fd number, so the
        // replacement has to be registered again.
        loop.disarm(&listener.source);
        if (!replaceListeningFd(current, self.new_fd)) {
            loop.register(&listener.source) catch {};
            return;
        }
        self.new_fd = -1;
        rememberBoundPath(listener);
        listener.path_taken = false;
        listener.rebind_logged = false;
        loop.register(&listener.source) catch |err| {
            listener.unwatched = true;
            log.warn("unix listener {s} is bound again but not watched: {}", .{ @as([]const u8, path), err });
            return;
        };
        log.info("restored unix listener {s}", .{@as([]const u8, path)});
    }
};

fn rewatchUnixListener(listener: *Listener) void {
    const loop = listener.loop orelse {
        listener.unwatched = false;
        return;
    };
    const Run = struct {
        fn run(ctx: *anyopaque) void {
            const l: *Listener = @ptrCast(@alignCast(ctx));
            l.loop.?.register(&l.source) catch return;
            l.unwatched = false;
        }
    };
    loop.call(Run.run, @ptrCast(listener));
}

/// Make `current` refer to the socket `new_fd`, and close `new_fd`.
fn replaceListeningFd(current: c_int, new_fd: c_int) bool {
    if (std.c.dup2(new_fd, current) < 0) return false;
    _ = std.c.close(new_fd);
    _ = std.c.fcntl(current, std.c.F.SETFD, @as(c_int, std.c.FD_CLOEXEC));
    return true;
}

/// The listener never removes itself; `stop` detaches it.
fn onListenerRemoved(_: *EventLoop.Source) void {}

/// Hand an accepted descriptor to its own thread (threads model) or to the
/// blocking pool (evented model) for the protocol probe / TLS handshake, so a
/// silent peer cannot stall accepting.
fn admit(rt: *Runtime, listener: *ServerConnection, raw: AcceptedConnection) void {
    // Counted first so stop never frees `rt` while the connection starts up.
    _ = rt.active_connections.fetchAdd(1, .acq_rel);
    const started = switch (rt.mode) {
        .Service => startConnection(.Service, rt, listener, raw),
        .Router => startConnection(.Router, rt, listener, raw),
    };
    started catch |err| {
        log.warn("failed to start connection: {}", .{err});
        _ = rt.active_connections.fetchSub(1, .acq_rel);
        (net.Stream{ .handle = raw.fd }).close();
    };
}

fn startConnection(comptime mode: HandlerMode, rt: *Runtime, listener: *ServerConnection, raw: AcceptedConnection) !void {
    const main = struct {
        fn main(r: *Runtime, server: *ServerConnection, a: AcceptedConnection) void {
            connectionMain(mode, r, server, a);
        }
    }.main;
    switch (runtime.model()) {
        .threads => (try std.Thread.spawn(.{}, main, .{ rt, listener, raw })).detach(),
        .evented => try runtime.spawnBlocking(main, .{ rt, listener, raw }),
    }
}

/// Finish the accept (TLS + protocol detection), then serve the connection:
/// on this thread in the threads model, and also for WebSocket sessions;
/// otherwise as an event-loop source.
fn connectionMain(comptime mode: HandlerMode, rt: *Runtime, listener: *ServerConnection, raw: AcceptedConnection) void {
    const client = listener.upgradeAccepted(raw) catch |err| {
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

/// Start accepting on every listener.  Call once, after a Service has set
/// its request fd and callback list, so the first handshake already carries
/// those callbacks.
pub fn beginAccepting(conn_num: usize) !void {
    const rt = (try getEntry(conn_num)).runtime;
    if (rt.acceptor != null) return;
    try rt.startAccepting();
}

pub fn setServiceMethods(methods: []const u8, conn_num: usize) !void {
    return try (try getEntry(conn_num)).setServiceMethodsServerEntry(methods);
}
