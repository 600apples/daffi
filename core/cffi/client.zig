//! CFFI bindings — client-side functions exposed to the Python dfcore extension.

const py = @import("../python.zig").c;
const PyObject = py.PyObject;
const Py_BuildValue = py.Py_BuildValue;
const PyArg_ParseTuple = py.PyArg_ParseTuple;
const PyErr_SetString = py.PyErr_SetString;

const std = @import("std");
const serde = @import("../serde.zig");
const handlers = @import("../handlers.zig");
const MessageFlag = serde.MessageFlag;
const MessageDecoder = serde.MessageDecoder;
const Client = @import("../Client.zig");
const HandlerMode = handlers.HandlerMode;

const allocator = std.heap.c_allocator;

/// Open a TCP connection to host:port and return a connection handle (conn_num).
/// Returns the Python None object on failure.
pub fn startClient(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var host: [*:0]u8 = undefined;
    var port: c_long = undefined;
    var app_name: [*:0]u8 = undefined;
    var tls_enabled: c_int = 0;
    var ca_file: [*:0]u8 = undefined;
    if (!(py.PyArg_ParseTuple(args, "slsps", &host, &port, &app_name, &tls_enabled, &ca_file) != 0)) return Py_BuildValue("");
    const pport: u16 = @intCast(port);
    const phost = std.mem.span(host);
    const papp_name = std.mem.span(app_name);
    const ptls = tls_enabled != 0;
    const pca_file = std.mem.span(ca_file);
    const conn_num = Client.init(allocator, papp_name, .{
        .host = phost, .port = pport,
        .tls = ptls, .ca_file = pca_file,
    }) catch return Py_BuildValue("");
    return Py_BuildValue("k", @as(c_ulong, conn_num));
}

/// Close the connection identified by conn_num and free all associated resources.
pub fn stopClient(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "k", &conn_num) != 0)) return Py_BuildValue("");
    Client.desctroyClient(conn_num) catch return Py_BuildValue("");
    return Py_BuildValue("");
}

/// Enqueue an outbound message on the client connection and return
/// (uuid, timestamp, found_receiver).  Raises ValueError on failure.
pub fn sendMessageFromClient(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
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

    // release the GIL around the blocking TCP write so other Python
    // threads can run while this one waits for the socket buffer to drain.
    // No Python API calls are made between SaveThread and RestoreThread.
    const py_state = py.PyEval_SaveThread();
    const msgident = Client.sendMessage(pdata, puuid, pflag, pdecoder, pis_bytes, preturn_result, preceiver, pfunc_name, conn_num) catch |err| {
        py.PyEval_RestoreThread(py_state);
        if (converted) |s| py.Py_DECREF(s);
        PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        return null;
    };
    py.PyEval_RestoreThread(py_state);

    // data has been copied into Zig-owned memory; safe to DECREF now.
    if (converted) |s| py.Py_DECREF(s);

    const found_receiver: []const u8 = msgident.receiver;
    // For REQUEST flags ``found_receiver`` is a caller-owned duplicate
    // produced by ``findReceiverForMethod`` while the appropriate mutex was
    // still held — see the comment on that function for why a borrowed slice
    // into chan_mapper storage was a use-after-free that surfaced as random
    // UTF-8 decode errors under concurrency.  Other flag values never go
    // through the resolver and must not be freed.  ``Py_BuildValue("s#")``
    // copies the bytes into a fresh Python ``str`` so freeing after the call
    // is safe.
    defer if (pflag == .REQUEST) allocator.free(found_receiver);
    return Py_BuildValue("(Iks#)", msgident.uuid, @as(c_long, msgident.timestamp), found_receiver.ptr, found_receiver.len);
}

/// Send the initial client handshake advertising exported method names.
/// Returns (uuid, timestamp, found_receiver).  Raises ValueError on failure.
pub fn sendHandshakeFromClient(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var methods: [*:0]u8 = undefined;
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "sk", &methods, &conn_num) != 0)) {
        PyErr_SetString(py.PyExc_ValueError, "unable to parse provided arguments");
        return null;
    }
    const pmethods = std.mem.span(methods);
    const msgident = Client.sendHandshake(conn_num, pmethods) catch |err| {
        PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        return null;
    };
    const found_receiver: []const u8 = msgident.receiver;
    return Py_BuildValue("(Iks#)", msgident.uuid, @as(c_long, msgident.timestamp), found_receiver.ptr, found_receiver.len);
}

