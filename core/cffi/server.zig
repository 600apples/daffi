//! CFFI bindings — server-side functions exposed to the Python dfcore extension.

const py = @import("../python.zig").c;
const PyObject = py.PyObject;
const Py_BuildValue = py.Py_BuildValue;
const PyArg_ParseTuple = py.PyArg_ParseTuple;
const PyErr_SetString = py.PyErr_SetString;

const std = @import("std");
const serde = @import("../serde.zig");
const handlers = @import("../handlers.zig");
const Server = @import("../Server.zig");
const MessageFlag = serde.MessageFlag;
const MessageDecoder = serde.MessageDecoder;
const HandlerMode = handlers.HandlerMode;

const allocator = std.heap.c_allocator;

const ThreadArray = struct {
    buffer: [256]?std.Thread = [_]?std.Thread{null} ** 256,
    len: usize = 0,

    pub fn append(self: *@This(), thread: std.Thread) !void {
        if (self.len >= 256) return error.Overflow;
        self.buffer[self.len] = thread;
        self.len += 1;
    }

    pub fn get(self: *const @This(), idx: usize) std.Thread {
        return self.buffer[idx].?;
    }
};

var serverHandlerThreads: ?ThreadArray = null;

/// Bind to host:port, start the server dispatcher thread, and return a
/// connection handle (conn_num).  mode: 0 = Router, 1 = Service.
/// Returns Python None on failure.
pub fn startServer(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var host: [*:0]u8 = undefined;
    var port: c_long = undefined;
    var mode: c_short = undefined;
    var app_name: [*:0]u8 = undefined;
    var tls_enabled: c_int = 0;
    var cert_file: [*:0]u8 = undefined;
    var key_file: [*:0]u8 = undefined;
    if (!(py.PyArg_ParseTuple(args, "slpspss", &host, &port, &mode, &app_name, &tls_enabled, &cert_file, &key_file) != 0)) return Py_BuildValue("");
    const pmode: HandlerMode = switch (mode) {
        0 => .Router,
        1 => .Service,
        else => unreachable,
    };
    const pport: u16 = @intCast(port);
    const phost = std.mem.span(host);
    const papp_name = std.mem.span(app_name);
    const ptls = tls_enabled != 0;
    const pcert_file = std.mem.span(cert_file);
    const pkey_file = std.mem.span(key_file);
    if (serverHandlerThreads == null) {
        serverHandlerThreads = ThreadArray{};
    }
    const conn_num: usize = @rem(serverHandlerThreads.?.len, 256);
    const cfg = @import("../network/ServerConnection.zig").Config{
        .host = phost, .port = pport, .mode = pmode,
        .tls = ptls, .cert_file = pcert_file, .key_file = pkey_file,
    };
    const handler_thread = std.Thread.spawn(.{}, Server.messageDispatcher, .{ allocator, papp_name, cfg, conn_num }) catch return Py_BuildValue("");
    serverHandlerThreads.?.append(handler_thread) catch return Py_BuildValue("");
    // Block until the dispatcher thread has either finished initialisation
    // (serverReady = true) or failed (serverFailed = true).
    // 100 µs × 100 000 = 10 s maximum wait.
    const sleep_ts = std.c.timespec{ .sec = 0, .nsec = 100_000 };
    var wait_iters: usize = 0;
    while (!Server.isReady(conn_num) and !Server.hasFailed(conn_num) and wait_iters < 100_000) : (wait_iters += 1) {
        _ = std.c.nanosleep(&sleep_ts, null);
    }
    // Signal failure to Python by raising ValueError("ConnectionRefused")
    // so system_exception_handler can catch and enrich the message.
    if (Server.hasFailed(conn_num)) {
        PyErr_SetString(py.PyExc_ValueError, "ConnectionRefused");
        return null;
    }
    return Py_BuildValue("k", @as(c_ulong, conn_num));
}

/// Signal the server identified by conn_num to stop and release all
/// associated native resources.
pub fn stopServer(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "k", &conn_num) != 0)) return Py_BuildValue("");
    Server.destroyHandler(conn_num);
    return Py_BuildValue("");
}

/// Block the calling thread until the server dispatcher thread for conn_num
/// has fully exited.  Call after stopServer().
pub fn joinServer(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "k", &conn_num) != 0)) return Py_BuildValue("");
    serverHandlerThreads.?.get(conn_num).join();
    return Py_BuildValue("");
}

/// Detach the server dispatcher thread for conn_num so it runs independently
/// and its resources are reclaimed automatically when it exits.
/// After detaching, joinServer() must not be called.
pub fn detachServer(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "k", &conn_num) != 0)) return Py_BuildValue("");
    serverHandlerThreads.?.get(conn_num).detach();
    return Py_BuildValue("");
}

