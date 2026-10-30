const std = @import("std");
const Client = @import("./Client.zig");
const builtin = std.builtin;
const ArenaAllocator = std.heap.ArenaAllocator;
const allocator = std.heap.wasm_allocator;
const MessageDecoder = @import("serde.zig").MessageDecoder;

// Override std.log so that std.log.* calls anywhere in the wasm compilation
// unit resolve to this no-op instead of defaultLog, which pulls in
// std.Io.Threaded / std.posix — unavailable on wasm32-freestanding.
pub const std_options: std.Options = .{
    .logFn = wasmLogFn,
};

fn wasmLogFn(
    comptime _: std.log.Level,
    comptime _: @EnumLiteral(),
    comptime _: []const u8,
    _: anytype,
) void {}

pub const os = struct {
    pub const system = struct {
        pub const fd_t = u8;
        pub const STDERR_FILENO = 1;
        pub const E = std.os.linux.E;

        pub const sockaddr = extern union {
            pub const in = u8;
            pub const in6 = u8;
        };

        pub fn getErrno(T: usize) E {
            _ = T;
            return .SUCCESS;
        }

        pub fn write(f: fd_t, ptr: [*]const u8, len: usize) usize {
            _ = ptr;
            _ = f;
            return len;
        }
    };
};

extern "env" fn _throwError(pointer: [*]const u8, length: u32) noreturn;
extern "env" fn _consoleLog(pointer: [*]const u8, length: u32) void;
extern "window" fn _sendToSocket(data_ptr: [*]const u8, data_len: u32) void;
/// decoder mirrors MessageDecoder: 0=OPAQUE, 1=JSON, 2=PICKLE, 3=MSGPACK.
/// The JS side uses this to choose the right deserialiser for the payload.
/// Passing it as a 5th argument is backward-compatible: older JS handlers
/// that only declare 4 parameters will simply ignore the extra value.
extern "window" fn _storeMessage(data_ptr: [*]const u8, data_len: u32, uuid: u32, is_error: bool, decoder: u32) void;
extern "window" fn _triggerEvent(data_ptr: [*]const u8, data_len: u32) void;

pub fn throwError(message: []const u8) noreturn {
    _throwError(message.ptr, message.len);
}

pub fn consoleLog(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(allocator, fmt, args) catch
        @panic("failed to allocate memory for consoleLog message");
    defer allocator.free(msg);
    _consoleLog(msg.ptr, msg.len);
}

// Calls to @panic are sent here.
// See https://ziglang.org/documentation/master/#panic
pub fn panic(message: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    throwError(message);
}

// Every buffer crosses the boundary with its length: payloads may contain
// NUL bytes, and the allocator must be given back the size it handed out.

export fn allocUint8(length: u32) [*]u8 {
    const slice = allocator.alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

/// Free `length` bytes at `pointer`, as returned by `allocUint8` (or, for
/// `getAvailableMembers`, its length plus the terminating NUL).
export fn free(pointer: [*]u8, length: u32) void {
    allocator.free(pointer[0..length]);
}

const send_result_len = 4;

/// Free what `sendMessage` returned: the receiver name and the result itself.
export fn freeSendResult(result: [*]usize) void {
    const receiver: [*]u8 = @ptrFromInt(result[2]);
    allocator.free(receiver[0..result[1]]);
    allocator.free(result[0..send_result_len]);
}

export fn sendHandshake(conn_num: usize) u32 {
    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const methods = ""; // Empty for now. Maybe in the future we will have some methods to be executed in browser.
    const ident = Client.createHandshake(arena_allocator, methods, conn_num) catch throwError("failed to create message\n");
    _sendToSocket(ident.data.ptr, ident.data.len);
    return ident.message.uuid;
}

/// Takes ownership of the three input buffers.  Returns
/// `[uuid, receiver_len, receiver_ptr, is_json]`; release it with
/// `freeSendResult`.
export fn sendMessage(data: [*]u8, data_len: u32, receiver: [*]u8, receiver_len: u32, func_name: [*]u8, func_name_len: u32, serde: u32, return_result: bool, conn_num: usize) [*]const usize {
    const actual_data = data[0..data_len];
    const actual_receiver = receiver[0..receiver_len];
    const actual_func_name = func_name[0..func_name_len];
    const decoder = std.enums.fromInt(MessageDecoder, serde) orelse throwError("invalid serde\n");
    const is_bytes = switch (decoder) {
        .JSON => false,
        .OPAQUE, .PICKLE, .MSGPACK => true,
    };
    defer {
        allocator.free(actual_data);
        allocator.free(actual_receiver);
        allocator.free(actual_func_name);
    }
    const ident = Client.createMessage(allocator, actual_data, 0, .REQUEST, decoder, is_bytes, return_result, actual_receiver, actual_func_name, conn_num) catch |err| {
        const available_receivers = Client.getAvailableMembers(allocator, conn_num) catch throwError("failed to get available receivers\n");
        var iterator = std.mem.splitSequence(u8, available_receivers, "members");
        _ = iterator.next();
        const members = iterator.next() orelse throwError("failed to get members\n");
        // consoleLog("failed to create message: {any} for method '{s}'.\nAvailable receivers {s}\n", .{ err, actual_func_name, available_receivers });
        var buf: [1000]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "failed to create message: {any} for method '{s}'.\nAvailable receivers {s}\n", .{ err, actual_func_name, std.mem.trim(u8, members, ":}") }) catch
            "failed to create message (and the details do not fit)\n";
        throwError(text);
    };
    defer allocator.free(ident.data);
    const result = allocator.alloc(usize, send_result_len) catch @panic("failed to allocate memory for result");
    _sendToSocket(ident.data.ptr, ident.data.len);
    result[0] = ident.message.uuid;
    result[1] = ident.message.receiver.len;
    result[2] = @intFromPtr(ident.message.receiver.ptr);
    result[3] = @intFromBool(!is_bytes);
    return result.ptr;
}

