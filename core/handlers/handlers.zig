const std = @import("std");
const mem = std.mem;
const handlers = @import("../handlers.zig");
const serde = @import("../serde.zig");
const network = @import("../network.zig");
const fmtNetAddr = @import("../network/connection.zig").fmtNetAddr;
const store = @import("../store.zig");
const Allocator = mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Message = serde.Message;
const RawMessage = serde.RawMessage;
const Handshake = serde.Handshake;
const Event = serde.Event;
const MessageFlag = serde.MessageFlag;
const ConnectionType = network.ConnectionType;
const Connection = network.Connection;
const MessagePool = serde.MessagePool;
const MessageHandler = handlers.MessageHandler;
const ClientMessageStore = store.ClientMessageStore;
const ChannelsMapper = store.ChannelsMapper;
const TasksQueue = store.TasksQueue;
const misc = @import("../misc.zig");
const Mutex = misc.Mutex;

// Scoped loggers — each handler module gets a distinctive scope so log lines
// show e.g. "| native[router] |" or "| native[client] |".
const log_service = std.log.scoped(.service);
const log_router  = std.log.scoped(.router);
const log_client  = std.log.scoped(.client);

pub const HandlerMode = enum {
    Service,
    Router,
};

fn RoundRobinIterator(comptime T: type) type {
    return struct {
        position: usize = 0,
        counter: usize = 0,

        fn next(self: *@This(), data: []const T) ?T {
            const data_len = data.len;
            if (data_len == 0) return null;
            while (self.counter < data_len) {
                // round-robin task cycle. start from end position of previous call.
                self.counter += 1;
                self.position = @rem(self.position + 1, data_len);
                return data[self.position];
            }
            return null;
        }

        fn reset(self: *@This()) void {
            self.counter = 0;
        }
    };
}

/// Send an ERROR reply for `request` back over `conn`.  Best effort: if it
/// fails as well the requester times out.
fn replyError(comptime log: type, allocator: Allocator, conn: anytype, request: *Message, name: []const u8, text: []const u8) void {
    if (comptime misc.is_wasm) return;
    const reply = serde.createErrorReply(allocator, request, name, text) catch |err| {
        log.warn("cannot build error reply: {}", .{err});
        return;
    };
    defer allocator.free(reply.data);
    conn.write(reply.data) catch |err| log.debug("error reply not delivered: {}", .{err});
}

const CommonHandlers = struct {
    pub fn onEmpty(ctx: *anyopaque, message: *Message) !void {
        _ = ctx;
        // return error.NoHandler;
        std.log.scoped(.handler).warn("no handler for message uuid={}", .{message.getUuid()});
    }
};

