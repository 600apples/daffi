//! CFFI bindings — server-side functions exposed to the Python dfcore extension.

const py = @import("python_c");
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

/// Bind every listener at once and return the server's single handle
/// (conn_num).  Accepting starts later, from `beginAccepting`.  `listeners`
/// is a non-empty list of
/// address tuples; a Unix socket is (path, 0).  mode: 0 = Router, 1 = Service.
///
/// Each listener is either `(host, port)` (plaintext),
/// `(host, port, tls, cert, key)`, or
/// `(host, port, tls, cert, key, ca)`.  A non-empty `ca` on a TLS listener
/// enables mutual TLS (clients must present a cert chaining to that CA).
/// `cert` / `key` / `ca` are a filesystem path or PEM material.
///
/// All or nothing: when a listener cannot be bound nothing stays bound, and
/// the ValueError's args are (reason, index of that listener).
pub fn startServer(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var listeners: *PyObject = undefined;
    var mode: c_short = undefined;
    var app_name: [*:0]u8 = undefined;
    if (PyArg_ParseTuple(args, "Ohs", &listeners, &mode, &app_name) == 0) return null;
    // Validate everything that comes from Python: an out-of-range value used to
    // hit `@intCast`/`unreachable`, i.e. abort the whole interpreter.
    const pmode: HandlerMode = switch (mode) {
        0 => .Router,
        1 => .Service,
        else => {
            PyErr_SetString(py.PyExc_ValueError, "invalid server mode");
            return null;
        },
    };
    if (py.PyList_Check(listeners) == 0) {
        PyErr_SetString(py.PyExc_TypeError, "listeners must be a list of address tuples");
        return null;
    }
    const count: usize = @intCast(py.PyList_Size(listeners));
    if (count == 0) {
        PyErr_SetString(py.PyExc_ValueError, "at least one listener is required");
        return null;
    }
    const configs = allocator.alloc(ServerConfig, count) catch return py.PyErr_NoMemory();
    defer allocator.free(configs);
    for (configs, 0..) |*cfg, i| {
        const item = py.PyList_GetItem(listeners, @intCast(i));
        if (py.PyTuple_Check(item) == 0) {
            PyErr_SetString(py.PyExc_TypeError, "listeners must be a list of address tuples");
            return null;
        }
        var host: [*:0]u8 = undefined;
        var port: c_long = undefined;
        var tls_enabled: c_int = 0;
        var cert: [*:0]u8 = undefined;
        var key: [*:0]u8 = undefined;
        var ca: [*:0]u8 = undefined;
        const nitems = py.PyTuple_Size(item);
        if (nitems == 2) {
            if (PyArg_ParseTuple(item, "sl", &host, &port) == 0) return null;
        } else if (nitems == 5) {
            if (PyArg_ParseTuple(item, "slpss", &host, &port, &tls_enabled, &cert, &key) == 0) return null;
        } else if (nitems == 6) {
            if (PyArg_ParseTuple(item, "slpsss", &host, &port, &tls_enabled, &cert, &key, &ca) == 0) return null;
        } else {
            PyErr_SetString(py.PyExc_TypeError, "listener must be (host, port), (host, port, tls, cert, key), or (host, port, tls, cert, key, ca)");
            return null;
        }
        if (port < 0 or port > std.math.maxInt(u16)) {
            raiseListenerError("port must be in range 0-65535", i);
            return null;
        }
        cfg.* = .{
            .host = std.mem.span(host),
            .port = @intCast(port),
            .tls = tls_enabled != 0,
            .cert = if (nitems >= 5) std.mem.span(cert) else "",
            .key = if (nitems >= 5) std.mem.span(key) else "",
            .ca = if (nitems == 6) std.mem.span(ca) else "",
        };
    }

    // Binding (and resolving hosts) may block: release the GIL meanwhile.
    var failed: ?usize = null;
    const py_state = py.PyEval_SaveThread();
    const started = Server.start(allocator, pmode, std.mem.span(app_name), configs, &failed);
    py.PyEval_RestoreThread(py_state);
    const conn_num = started catch |err| {
        if (failed) |i| {
            // system_exception_handler enriches "ConnectionRefused" with the
            // address of listener `i`.
            raiseListenerError(if (err == error.DuplicateListener) "DuplicateListener" else "ConnectionRefused", i);
        } else if (err == error.TooManyServers) {
            PyErr_SetString(py.PyExc_ValueError, "too many servers started in this process (limit 256)");
        } else {
            PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        }
        return null;
    };
    return Py_BuildValue("k", @as(c_ulong, conn_num));
}

const ServerConfig = @import("../network/ServerConnection.zig").Config;

/// Raise ValueError(reason, index) for the listener at `index`.
fn raiseListenerError(reason: [*:0]const u8, index: usize) void {
    const value = Py_BuildValue("(sn)", reason, @as(py.Py_ssize_t, @intCast(index))) orelse return;
    py.PyErr_SetObject(py.PyExc_ValueError, value);
    py.Py_DECREF(value);
}

/// Start accepting on every listener of a server that `startServer` bound.
pub fn beginAccepting(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (PyArg_ParseTuple(args, "k", &conn_num) == 0) return null;
    const py_state = py.PyEval_SaveThread();
    Server.beginAccepting(conn_num) catch |err| {
        py.PyEval_RestoreThread(py_state);
        PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        return null;
    };
    py.PyEval_RestoreThread(py_state);
    return Py_BuildValue("");
}

/// Stop the server identified by conn_num and release every native resource
/// it owns: the listening socket, all accepted connections, their threads and
/// the message pool.  Blocks (with the GIL released) until that is done, so
/// the port can be rebound as soon as this returns.
pub fn stopServer(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "k", &conn_num) != 0)) return Py_BuildValue("");
    const py_state = py.PyEval_SaveThread();
    Server.stop(conn_num);
    py.PyEval_RestoreThread(py_state);
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

    // skip PyBytes_FromObject when data is already a bytes object.
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
    const pflag = std.enums.fromInt(MessageFlag, flag) orelse {
        if (converted) |s| py.Py_DECREF(s);
        PyErr_SetString(py.PyExc_ValueError, "invalid message flag");
        return null;
    };
    const pdecoder = std.enums.fromInt(MessageDecoder, decoder) orelse {
        if (converted) |s| py.Py_DECREF(s);
        PyErr_SetString(py.PyExc_ValueError, "invalid message decoder");
        return null;
    };
    const pis_bytes = if (is_bytes == 0) false else true;
    const preceiver = std.mem.span(receiver);
    const pfunc_name = std.mem.span(func_name);
    const preturn_result = if (return_result == 0) false else true;

    // release GIL around the blocking TCP write.
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
    const flag: c_ushort = @backingInt(msg.getFlag());
    const decoder: c_ushort = @backingInt(msg.getDecoder());
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