/// Enqueue an outbound message on the server connection and return
/// (uuid, timestamp, found_receiver).  Raises ValueError on failure.
pub fn sendMessageFromServer(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var data: *PyObject = undefined;
    var uuid: c_uint = undefined;
    var flag: c_ushort = undefined;
    var decoder: c_ushort = undefined;
    var is_bytes: c_int = undefined;
    var receiver: [*:0]u8 = undefined;
    var func_name: [*:0]u8 = undefined;
    var return_result: c_int = undefined;
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "OIHHpsspk", &data, &uuid, &flag, &decoder, &is_bytes, &receiver, &func_name, &return_result, &conn_num) != 0)) {
        PyErr_SetString(py.PyExc_ValueError, "unable to parse provided arguments");
        return null;
    }

    // #1: skip PyBytes_FromObject when data is already a bytes object.
    var size: i64 = 0;
    var raw_buf: [*c]u8 = undefined;
    var converted: ?*PyObject = null;

    if (py.PyBytes_Check(data) != 0) {
        if (py.PyBytes_AsStringAndSize(data, @ptrCast(&raw_buf), &size) < 0) return null;
    } else {
        converted = py.PyBytes_FromObject(data);
        if (converted == null) { PyErr_SetString(py.PyExc_ValueError, "cannot convert to bytes"); return null; }
        if (py.PyBytes_AsStringAndSize(converted.?, @ptrCast(&raw_buf), &size) < 0) {
            py.Py_DECREF(converted.?);
            return null;
        }
    }
    const pdata = raw_buf[0..@as(usize, @intCast(size))];

    const puuid: u16 = @as(u16, @truncate(uuid));
    const pflag: MessageFlag = @enumFromInt(@as(std.meta.Tag(MessageFlag), @truncate(flag)));
    const pdecoder: MessageDecoder = @enumFromInt(@as(std.meta.Tag(MessageDecoder), @truncate(decoder)));
    const pis_bytes = if (is_bytes == 0) false else true;
    const preceiver = std.mem.span(receiver);
    const pfunc_name = std.mem.span(func_name);
    const preturn_result = if (return_result == 0) false else true;

    // #5: release GIL around the blocking TCP write.
    const py_state = py.PyEval_SaveThread();
    const msgident = Server.sendMessage(pdata, puuid, pflag, pdecoder, pis_bytes, preturn_result, preceiver, pfunc_name, conn_num) catch |err| {
        py.PyEval_RestoreThread(py_state);
        if (converted) |s| py.Py_DECREF(s);
        PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        return null;
    };
    py.PyEval_RestoreThread(py_state);

    if (converted) |s| py.Py_DECREF(s);

    const found_receiver: []const u8 = msgident.receiver;
    return Py_BuildValue("(Iks#)", msgident.uuid, @as(c_long, msgident.timestamp), found_receiver.ptr, found_receiver.len);
}

/// Dequeue one inbound task from the server's incoming message queue.
/// Returns a task tuple on success, or None when the queue is empty
/// (including during startup before the server is fully initialised).
pub fn getMessageForServerWorker(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "k", &conn_num) != 0)) return Py_BuildValue("");
    // Return empty (no message) on any error – e.g. ServerNotInitialized during startup.
    // Never set a Python exception here; the caller polls in a tight loop and treats
    // None as "nothing to process yet".
    var msg = (Server.getMessageForServerWorker(conn_num) catch return Py_BuildValue("")) orelse return Py_BuildValue("");
    defer msg.deinit();
    const uuid: c_uint = @as(c_uint, msg.getUuid());
    const data: []const u8 = msg.getData();
    const flag: c_ushort = @intFromEnum(msg.getFlag());
    const decoder: c_ushort = @intFromEnum(msg.getDecoder());
    const transmitter: []const u8 = msg.getTransmitter();
    const receiver: []const u8 = msg.getReceiver();
    const func_name: []const u8 = msg.getFuncName();
    const return_result: c_ushort = @intFromBool(msg.getReturnResult());
    const template = if (msg.isBytes()) "(Iy#IHs#s#s#H)" else "(Is#IHs#s#s#H)";
    return Py_BuildValue(template, uuid, data.ptr, data.len, flag, decoder, transmitter.ptr, transmitter.len, receiver.ptr, receiver.len, func_name.ptr, func_name.len, return_result);
}

/// Update the set of callback names this service advertises to the router.
/// methods is a comma-separated string, e.g. "add,multiply".
pub fn setServiceMethods(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var methods: [*:0]u8 = undefined;
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "sk", &methods, &conn_num) != 0)) return Py_BuildValue("");
    const pmethods = std.mem.span(methods);
    Server.setServiceMethods(pmethods, conn_num) catch return Py_BuildValue("");
    return Py_BuildValue("");
}

/// Register the fd the native layer signals whenever an incoming request
/// (a call to one of this Service's @callback functions) is pushed onto
/// the task queue.  The TaskDispatcher poller blocks on this fd so it
/// wakes only when real work arrives — no busy-wait or fixed-interval polling.
///
/// setServiceRequestFd(conn_num: int, fd: int) -> None
pub fn setServiceRequestFd(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var fd: c_int = undefined;
    if (!(py.PyArg_ParseTuple(args, "ki", &conn_num, &fd) != 0)) return null;
    Server.setServiceRequestFd(@intCast(conn_num), @intCast(fd));
    return Py_BuildValue("");
}