pub fn ServerHandler(comptime HandlerConnectionT: ConnectionType) type {

    // Service/Router handlers
    return union(HandlerMode) {
        Service: ServiceHandler,
        Router: RouterHandler,

        const HandlerUnion = @This();
        pub const ConnectionT = Connection(HandlerConnectionT);
        const ChannelsMapperT = ChannelsMapper(ConnectionT);

        pub fn init(mode: HandlerMode, allocator: Allocator, app_name: []const u8) !*HandlerUnion {
            const self = try allocator.create(HandlerUnion);
            return switch (mode) {
                .Service => blk: {
                    self.* = .{ .Service = .{ .allocator = allocator, .chan_mapper = try ChannelsMapperT.init(allocator), .tasks_queue = .{}, .app_name = app_name } };
                    break :blk self;
                },
                .Router => blk: {
                    self.* = .{ .Router = .{ .allocator = allocator, .chan_mapper = try ChannelsMapperT.init(allocator), .app_name = app_name } };
                    break :blk self;
                },
            };
        }

        pub fn deinit(self: *HandlerUnion) void {
            const allocator = switch (self.*) {
                .Service => |*s| blk: {
                    s.tasks_queue.deinit();
                    s.chan_mapper.deinit();
                    if (s.methods) |m| s.allocator.free(m);
                    break :blk s.allocator;
                },
                .Router => |*r| blk: {
                    r.chan_mapper.deinit();
                    break :blk r.allocator;
                },
            };
            allocator.destroy(self);
        }

        const ServiceHandler = struct {
            chan_mapper: *ChannelsMapperT,
            tasks_queue: TasksQueue,
            allocator: Allocator,
            app_name: []const u8,
            methods: ?[]const u8 = null, // comma separated list of service methods
            task_cycle_position: usize = 0,
            mutex: Mutex = .{},
            chan_iterator: RoundRobinIterator(ChannelsMapperT.Channel) = .{},

            const Self = @This();
            pub const ParentConnT = ConnectionT;
            const MessageHandlerT = MessageHandler(Self);

            fn wakeupFn(self: *Self) void {
                self.tasks_queue.triggerWakeup();
            }

            pub fn handler(self: *const Self) MessageHandlerT {
                return .{
                    .ptr = @constCast(self),
                    .handlers_mapping = MessageHandlerT.createMapping(.{ .HANDSHAKE = onHandshake, .REQUEST = onRequest }),
                    .error_handler = errorHandler,
                    .disconnection_handler = diconnectionHandler,
                    .wakeup_fn = wakeupFn,
                };
            }

            pub fn setServiceMethods(self: *Self, methods: []const u8) !void {
                if (self.methods) |m| self.allocator.free(m);
                self.methods = try self.allocator.dupe(u8, methods);
            }

            fn sendToConnection(_: *Self, comptime MessageT: type, conn: *ParentConnT, message: *MessageT) !void {
                message.sendTo(conn) catch |err| {
                    switch (err) {
                        error.NotOpenForWriting, error.BrokenPipe, error.WriteError => {},
                        else => {
                            if (conn.getAddr()) |addr| {
                                log_service.warn("failed to send message to {f}: {any}", .{ fmtNetAddr(addr), err });
                            } else {
                                log_service.warn("failed to send message (connection already closed): {any}", .{err});
                            }
                        },
                    }
                };
            }

            // ----------------------------- SERVICE HANDLERS -----------------------------
            fn onHandshake(self: *Self, conn: *ParentConnT, message: *Message, _: *bool) !void {
                // The mutex only protects channel-map bookkeeping.  Socket writes
                // (which can block on a slow peer) happen after it is released.
                self.mutex.lock();
                var locked = true;
                defer if (locked) self.mutex.unlock();
                var arena = ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                var allocator = arena.allocator();
                var client_hs = Handshake.fromJson(allocator, message.getData()) catch |err| {
                    log_service.err("handshake parse error: {s}", .{@errorName(err)});
                    try message.writeErrorMessage("failed to parse handshake message: {s}", .{@errorName(err)});
                    try self.sendToConnection(Message, conn, message);
                    return;
                };
                defer client_hs.deinit();
                const connection_name = try allocator.dupe(u8, message.getTransmitter());

                // Last-connection-wins: if a slot for this name already exists
                // (stale zombie from an abrupt network cut or process kill that
                // never sent a TCP FIN), evict it and accept the new peer.
                // The evicted connection is closed AFTER we release the channel
                // map entry so that its reader thread's diconnectionHandler call
                // finds no channel and returns cleanly.
                //
                // An "evicted" EVENT is pushed to tasks_queue so the service's
                // Python handlers can react before the "connected" event fires.
                var stale_conn: ?*ParentConnT = null; // owned reference
                defer if (stale_conn) |sc| sc.release();
                var evict_event: ?*Message = null; // freed below unless handed to the queue
                defer if (evict_event) |ev| ev.deinit();
                if (self.chan_mapper.evictChannel(connection_name, conn)) |sc| {
                    stale_conn = sc;
                    log_service.warn("evicting stale slot for '{s}' — new connection takes over", .{connection_name});
                    evict_event = try serde.createEventMessage(self.allocator, 0, connection_name, "evicted");
                }
                _ = try self.chan_mapper.getOrCreateChannel(conn, connection_name);
                const methods = self.methods orelse serde.PLACEHOLDER;

                var service_hs = try Handshake.create(allocator, &[_]Handshake.MemberData{.{ .name = self.app_name, .methods = methods }}, "service");
                const data = try service_hs.toJson(allocator);
                try message.setData(data);

                // Event message for the service itself.
                const event_message = try serde.createEventMessage(self.allocator, 0, connection_name, "connected");
                var event_pushed = false;
                defer if (!event_pushed) event_message.deinit();

                self.mutex.unlock();
                locked = false;

                // Reply only to the client that just connected, and before the
                // stale peer is told: that write may stall on a dead socket.
                // Writing to every older client as well made connect number N
                // do N socket writes, so a few thousand clients never finished.
                try self.sendToConnection(Message, conn, message);
                if (stale_conn) |sc| {
                    // Use the event BEFORE handing it to the queue: once pushed,
                    // Python may dequeue and free it at any moment.
                    try self.sendToConnection(Message, sc, evict_event.?);
                    sc.close();
                    self.tasks_queue.pushMessageToQueue(evict_event.?);
                    evict_event = null;
                }
                self.tasks_queue.pushMessageToQueue(event_message);
                event_pushed = true;
            }

            fn onRequest(self: *Self, conn: *ParentConnT, message: *Message, consumed: *bool) !void {
                // No handler mutex: the queue has its own, and taking
                // ``self.mutex`` serialised every client reader thread.
                // Once pushed, Python may free the message at any moment.
                if (self.tasks_queue.tryPushRequest(message)) {
                    consumed.* = true;
                    return;
                }
                log_service.warn("task queue full ({d} pending), refusing request uuid={d}", .{ TasksQueue.max_pending, message.getUuid() });
                if (message.getReturnResult()) replyError(log_service, self.allocator, conn, message, "ServiceOverloaded", "the service has too many pending requests");
            }

            // ---------------------- SERVICE CONNECTION LIFECYCLE ------------------------
            fn diconnectionHandler(self: *Self, conn: *ParentConnT) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                // One connection can hold several channels (a peer may
                // handshake again under another name).
                while (self.chan_mapper.getChannelByConnection(conn)) |chan| {
                    const event_message = try serde.createEventMessage(self.allocator, 0, chan.connection_name, "disconnected");
                    self.chan_mapper.destroyChannel(chan);
                    self.tasks_queue.pushMessageToQueue(event_message);
                }
            }

            fn errorHandler(_: *Self, conn: *ParentConnT, err: anyerror) !void {
                switch (err) {
                    error.EOF => {},
                    error.IncompleteMessage => {
                        const addr = conn.getAddr();
                        log_service.debug("incomplete message from {?}", .{addr});
                    },
                    else => log_service.debug("failed to receive message: {}", .{err}),
                }
            }

            // error_handler / disconnection_handler keep their original signatures
            // (they are not part of handlers_mapping and don't receive *bool).
        };

        const RouterHandler = struct {
            chan_mapper: *ChannelsMapperT,
            app_name: []const u8,
            allocator: Allocator,
            mutex: Mutex = .{},

            const Self = @This();
            pub const ParentConnT = ConnectionT;
            const MessageHandlerT = MessageHandler(Self);
            fn wakeupFn(_: *Self) void {}

            pub fn handler(self: *const Self) MessageHandlerT {
                return .{
                    .ptr = @constCast(self),
                    .handlers_mapping = MessageHandlerT.createMapping(.{ .HANDSHAKE = onHandshake, .REQUEST = onRequest, .RESPONSE = onResponse, .ERROR = onResponse }),
                    .error_handler = errorHandler,
                    .disconnection_handler = diconnectionHandler,
                    .wakeup_fn = wakeupFn,
                };
            }

            fn findChannel(self: *Self, method: ?[]const u8, receiver: []const u8) ?ChannelsMapperT.Channel {
                var chan = self.chan_mapper.getChannel(receiver) catch {
                    log_router.debug("no channel for receiver: {s}", .{receiver});
                    return null;
                };
                if (method == null or chan.containsMethod(method.?)) return chan;
                return null;
            }

            fn sendToConnection(_: *Self, comptime MessageT: type, conn: *ParentConnT, message: *MessageT) !void {
                message.sendTo(conn) catch |err| {
                    switch (err) {
                        error.NotOpenForWriting, error.BrokenPipe, error.WriteError => {},
                        else => {
                            if (conn.getAddr()) |addr| {
                                log_router.warn("failed to send message to {f}: {any}", .{ fmtNetAddr(addr), err });
                            } else {
                                log_router.warn("failed to send message (connection already closed): {any}", .{err});
                            }
                        },
                    }
                };
            }

            // ----------------------------- ROUTER HANDLERS -----------------------------
            fn onHandshake(self: *Self, conn: *ParentConnT, message: *Message, _: *bool) !void {
                self.mutex.lock();
                // Unlock on every exit while still holding the mutex. Cleared to
                // false after the intentional unlock before the broadcast section.
                var locked = true;
                defer if (locked) self.mutex.unlock();

                var arena = ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                var alloc = arena.allocator();
                const connection_name = try alloc.dupe(u8, message.getTransmitter()); // for event
                const client_hs = Handshake.fromJson(alloc, message.getData()) catch |err| {
                    log_router.err("handshake parse error from {s}: {s}", .{ connection_name, @errorName(err) });
                    try message.writeErrorMessage("failed to parse handshake message: {s}", .{@errorName(err)});
                    try self.sendToConnection(Message, conn, message);
                    return;
                };
                // Evict stale slots (last-connection-wins).  Only the bookkeeping
                // happens under the mutex; the "evicted" notifications and the
                // close are done after it is released (see below).
                const Evicted = struct { name: []const u8, conn: *ParentConnT };
                var evicted: std.ArrayList(Evicted) = .empty;
                defer {
                    for (evicted.items) |e| e.conn.release();
                    evicted.deinit(self.allocator);
                }
                for (client_hs.value.members) |mb| {
                    if (self.chan_mapper.evictChannel(mb.name, conn)) |stale_conn| {
                        log_router.warn("evicting stale slot for '{s}' — new connection takes over", .{mb.name});
                        evicted.append(self.allocator, .{ .name = try alloc.dupe(u8, mb.name), .conn = stale_conn }) catch |err| {
                            stale_conn.release();
                            return err;
                        };
                    }
                }
                for (client_hs.value.members) |mb| {
                    var chan = try self.chan_mapper.getOrCreateChannel(conn, mb.name);
                    chan.clear();
                    if (mb.methods) |methods| {
                        for (methods) |mt| try chan.addMethod(mt);
                    }
                }
                const all_chans = self.chan_mapper.allChannels();
                var memberdata = try alloc.alloc(Handshake.MemberData, all_chans.len);
                for (all_chans, 0..) |*c, idx| {
                    memberdata[idx] = .{ .name = c.connection_name, .methods = try c.joinedMethods(alloc, serde.UNIT_SEPARATOR) };
                }
                var router_hs = try Handshake.create(alloc, memberdata, "router");
                const hs_data = try router_hs.toJson(alloc);
                try message.setData(hs_data);

                // Build broadcast messages while holding mutex so channel state
                // is consistent with what we captured above.
                var mini_broadcast: ?*Message = null;
                // `connection_name` is the transmitter from the message metadata, while
                // channels are registered under the names in the JSON body; a peer
                // is free to make those differ, so the lookup can legitimately miss.
                const new_chan = self.chan_mapper.channels.getPtr(connection_name);
                if (new_chan != null and new_chan.?.methods.hash_map.count() > 0) {
                    const new_member_methods = try new_chan.?.joinedMethods(alloc, serde.UNIT_SEPARATOR);
                    var mini_memberdata = try alloc.alloc(Handshake.MemberData, 1);
                    mini_memberdata[0] = .{ .name = connection_name, .methods = new_member_methods };
                    mini_broadcast = try serde.createHandshakeMessage(self.allocator, mini_memberdata, 0, "router");
                }
                defer if (mini_broadcast) |mb| mb.deinit();

                var connected_event = try serde.createEventMessage(self.allocator, 0, connection_name, "connected");
                defer connected_event.deinit();

                // Collect broadcast targets with retain() so their connections
                // stay alive after we release self.mutex.  Size grows with the
                // number of peers — no fixed cap / silent skip.
                var bcast_conns: std.ArrayList(*ParentConnT) = .empty;
                defer {
                    for (bcast_conns.items) |c| c.release();
                    bcast_conns.deinit(self.allocator);
                }
                for (self.chan_mapper.channels.values()) |c| {
                    if (std.mem.eql(u8, connection_name, c.connection_name)) continue;
                    c.conn.retain();
                    bcast_conns.append(self.allocator, c.conn) catch |err| {
                        c.conn.release();
                        return err;
                    };
                }

                // The member list goes out after the mutex is released, so a
                // slow new peer cannot stall the router.  Its write side is
                // taken first: a concurrent handshake that already sees this
                // peer queues its broadcast behind the list instead of
                // overtaking it (the list rebuilds the peer's routing table).
                conn.lockWrites();
                self.mutex.unlock();
                locked = false;
                const list_sent = conn.writeHeld(message.data);
                conn.unlockWrites();
                list_sent catch |err| log_router.debug("member list not delivered to {s}: {}", .{ connection_name, err });

                // 0. Tell everyone (and the evicted peer itself) that stale slots
                //    were taken over, then drop the stale sockets.
                for (evicted.items) |e| {
                    var evicted_event = serde.createEventMessage(self.allocator, 0, e.name, "evicted") catch continue;
                    defer evicted_event.deinit();
                    for (bcast_conns.items) |c| self.sendToConnection(Message, c, evicted_event) catch {};
                    self.sendToConnection(Message, e.conn, evicted_event) catch {};
                    e.conn.close();
                }

                // 1. Mini-HANDSHAKE so receiving clients update their routing tables.
                if (mini_broadcast) |mb| {
                    for (bcast_conns.items) |c|
                        self.sendToConnection(Message, c, mb) catch {};
                }
                // 2. "connected" EVENT drives @on_event("connected") handlers.
                for (bcast_conns.items) |c|
                    self.sendToConnection(Message, c, connected_event) catch {};
            }

            fn onRequest(self: *Self, conn: *ParentConnT, message: *Message, _: *bool) !void {
                log_router.debug("onRequest func={s} receiver={s}", .{ message.getFuncName(), message.getReceiver() });
                self.mutex.lock();
                const target_conn: ?*ParentConnT = blk: {
                    if (self.findChannel(message.getFuncName(), message.getReceiver())) |c| {
                        c.conn.retain();
                        break :blk c.conn;
                    }
                    break :blk null;
                };
                self.mutex.unlock();

                const target = target_conn orelse {
                    log_router.debug("no route for request to: {s}", .{message.getReceiver()});
                    if (message.getReturnResult()) replyError(log_router, self.allocator, conn, message, "ReceiverNotFound", "no connected peer with that name exposes the requested callback");
                    return;
                };
                defer target.release();
                target.write(message.data) catch |err| {
                    log_router.debug("onRequest: send to {s} failed: {}", .{ message.getReceiver(), err });
                    if (message.getReturnResult()) replyError(log_router, self.allocator, conn, message, "DeliveryFailed", "the router could not forward the request to its receiver");
                };
            }

            fn onResponse(self: *Self, _: *ParentConnT, message: *Message, _: *bool) !void {
                log_router.debug("onResponse receiver={s} uuid={}", .{ message.getReceiver(), message.getUuid() });
                // Same retain/release pattern as onRequest — see its comment.
                self.mutex.lock();
                const target_conn: ?*ParentConnT = blk: {
                    if (self.findChannel(null, message.getReceiver())) |c| {
                        c.conn.retain();
                        break :blk c.conn;
                    }
                    break :blk null;
                };
                self.mutex.unlock();

                if (target_conn) |c| {
                    defer c.release();
                    self.sendToConnection(Message, c, message) catch |err|
                        log_router.debug("onResponse: send to {s} failed: {}", .{ message.getReceiver(), err });
                } else {
                    log_router.debug("no route for response to: {s}", .{message.getReceiver()});
                }
            }

            // --------------------- ROUTER CONNECTION LIFECYCLE ----------------------
            fn diconnectionHandler(self: *Self, conn: *ParentConnT) !void {
                self.mutex.lock();
                var locked = true;
                defer if (locked) self.mutex.unlock();
                var arena = ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                var allocator = arena.allocator();

                // A client registers one channel per member it announced.
                var departed: std.ArrayList([]const u8) = .empty;
                while (self.chan_mapper.getChannelByConnection(conn)) |chan| {
                    try departed.append(allocator, try allocator.dupe(u8, chan.connection_name));
                    self.chan_mapper.destroyChannel(chan);
                }
                if (departed.items.len == 0) return;

                // Send a "disconnected" EVENT to every remaining client.
                //
                // The "disconnected" EVENT is the sole mechanism for removing a
                // departed peer: the client-side ``onEvent`` handler calls
                // ``destroyChannelByName`` in Zig (updating the chan_mapper
                // atomically) and then pushes the event to the Python task queue
                // so ``@on_event("disconnected")`` handlers are notified.  (A full
                // HANDSHAKE rebuild here would be O(N^2) traffic per disconnect and
                // would overwrite live chan_mapper state.)
                //
                // Targets are snapshotted with references and written to after the
                // mutex is released, so one slow peer cannot stall the router.
                var targets: std.ArrayList(*ParentConnT) = .empty;
                defer {
                    for (targets.items) |t| t.release();
                    targets.deinit(self.allocator);
                }
                for (self.chan_mapper.channels.values()) |c| {
                    try targets.ensureUnusedCapacity(self.allocator, 1);
                    c.conn.retain();
                    targets.appendAssumeCapacity(c.conn);
                }
                self.mutex.unlock();
                locked = false;
                for (departed.items) |name| {
                    var event_message = try serde.createEventMessage(self.allocator, 0, name, "disconnected");
                    defer event_message.deinit();
                    for (targets.items) |t| try self.sendToConnection(Message, t, event_message);
                }
            }

            fn errorHandler(_: *Self, conn: *ParentConnT, err: anyerror) !void {
                switch (err) {
                    error.EOF => {},
                    error.IncompleteMessage => {
                        const addr = conn.getAddr();
                        log_router.debug("incomplete message from {?}", .{addr});
                    },
                    else => log_router.debug("failed to receive message: {}", .{err}),
                }
            }
        };
    };
}

