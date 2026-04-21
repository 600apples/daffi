const std = @import("std");
const mem = std.mem;
const fifo = std.fifo;
const net = std.net;
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
const print = misc.print;
const debugPrint = misc.debugPrint;
const Mutex = misc.Mutex;

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

const CommonHandlers = struct {
    pub fn onEmpty(ctx: *anyopaque, message: *Message) !void {
        _ = ctx;
        // return error.NoHandler;
        print("No handler for message: {}\n", .{message.getUuid()});
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
                    self.* = .{ .Service = .{ .allocator = allocator, .chan_mapper = try ChannelsMapperT.init(allocator), .tasks_queue = try TasksQueue.init(allocator), .app_name = app_name } };
                    break :blk self;
                },
                .Router => blk: {
                    self.* = .{ .Router = .{ .allocator = allocator, .chan_mapper = try ChannelsMapperT.init(allocator), .app_name = app_name } };
                    break :blk self;
                },
            };
        }

        pub fn deinit(self: *HandlerUnion) void {
            switch (self) {
                inline else => |e| e.allocator.destroy(e),
            }
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
                                print("failed to send message to {f}: {any}\n", .{ fmtNetAddr(addr), err });
                            } else {
                                print("failed to send message (connection already closed): {any}\n", .{err});
                            }
                        },
                    }
                };
            }

            // ----------------------------- SERVICE HANDLERS -----------------------------
            fn onHandshake(self: *Self, conn: *ParentConnT, message: *Message) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                var arena = ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                var allocator = arena.allocator();
                var client_hs = Handshake.fromJson(allocator, message.getData()) catch |err| {
                    try message.writeErrorMessage("failed to parse handshake message: {s}", .{@errorName(err)});
                    try self.sendToConnection(Message, conn, message);
                    return;
                };
                defer client_hs.deinit();
                // TODO: check password
                const connection_name = try allocator.dupe(u8, message.getTransmitter());
                _ = try self.chan_mapper.getOrCreateChannel(conn, connection_name);
                const methods = self.methods orelse serde.PLACEHOLDER;

                var service_hs = try Handshake.create(allocator, &[_]Handshake.MemberData{.{ .name = self.app_name, .methods = methods }}, null, "service");
                const data = try service_hs.toJson(allocator);
                try message.setData(data);
                for (self.chan_mapper.channels.values()) |c| try self.sendToConnection(Message, c.conn, message);

                // Store event message for service itself.
                const event_message = try serde.createEventMessage(self.allocator, 0, connection_name, "connected");
                try self.tasks_queue.pushMessageToQueue(event_message);
            }

            fn onRequest(self: *Self, _: *ParentConnT, message: *Message) !void {
                // put message to task queue for processing by service worker.
                self.mutex.lock();
                defer self.mutex.unlock();
                message.setDurable();
                try self.tasks_queue.pushMessageToQueue(message);
            }

            // ---------------------- SERVICE CONNECTION LIFECYCLE ------------------------
            fn diconnectionHandler(self: *Self, conn: *ParentConnT) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                var arena = ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                var allocator = arena.allocator();

                const chan = self.chan_mapper.getChannelByConnection(conn) orelse return error.ChannelNotFound;
                const connection_name = try allocator.dupe(u8, chan.connection_name); // for event
                self.chan_mapper.destroyChannel(chan);

                // Store event message for service itself.
                const event_message = try serde.createEventMessage(self.allocator, 0, connection_name, "disconnected");
                try self.tasks_queue.pushMessageToQueue(event_message);
            }

            fn errorHandler(_: *Self, conn: *ParentConnT, err: anyerror) !void {
                switch (err) {
                    error.EOF => {},
                    error.IncompleteMessage => if (comptime @import("builtin").mode == .Debug) {
                        const addr = conn.getAddr();
                        print("incomplete message from {?}\n", .{addr});
                    },
                    else => print("failed to receive message: {}\n", .{err}),
                }
            }
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
                    debugPrint("No channel for receiver: {s}\n", .{receiver});
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
                                print("failed to send message to {f}: {any}\n", .{ fmtNetAddr(addr), err });
                            } else {
                                print("failed to send message (connection already closed): {any}\n", .{err});
                            }
                        },
                    }
                };
            }

            // ----------------------------- ROUTER HANDLERS -----------------------------
            fn onHandshake(self: *Self, conn: *ParentConnT, message: *Message) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                var arena = ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                var allocator = arena.allocator();
                const connection_name = try allocator.dupe(u8, message.getTransmitter()); // for event
                const client_hs = Handshake.fromJson(allocator, message.getData()) catch |err| {
                    try message.writeErrorMessage("failed to parse handshake message: {s}", .{@errorName(err)});
                    try self.sendToConnection(Message, conn, message);
                    return;
                };
                for (client_hs.value.members) |mb| {
                    var chan = try self.chan_mapper.getOrCreateChannel(conn, mb.name);
                    chan.clear();
                    if (mb.methods) |methods| {
                        for (methods) |mt| try chan.addMethod(mt);
                    }
                }
                // Capture allChannels() once so chan_count and the slice are consistent.
                // Holding self.mutex prevents concurrent onHandshake/diconnectionHandler
                // from modifying the ChannelsMapper between the count check and iteration.
                const all_chans = self.chan_mapper.allChannels();
                var memberdata = try allocator.alloc(Handshake.MemberData, all_chans.len);
                for (all_chans, 0..) |*c, idx| {
                    memberdata[idx] = .{ .name = c.connection_name, .methods = try c.joinedMethods(allocator, serde.UNIT_SEPARATOR) };
                }
                var router_hs = try Handshake.create(allocator, memberdata, null, "router");
                const data = try router_hs.toJson(allocator);
                try message.setData(data);
                for (self.chan_mapper.channels.values()) |c| try self.sendToConnection(Message, c.conn, message);

                // Event for all channels.
                var event_message = try serde.createEventMessage(self.allocator, 0, connection_name, "connected");
                defer event_message.deinit();
                for (self.chan_mapper.channels.values()) |c| {
                    // Send event to all channels except connected.
                    if (!std.mem.eql(u8, connection_name, c.connection_name)) try self.sendToConnection(Message, c.conn, event_message);
                }
            }

            fn onRequest(self: *Self, _: *ParentConnT, message: *Message) !void {
                if (self.findChannel(message.getFuncName(), message.getReceiver())) |c| try self.sendToConnection(Message, c.conn, message) else debugPrint("No route for request to: {s}\n", .{message.getReceiver()});
            }

            fn onResponse(self: *Self, _: *ParentConnT, message: *Message) !void {
                if (self.findChannel(null, message.getReceiver())) |*c| try self.sendToConnection(Message, c.conn, message) else debugPrint("No route for response to: {s}\n", .{message.getReceiver()});
            }

            // --------------------- ROUTER CONNECTION LIFECYCLE ----------------------
            fn diconnectionHandler(self: *Self, conn: *ParentConnT) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                var arena = ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                var allocator = arena.allocator();

                const chan = self.chan_mapper.getChannelByConnection(conn) orelse return error.ChannelNotFound;
                const connection_name = try allocator.dupe(u8, chan.connection_name); // for event
                self.chan_mapper.destroyChannel(chan);
                // Capture allChannels() once after the removal so count and slice are consistent.
                const all_chans = self.chan_mapper.allChannels();
                var memberdata = try allocator.alloc(Handshake.MemberData, all_chans.len);
                for (all_chans, 0..) |*c, idx| {
                    memberdata[idx] = .{ .name = c.connection_name, .methods = try c.joinedMethods(allocator, serde.UNIT_SEPARATOR) };
                }
                var handshake_message = try serde.createHandshakeMessage(self.allocator, memberdata, 0, null, "router");
                defer handshake_message.deinit();
                for (self.chan_mapper.channels.values()) |c| try self.sendToConnection(Message, c.conn, handshake_message);

                // Event for all channels.
                var event_message = try serde.createEventMessage(self.allocator, 0, connection_name, "disconnected");
                defer event_message.deinit();
                for (self.chan_mapper.channels.values()) |c| try self.sendToConnection(Message, c.conn, event_message);
            }

            fn errorHandler(_: *Self, conn: *ParentConnT, err: anyerror) !void {
                switch (err) {
                    error.EOF => {},
                    error.IncompleteMessage => if (comptime @import("builtin").mode == .Debug) {
                        const addr = conn.getAddr();
                        print("incomplete message from {?}\n", .{addr});
                    },
                    else => print("failed to receive message: {}\n", .{err}),
                }
            }
        };
    };
}

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

    const Self = @This();
    pub const ParentConnT = Connection(.ClientConnectionType);
    const MessageHandlerT = MessageHandler(Self);
    const ChannelsMapperT = ChannelsMapper(ParentConnT);

    pub fn init(allocator: Allocator, app_name: []const u8) !*ClientHandler {
        const self = try allocator.create(ClientHandler);
        self.* = .{ .chan_mapper = try ChannelsMapperT.init(allocator), .tasks_queue = try TasksQueue.init(allocator), .allocator = allocator, .msg_store = ClientMessageStore{ .allocator = allocator }, .app_name = try allocator.dupe(u8, app_name) };
        return self;
    }

    pub fn deinit(self: *ClientHandler) void {
        self.allocator.free(self.app_name);
        self.allocator.destroy(self);
    }

    fn wakeupFn(self: *Self) void {
        self.tasks_queue.triggerWakeup();
    }

    pub fn handler(self: *const Self) MessageHandlerT {
        return .{
            .ptr = @constCast(self),
            .handlers_mapping = MessageHandlerT.createMapping(.{ .HANDSHAKE = onHandshake, .REQUEST = onRequest, .EVENTS = onRequest, .RESPONSE = onResponse, .ERROR = onResponse }),
            .error_handler = errorHandler,
            .disconnection_handler = diconnectionHandler,
            .wakeup_fn = wakeupFn,
        };
    }

    pub fn findReceiverForMethod(self: *Self, method: []const u8, receiver: ?[]const u8) ![]const u8 {
        if (receiver) |rec| {
            if (mem.eql(u8, rec, self.app_name)) return error.ReceiverNotFound;
            var chan = self.chan_mapper.getChannel(rec) catch {
                debugPrint("No channel for receiver: {s}\n", .{rec});
                return error.ReceiverNotFound;
            };
            if (chan.containsMethod(method)) return chan.connection_name;
        } else {
            var found_channels = std.array_list.Managed(ChannelsMapperT.Channel).init(self.allocator);
            self.mutex.lock();
            defer {
                self.mutex.unlock();
                found_channels.deinit();
                self.chan_iterator.reset();
            }
            for (self.chan_mapper.allChannels()) |*c| {
                if (mem.eql(u8, c.connection_name, self.app_name)) continue;
                if (c.containsMethod(method)) try found_channels.append(c.*);
            }
            if (self.chan_iterator.next(found_channels.items)) |*c| return c.connection_name;
        }
        return error.ReceiverNotFound;
    }

    pub fn setClientMethods(self: *Self, methods: []const u8) !void {
        if (self.methods) |m| self.allocator.free(m);
        self.methods = try self.allocator.dupe(u8, methods);
    }

    // ----------------------------- CLIENT HANDLERS -----------------------------

    /// Full (re)build of the local chan_mapper from a HANDSHAKE response.
    /// Used for the client's *own* handshake response (transmitter == app_name)
    /// so the initial authoritative member list is applied cleanly.
    pub fn onHandshake(self: *Self, conn: *ParentConnT, message: *Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var client_hs = Handshake.fromJson(self.allocator, message.getData()) catch |err| {
            print("failed to parse handshake message: {s}", .{@errorName(err)});
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
        if (std.mem.eql(u8, message.getTransmitter(), self.app_name)) {
            // Notify client worker about handshake completion.
            message.setDurable();
            try self.msg_store.insert(message);
        }
    }

    /// Add-only update of the chan_mapper from a broadcast HANDSHAKE message.
    /// Unlike onHandshake this does NOT call clearAllChannels, so a stale
    /// broadcast arriving out-of-order cannot wipe out members that a fresher
    /// broadcast already added.  Existing channels that are absent from the
    /// broadcast are left untouched; they are removed when a "disconnected"
    /// event arrives via onEvent.
    pub fn addMembersFromHandshake(self: *Self, conn: *ParentConnT, message: *Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var arena = ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();
        const client_hs = Handshake.fromJson(alloc, message.getData()) catch |err| {
            print("failed to parse broadcast handshake: {s}", .{@errorName(err)});
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

    /// Remove a disconnected member from the local chan_mapper when a
    /// "disconnected" event arrives from the router.
    pub fn onEvent(self: *Self, _: *ParentConnT, message: *Message) !void {
        var arena = ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const event = Event.fromJson(arena.allocator(), message.getData()) catch return;
        if (std.mem.eql(u8, event.value.type, "disconnected")) {
            self.chan_mapper.destroyChannelByName(event.value.member);
        }
    }

    pub fn onRequest(self: *Self, _: *ParentConnT, message: *Message) !void {
        // put message to message queue for processing by client worker.
        message.setDurable();
        try self.tasks_queue.pushMessageToQueue(message);
    }

    pub fn onResponse(self: *Self, _: *ParentConnT, message: *Message) !void {
        // put message to client store for taking result by client.
        message.setDurable();
        try self.msg_store.insert(message);
    }

    // ---------------------- CLIENT CONNECTION LIFECYCLE ------------------------
    fn diconnectionHandler(_: *Self, _: *ParentConnT) !void {}

    fn errorHandler(_: *Self, conn: *ParentConnT, err: anyerror) !void {
        conn.suspended = true;
        switch (err) {
            error.EOF => {},
            error.IncompleteMessage => if (comptime @import("builtin").mode == .Debug) {
                const addr = conn.getAddr();
                print("incomplete message from {?}\n", .{addr});
            },
            else => print("failed to receive message: {}\n", .{err}),
        }
    }
};
