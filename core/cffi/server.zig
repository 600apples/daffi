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
const client = @import("client.zig");
const MessageFlag = serde.MessageFlag;
const MessageDecoder = serde.MessageDecoder;
const HandlerMode = handlers.HandlerMode;

const allocator = std.heap.c_allocator;

/// Bind every listener at once and return the server's single handle
/// (conn_num).  Nothing accepts yet; `startServer` does that.  `listeners`
/// is a non-empty list of
/// address tuples; a Unix socket is (path, 0).  mode: 0 = Router, 1 = Service.
///
/// Each listener is either `(host, port)` (plaintext),
/// `(host, port, tls, cert, key)`, or
/// `(host, port, tls, cert, key, ca)`, or
/// `(host, port, tls, cert, key, ca, allowed_origins)`.  A non-empty `ca` on
/// a TLS listener enables mutual TLS (clients must present a cert chaining to
/// that CA).  `allowed_origins` is a newline-separated list of the origins a
/// WebSocket upgrade may come from; empty allows any.
/// `cert` / `key` / `ca` are a filesystem path or PEM material.
///
/// All or nothing: when a listener cannot be bound nothing stays bound, and
/// the ValueError's args are (reason, index of that listener).
pub fn addListeners(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var listeners: *PyObject = undefined;
    var mode: c_short = undefined;
    var app_name: [*:0]u8 = undefined;
    var auth_token: ?[*:0]u8 = null;
    if (PyArg_ParseTuple(args, "Ohs|z", &listeners, &mode, &app_name, &auth_token) == 0) return null;
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
        var origins: [*:0]u8 = undefined;
        const nitems = py.PyTuple_Size(item);
        if (nitems == 2) {
            if (PyArg_ParseTuple(item, "sl", &host, &port) == 0) return null;
        } else if (nitems == 5) {
            if (PyArg_ParseTuple(item, "slpss", &host, &port, &tls_enabled, &cert, &key) == 0) return null;
        } else if (nitems == 6) {
            if (PyArg_ParseTuple(item, "slpsss", &host, &port, &tls_enabled, &cert, &key, &ca) == 0) return null;
        } else if (nitems == 7) {
            if (PyArg_ParseTuple(item, "slpssss", &host, &port, &tls_enabled, &cert, &key, &ca, &origins) == 0) return null;
        } else {
            PyErr_SetString(py.PyExc_TypeError, "listener must be (host, port), (host, port, tls, cert, key), (host, port, tls, cert, key, ca), or (host, port, tls, cert, key, ca, allowed_origins)");
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
            .ca = if (nitems >= 6) std.mem.span(ca) else "",
            .allowed_origins = if (nitems == 7) std.mem.span(origins) else "",
        };
    }

    // Binding (and resolving hosts) may block: release the GIL meanwhile.
    var failed: ?usize = null;
    const py_state = py.PyEval_SaveThread();
    const started = Server.start(allocator, pmode, std.mem.span(app_name), configs, &failed, if (auth_token) |t| std.mem.span(t) else null);
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

/// Start accepting on every listener of a server that `addListeners` bound.
pub fn startServer(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
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
    var conn_num: c_ulong = undefined;
    if (PyArg_ParseTuple(args, "k", &conn_num) == 0) return null;
    const py_state = py.PyEval_SaveThread();
    Server.stop(conn_num);
    py.PyEval_RestoreThread(py_state);
    return Py_BuildValue("");
}

/// Send a message on the server connection and return
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
    var conn_num: c_ulong = undefined;
    if (PyArg_ParseTuple(args, "OIHHpsspk", &data, &uuid, &flag, &decoder, &is_bytes, &receiver, &func_name, &return_result, &conn_num) == 0) return null;

    var payload = client.bytesOf(data) orelse return null;
    defer payload.deinit();

    const pflag = std.enums.fromInt(MessageFlag, flag) orelse {
        PyErr_SetString(py.PyExc_ValueError, "invalid message flag");
        return null;
    };
    const pdecoder = std.enums.fromInt(MessageDecoder, decoder) orelse {
        PyErr_SetString(py.PyExc_ValueError, "invalid message decoder");
        return null;
    };

    // The write may block on a full socket buffer.  `data` and the argument
    // strings stay alive because `args` holds them.
    const py_state = py.PyEval_SaveThread();
    const result = Server.sendMessage(payload.slice, @truncate(uuid), pflag, pdecoder, is_bytes != 0, return_result != 0, std.mem.span(receiver), std.mem.span(func_name), conn_num);
    py.PyEval_RestoreThread(py_state);
    const msgident = result catch |err| {
        PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        return null;
    };
    return Py_BuildValue("(Ils#)", @as(c_uint, msgident.uuid), @as(c_long, msgident.timestamp), msgident.receiver.ptr, @as(py.Py_ssize_t, @intCast(msgident.receiver.len)));
}

/// Dequeue one inbound task from the server's incoming message queue.
/// Returns a task tuple, or None when the queue is empty or the handle is gone.
pub fn getMessageForServerWorker(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    if (PyArg_ParseTuple(args, "k", &conn_num) == 0) return null;
    const msg = (Server.getMessageForServerWorker(conn_num) catch return Py_BuildValue("")) orelse return Py_BuildValue("");
    return client.taskTuple(msg);
}

/// Update the set of callback names this service advertises to the router.
/// methods is a comma-separated string, e.g. "add,multiply".
pub fn setServiceMethods(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var methods: [*:0]u8 = undefined;
    var conn_num: c_ulong = undefined;
    if (PyArg_ParseTuple(args, "sk", &methods, &conn_num) == 0) return null;
    Server.setServiceMethods(std.mem.span(methods), conn_num) catch |err| {
        PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        return null;
    };
    return Py_BuildValue("");
}

/// Install (or with -1, withdraw) the descriptor the native layer signals
/// when a request for one of this Service's callbacks is queued.  A stopped
/// server is not an error.
///
/// setServiceRequestFd(conn_num: int, fd: int) -> None
pub fn setServiceRequestFd(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var fd: c_int = undefined;
    if (PyArg_ParseTuple(args, "ki", &conn_num, &fd) == 0) return null;
    Server.setServiceRequestFd(conn_num, fd) catch {};
    return Py_BuildValue("");
}