/// Return a null-terminated JSON string describing all connected members and
/// their registered methods.  Format: {"meta":{...},"members":[{"name":...,"methods":[...]},...]}
/// The caller must pass the returned pointer, and its length plus one, to
/// free() when done.
export fn getAvailableMembers(conn_num: usize) [*:0]const u8 {
    const json = Client.getAvailableMembers(allocator, conn_num) catch throwError("failed to get available members\n");
    defer allocator.free(json);
    return (allocator.dupeSentinel(u8, json, 0) catch @panic("OOM")).ptr;
}

/// Takes ownership of `data`.
export fn parseAndStoreMessage(data: [*]u8, len: u32, conn_num: u32) void {
    const actual_data = data[0..len];
    defer allocator.free(actual_data);
    var entry = Client.acquireClientEntry(conn_num) catch throwError("failed to get client entry\n");
    defer entry.release();
    var client_handler = entry.client_handler;
    const connection = entry.connection;
    var msg = entry.msgpool.buildWsMessage(actual_data) catch throwError("failed to build framed message\n");
    // The handlers below may take ownership of `msg` (they set `consumed`) by
    // parking it in the client's message store / task queue.  Freeing it here as
    // well, as an unconditional `defer msg.deinit()` did, left a dangling
    // pointer in that container and a double free when it was torn down.
    var owned = true;
    defer if (owned) msg.deinit();
    const uuid = msg.getUuid();
    const payload = msg.getData();
    switch (msg.getFlag()) {
        .HANDSHAKE => {
            const is_own = std.mem.eql(u8, msg.getTransmitter(), client_handler.app_name);
            if (is_own) {
                // Own handshake response: clear + full rebuild, then resolve the JS promise.
                var consumed = false;
                client_handler.onHandshake(connection, msg, &consumed) catch |err| {
                    consoleLog("failed to handle own handshake: {any}\n", .{err});
                    throwError("failed to handle own handshake\n");
                };
                _storeMessage(payload.ptr, payload.len, uuid, false, @backingInt(msg.getDecoder()));
                if (consumed) {
                    // JS has its copy of the payload now; reclaim the store's.
                    owned = false;
                    if (client_handler.msg_store.fetch(uuid)) |stored| stored.deinit();
                }
            } else {
                // Broadcast from another worker's reconnect: add-only so a stale
                // broadcast arriving out-of-order cannot wipe out freshly added members.
                client_handler.addMembersFromHandshake(connection, msg) catch |err| {
                    consoleLog("failed to merge handshake broadcast: {any}\n", .{err});
                };
            }
        },
        .RESPONSE => _storeMessage(payload.ptr, payload.len, uuid, false, @backingInt(msg.getDecoder())),
        .ERROR => _storeMessage(payload.ptr, payload.len, uuid, true, @backingInt(msg.getDecoder())),
        .EVENTS => {
            // Update local chan_mapper before notifying JS event handlers so
            // that any RPC triggered from within an event handler sees the
            // correct (already-updated) member list.
            var consumed = false;
            client_handler.onEvent(connection, msg, &consumed) catch {};
            _triggerEvent(payload.ptr, payload.len);
            if (consumed) {
                // onEvent queued it for Python; nothing consumes that queue in
                // wasm, so take it back out and free it.
                owned = false;
                if (client_handler.tasks_queue.getMessageFromQueue()) |queued| queued.deinit();
            }
        },
        // REQUEST (and anything else) is not meaningful to a browser client.
        else => {},
    }
}

/// Takes ownership of the name and token buffers.  A zero `token_len` means
/// no `auth_token` (the token pointer is then not freed).
export fn initClient(data: [*]u8, len: u32, token: [*]u8, token_len: u32) usize {
    const app_name = data[0..len];
    defer allocator.free(app_name);
    const auth_token: ?[]u8 = if (token_len > 0) token[0..token_len] else null;
    defer if (auth_token) |t| allocator.free(t);
    return Client.init(allocator, app_name, .{}, auth_token) catch throwError("failed to initialize client\n");
}

/// Release the client slot allocated by initClient.  Must be called on
/// reconnect so that old slots do not accumulate in the 512-entry table.
export fn stopClient(conn_num: usize) void {
    Client.destroyClient(conn_num) catch {};
}