// error_handler / disconnection_handler keep their original signatures — they
// are stored in separate function-pointer fields (not in handlers_mapping) and
// are called with their own wrappers (handleErr / handleDisconnect), so they
// do not need the consumed: *bool parameter.

// Client handlers

pub const ClientHandler = struct {
    msg_store: ClientMessageStore,
    tasks_queue: TasksQueue,
    chan_mapper: *ChannelsMapperT,
    app_name: []const u8,
    methods: ?[]const u8 = null, // comma separated list of service methods
    allocator: Allocator,
    mutex: Mutex = .{},
    chan_iterator: RoundRobinIterator(ChannelsMapperT.Channel) = .{},
    /// Set by the handlers for the message being dispatched; `wakeupFn`
    /// signals only the descriptor that has something new.  Only the one
    /// receiver of this client touches them.
    task_pushed: bool = false,
    response_parked: bool = false,
    /// The server announced that a newer connection took this client's name.
    evicted: std.atomic.Value(bool) = .init(false),

    const Self = @This();
    pub const ParentConnT = Connection(.ClientConnectionType);
    const MessageHandlerT = MessageHandler(Self);
    const ChannelsMapperT = ChannelsMapper(ParentConnT);

    pub fn init(allocator: Allocator, app_name: []const u8) !*ClientHandler {
        const self = try allocator.create(ClientHandler);
        errdefer allocator.destroy(self);
        const chan_mapper = try ChannelsMapperT.init(allocator);
        errdefer chan_mapper.deinit();
        self.* = .{ .chan_mapper = chan_mapper, .tasks_queue = .{}, .allocator = allocator, .msg_store = ClientMessageStore.init(allocator), .app_name = try allocator.dupe(u8, app_name) };
        return self;
    }

    pub fn deinit(self: *ClientHandler) void {
        self.tasks_queue.deinit();
        self.chan_mapper.deinit();
        self.msg_store.deinit();
        self.allocator.free(self.app_name);
        self.allocator.destroy(self);
    }

    /// Runs after the dispatcher is done with the message: once Python
    /// wakes it may pop and free it.
    fn wakeupFn(self: *Self) void {
        if (self.task_pushed) {
            self.task_pushed = false;
            self.tasks_queue.triggerWakeup();
        }
        if (self.response_parked) {
            self.response_parked = false;
            self.msg_store.triggerWakeup();
        }
    }

    fn storeResponse(self: *Self, message: *Message, consumed: *bool) void {
        const placed = self.msg_store.insert(message) catch |err| {
            switch (err) {
                // The caller timed out and gave up on this uuid: expected.
                error.Expired => log_client.debug("dropping late response for uuid={}", .{message.getUuid()}),
                else => log_client.warn("dropping response for uuid={}: {}", .{ message.getUuid(), err }),
            }
            return;
        };
        consumed.* = true;
        if (placed == .parked) self.response_parked = true;
    }

    pub fn handler(self: *const Self) MessageHandlerT {
        return .{
            .ptr = @constCast(self),
            // EVENTS are routed to onEvent (not onRequest) so that:
            // * "disconnected" events update the Zig chan_mapper inline (via
            //   destroyChannelByName) before the message is pushed to the task
            //   queue for Python @on_event handlers.
            // * "connected" and all other events are pushed to the task queue so
            //   Python @on_event handlers are notified.
            .handlers_mapping = MessageHandlerT.createMapping(.{ .HANDSHAKE = onHandshake, .REQUEST = onRequest, .EVENTS = onEvent, .RESPONSE = onResponse, .ERROR = onResponse }),
            .error_handler = errorHandler,
            .disconnection_handler = diconnectionHandler,
            .wakeup_fn = wakeupFn,
        };
    }

    /// Resolve the target peer for *method* and return a newly-allocated,
    /// caller-owned copy of that peer's connection_name.
    ///
    /// Why a copy?  Callers propagate the returned slice through several
    /// layers (``msgpool.sendMessage``, the ``MessageIdentifier`` return
    /// chain, and finally ``Py_BuildValue("...s#...")`` at the CFFI boundary)
    /// *after* the resolution step releases its locks.  If we returned a
    /// borrowed view into ``chan_mapper``'s storage, a concurrent handshake
    /// or "disconnected" event on the reader thread could free the underlying
    /// Channel before the caller is done — a classic use-after-free.  When
    /// the freed bytes happened to be reused by another allocation the bug
    /// surfaced as a random ``UnicodeDecodeError`` out of ``s#`` (or a
    /// ``TransmissionFailure`` wrapping it) in ``test_concurrent_mixed_callbacks``.
    ///
    /// Duplication happens while the appropriate mutex is still held:
    ///   * explicit receiver: ``chan_mapper.findReceiverDupe`` locks the
    ///     ``ChannelsMapper`` mutex across lookup + dupe.
    ///   * round-robin: ``self.mutex`` is held across the ``allChannels()``
    ///     walk *and* the dupe of the selected entry.
    ///
    /// Caller must free the returned slice with ``self.allocator`` — see the
    /// ``defer`` in ``core/cffi/client.zig:sendMessageFromClient``.
    pub fn findReceiverForMethod(self: *Self, method: []const u8, receiver: ?[]const u8) ![]const u8 {
        // Always hold client_handler.mutex for the entire lookup.
        //
        // Rationale: chan_mapper.allChannels() returns a raw slice into the
        // HashMap backing array.  onHandshake calls chan.clear() and
        // chan.addMethod() *after* releasing chan_mapper.mutex but still holding
        // client_handler.mutex.  Without client_handler.mutex here, the explicit-
        // receiver path (which previously relied on chan_mapper.mutex only) could
        // race with chan.clear() / chan.addMethod() — reading a BufSet that is
        // being concurrently freed/rebuilt, causing SIGSEGV.
        //
        // Lock ordering:  client_handler.mutex  →  chan_mapper.mutex  (inside
        // findReceiverDupe / getOrCreateChannel).  onEvent follows the same
        // order, so no deadlock is possible.
        self.mutex.lock();
        defer self.mutex.unlock();
        if (receiver) |rec| {
            if (mem.eql(u8, rec, self.app_name)) return error.ReceiverNotFound;
            return self.chan_mapper.findReceiverDupe(self.allocator, rec, method) catch |err| switch (err) {
                error.ChannelNotFound => {
                    log_client.debug("no channel for receiver: {s}", .{rec});
                    return error.ReceiverNotFound;
                },
                else => return err,
            };
        }
        // #9: round-robin across method-matching channels WITHOUT allocating an
        // intermediate list.  Two O(N) passes over allChannels() avoid the
        // heap allocation entirely; N is the number of connected peers which is
        // small in practice.
        //
        // Pass 1: count matching channels so we can wrap the position modulo that count.
        // Pass 2: pick the channel at the round-robin index.
        const all = self.chan_mapper.allChannels();
        var match_count: usize = 0;
        for (all) |*c| {
            if (mem.eql(u8, c.connection_name, self.app_name)) continue;
            if (c.containsMethod(method)) match_count += 1;
        }
        if (match_count == 0) return error.ReceiverNotFound;

        // Advance the position by 1 so successive calls rotate to the next peer.
        const pos = self.chan_iterator.position % match_count;
        self.chan_iterator.position = (pos + 1) % match_count;

        var idx: usize = 0;
        for (all) |*c| {
            if (mem.eql(u8, c.connection_name, self.app_name)) continue;
            if (!c.containsMethod(method)) continue;
            if (idx == pos) return try self.allocator.dupe(u8, c.connection_name);
            idx += 1;
        }
        return error.ReceiverNotFound;
    }

    pub fn setClientMethods(self: *Self, methods: []const u8) !void {
        if (self.methods) |m| self.allocator.free(m);
        self.methods = try self.allocator.dupe(u8, methods);
    }

    // ----------------------------- CLIENT HANDLERS -----------------------------

    /// Dispatch a HANDSHAKE message received from the server.
    ///
    /// Two cases are handled differently:
    ///
    /// **Own handshake response** (``transmitter == self.app_name``):
    ///   The router/service acknowledged *this* client's initial connection.
    ///   We do a full rebuild — ``clearAllChannels`` then reconstruct — to get
    ///   a clean, authoritative member list, and then insert the response into
    ///   the message store so the Python side unblocks from ``_process_client_handshake``.
    ///
    /// **Broadcast from another peer joining** (``transmitter != self.app_name``):
    ///   Another client connected and the router broadcast the updated member
    ///   list to every connected peer.  We use an *add-only* update — new
    ///   members are added, existing ones are updated in-place — without calling
    ///   ``clearAllChannels``.  Peers that left are handled separately by the
    ///   "disconnected" EVENT message (see ``onEvent``).
    ///
    ///   Skipping ``clearAllChannels`` is critical for performance: with N
    ///   clients connected, every new connection triggers N broadcast HANDSHAKE
    ///   messages arriving simultaneously at N existing clients.  If each
    ///   client calls ``clearAllChannels`` (freeing N entries) and then rebuilds
    ///   (allocating N new entries), the global C allocator is hit with O(N²)
    ///   concurrent alloc/free operations whose internal mutex serialises them,
    ///   causing each subsequent connection to take proportionally longer
    ///   (client 196 → 3.4 s).  The add-only path avoids all per-entry allocs
    ///   for already-known members, reducing pressure to O(N) total for the new
    ///   entry only.
    pub fn onHandshake(self: *Self, conn: *ParentConnT, message: *Message, consumed: *bool) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const is_own = std.mem.eql(u8, message.getTransmitter(), self.app_name);
        if (is_own) {
            // Full rebuild: clear then reconstruct from the authoritative list.
            // Use the persistent allocator directly so the channel data outlives
            // this stack frame.
            var client_hs = Handshake.fromJson(self.allocator, message.getData()) catch |err| {
                log_client.err("failed to parse own handshake: {s}", .{@errorName(err)});
                return;
            };
            defer client_hs.deinit();
            self.chan_mapper.clearAllChannels();
            for (client_hs.value.members) |mb| {
                var chan = try self.chan_mapper.getOrCreateChannel(conn, mb.name);
                if (mb.methods) |methods| {
                    for (methods) |mt| try chan.addMethod(mt);
                }
            }
            self.storeResponse(message, consumed);
        } else {
            // Add-only broadcast update: parse with an arena to avoid permanent
            // allocations for member strings we will not keep.
            var arena = ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const client_hs = Handshake.fromJson(arena.allocator(), message.getData()) catch |err| {
                log_client.err("failed to parse broadcast handshake: {s}", .{@errorName(err)});
                return;
            };
            for (client_hs.value.members) |mb| {
                const method_count = if (mb.methods) |m| m.len else 0;
                log_client.debug("[{s}] broadcast handshake: member={s} methods={d}", .{ self.app_name, mb.name, method_count });
                var chan = try self.chan_mapper.getOrCreateChannel(conn, mb.name);
                chan.clear();
                if (mb.methods) |methods| {
                    for (methods) |mt| try chan.addMethod(mt);
                }
            }
        }
    }

    /// Add-only update of the chan_mapper from a broadcast HANDSHAKE message.
    /// Used by WASM targets (see wasm.zig); the CFFI path now uses the
    /// broadcast branch inside ``onHandshake`` directly.
    pub fn addMembersFromHandshake(self: *Self, conn: *ParentConnT, message: *Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var arena = ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();
        const client_hs = Handshake.fromJson(alloc, message.getData()) catch |err| {
            log_client.err("failed to parse broadcast handshake: {s}", .{@errorName(err)});
            return;
        };
        for (client_hs.value.members) |mb| {
            var chan = try self.chan_mapper.getOrCreateChannel(conn, mb.name);
            chan.clear();
            if (mb.methods) |methods| {
                for (methods) |mt| try chan.addMethod(mt);
            }
        }
    }

    /// Handle an EVENTS message received from the router.
    ///
    /// **"connected"**: pushed to the task queue so Python ``on_member_added``
    ///   handlers fire.  The mini-HANDSHAKE broadcast (sent just before this EVENT
    ///   over the same TCP connection) already updated chan_mapper via the add-only
    ///   branch in ``onHandshake``, so routing is ready by the time Python wakes up.
    ///
    /// **"disconnected"**: removes the departed member from the Zig chan_mapper
    ///   immediately (so routing stops hitting the dead peer) and then pushes
    ///   the event to the task queue so Python ``on_member_removed`` handlers
    ///   are notified.
    pub fn onEvent(self: *Self, _: *ParentConnT, message: *Message, consumed: *bool) !void {
        var arena = ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const event = Event.fromJson(arena.allocator(), message.getData()) catch return;

        log_client.debug("[{s}] event: type={s} member={s}", .{ self.app_name, event.value.type, event.value.member });

        if (std.mem.eql(u8, event.value.type, "disconnected")) {
            // Must hold client_handler.mutex while mutating chan_mapper so we
            // don't race with findReceiverForMethod / getAvailableMembersClientEntry
            // which iterate allChannels() under the same lock.
            self.mutex.lock();
            self.chan_mapper.destroyChannelByName(event.value.member);
            self.mutex.unlock();
        } else if (std.mem.eql(u8, event.value.type, "evicted") and std.mem.eql(u8, event.value.member, self.app_name)) {
            self.evicted.store(true, .release);
            self.tasks_queue.triggerEviction();
        }

        self.tasks_queue.pushMessageToQueue(message);
        consumed.* = true;
        self.task_pushed = true;
    }

    pub fn onRequest(self: *Self, conn: *ParentConnT, message: *Message, consumed: *bool) !void {
        if (self.tasks_queue.tryPushRequest(message)) {
            consumed.* = true;
            self.task_pushed = true;
            return;
        }
        log_client.warn("[{s}] task queue full ({d} pending), refusing request uuid={d}", .{ self.app_name, TasksQueue.max_pending, message.getUuid() });
        if (message.getReturnResult()) replyError(log_client, self.allocator, conn, message, "ServiceOverloaded", "the worker has too many pending requests");
    }

    pub fn onResponse(self: *Self, _: *ParentConnT, message: *Message, consumed: *bool) !void {
        self.storeResponse(message, consumed);
    }

    // ---------------------- CLIENT CONNECTION LIFECYCLE ------------------------
    fn diconnectionHandler(_: *Self, _: *ParentConnT) !void {}

    fn errorHandler(_: *Self, conn: *ParentConnT, err: anyerror) !void {
        conn.suspended.store(true, .release);
        switch (err) {
            error.EOF => {},
            error.IncompleteMessage => {
                const addr = conn.getAddr();
                log_client.debug("incomplete message from {?}", .{addr});
            },
            else => log_client.debug("failed to receive message: {}", .{err}),
        }
    }
};