/// Poll the client message store for a response to uuid.
/// Returns (data, flag, serde) when ready, or None if not yet available.
pub fn getMessageFromClientStore(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var uuid: c_uint = undefined;
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "Ik", &uuid, &conn_num) != 0)) return Py_BuildValue("");
    const msg = (Client.getMessageByUuid(@as(u16, @truncate(uuid)), conn_num) catch |err| {
        const err_name = @errorName(err)[0..];
        return Py_BuildValue("(s#)", err_name.ptr, err_name.len);
    }) orelse return Py_BuildValue("");
    defer msg.deinit();
    const data: []const u8 = msg.getData();
    const flag: c_ushort = @intFromEnum(msg.getFlag());
    const decoder: c_ushort = @intFromEnum(msg.getDecoder());
    const template = if (msg.isBytes()) "(y#IH)" else "(s#IH)";
    return Py_BuildValue(template, data.ptr, data.len, flag, decoder);
}

/// Mark the pending message identified by uuid as timed-out so its slot
/// can be reclaimed by the native layer.
pub fn setTimeoutError(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var uuid: c_uint = undefined;
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "Ik", &uuid, &conn_num) != 0)) return Py_BuildValue("");
    Client.setTimeoutError(@as(u16, @truncate(uuid)), conn_num) catch return Py_BuildValue("");
    return Py_BuildValue("");
}

/// Dequeue one inbound task from the client's incoming message queue.
/// Returns a task tuple on success or None when the queue is empty.
pub fn getMessageForClientWorker(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "k", &conn_num) != 0)) return Py_BuildValue("");
    var msg = (Client.getMessageForClientWorker(conn_num) catch return Py_BuildValue("")) orelse return Py_BuildValue("");
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

/// Register the eventfd (or pipe write-end) that the native layer signals
/// whenever a new task-queue message is available for the client at conn_num.
/// Used by client connections that act as workers in a router topology.
///
/// setClientRequestFd(conn_num: int, fd: int) -> None
pub fn setClientRequestFd(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var fd: c_int = undefined;
    if (!(py.PyArg_ParseTuple(args, "ki", &conn_num, &fd) != 0)) return null;
    Client.setRequestFd(@intCast(conn_num), @intCast(fd)) catch return Py_BuildValue("");
    return Py_BuildValue("");
}

/// Register the pipe write-end that the native layer writes to once when the
/// connection is lost (EOF / network error).  The Python task dispatcher
/// selects on the corresponding read end so it can react immediately without
/// a dedicated polling thread.
///
/// setLifecycleFd(conn_num: int, fd: int) -> None
pub fn setLifecycleFd(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var fd: c_int = undefined;
    if (!(py.PyArg_ParseTuple(args, "ki", &conn_num, &fd) != 0)) return null;
    Client.setLifecycleFd(@intCast(conn_num), @intCast(fd)) catch return Py_BuildValue("");
    return Py_BuildValue("");
}

/// Register the eventfd (or pipe write-end) that the native layer signals
/// whenever a new response message is inserted into the client message
/// store.  Python's RpcResult waiters block on the corresponding read end
/// (with a select-based deadline) instead of polling the store.
///
/// setResponseFd(conn_num: int, fd: int) -> None
pub fn setResponseFd(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var fd: c_int = undefined;
    if (!(py.PyArg_ParseTuple(args, "ki", &conn_num, &fd) != 0)) return null;
    Client.setResponseFd(@intCast(conn_num), @intCast(fd)) catch return Py_BuildValue("");
    return Py_BuildValue("");
}

/// Set the native Zig log level at runtime.
///
/// level values: 0=DEBUG  1=INFO  2=WARNING  3=ERROR  4=OFF (default, silent)
///
/// setLogLevel(level: int) -> None
pub fn setLogLevel(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var level: c_int = 4;
    if (!(py.PyArg_ParseTuple(args, "i", &level) != 0)) return Py_BuildValue("");
    const clamped: u32 = @intCast(@max(0, @min(4, level)));
    @import("../log.zig").setLevel(clamped);
    return Py_BuildValue("");
}

/// Return a JSON-encoded list of currently connected nodes, or None on error.
pub fn getAvailableMembers(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: usize = undefined;
    if (!(py.PyArg_ParseTuple(args, "k", &conn_num) != 0)) return Py_BuildValue("");
    // getAvailableMembers returns allocator-owned memory (always).  We must
    // free it after Py_BuildValue has copied it into a Python string object.
    const members = Client.getAvailableMembers(allocator, conn_num) catch return Py_BuildValue("");
    defer allocator.free(members);
    return Py_BuildValue("s#", members.ptr, members.len);
}
