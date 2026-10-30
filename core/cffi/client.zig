//! CFFI bindings — client-side functions exposed to the Python dfcore extension.

const py = @import("python_c");
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
const net = @import("../network/posix_net.zig");
const HandlerMode = handlers.HandlerMode;

const allocator = std.heap.c_allocator;

/// Open a TCP connection to host:port and return a connection handle (conn_num).
/// On failure sets OSError to the Zig error name plus the OS reason, when one
/// was recorded, and returns null.
pub fn startClient(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var host: [*:0]u8 = undefined;
    var port: c_long = undefined;
    var app_name: [*:0]u8 = undefined;
    var tls_enabled: c_int = 0;
    var ca: [*:0]u8 = undefined;
    var cert: [*:0]u8 = undefined;
    var key: [*:0]u8 = undefined;
    var verify: c_int = 1;
    var auth_token: ?[*:0]u8 = null;
    if (py.PyArg_ParseTuple(args, "slspsss|pz", &host, &port, &app_name, &tls_enabled, &ca, &cert, &key, &verify, &auth_token) == 0) return null;
    if (port < 0 or port > std.math.maxInt(u16)) {
        PyErr_SetString(py.PyExc_ValueError, "port must be in range 0-65535");
        return null;
    }
    const config: @import("../network.zig").Connection(.ClientConnectionType).Config = .{
        .host = std.mem.span(host),
        .port = @intCast(port),
        .tls = tls_enabled != 0,
        .ca = std.mem.span(ca),
        .cert = std.mem.span(cert),
        .key = std.mem.span(key),
        .verify = verify != 0,
    };
    // Connecting (and a TLS handshake) can take seconds; the argument
    // strings stay alive because `args` holds them.
    const py_state = py.PyEval_SaveThread();
    const result = Client.init(allocator, std.mem.span(app_name), config, if (auth_token) |t| std.mem.span(t) else null);
    py.PyEval_RestoreThread(py_state);
    const conn_num = result catch |err| return raiseConnectError(err);
    return Py_BuildValue("k", @as(c_ulong, conn_num));
}

fn raiseConnectError(err: anyerror) [*c]PyObject {
    var buf: [256]u8 = undefined;
    const detail = net.connectFailure();
    const text = if (detail.len == 0)
        std.fmt.bufPrint(buf[0 .. buf.len - 1], "{s}", .{@errorName(err)}) catch {
            PyErr_SetString(py.PyExc_OSError, @errorName(err));
            return null;
        }
    else
        std.fmt.bufPrint(buf[0 .. buf.len - 1], "{s} ({s})", .{ @errorName(err), detail }) catch {
            PyErr_SetString(py.PyExc_OSError, @errorName(err));
            return null;
        };
    buf[text.len] = 0;
    PyErr_SetString(py.PyExc_OSError, buf[0..text.len :0].ptr);
    return null;
}

/// Close the connection identified by conn_num and free all associated
/// resources.  An unknown or already stopped handle is not an error.
pub fn stopClient(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "k", &conn_num) == 0) return null;
    // Waits for the receiver and for callers still inside the native layer.
    const py_state = py.PyEval_SaveThread();
    Client.destroyClient(conn_num) catch {};
    py.PyEval_RestoreThread(py_state);
    return Py_BuildValue("");
}

/// Send a message on the client connection and return
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
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "OIHHpsspk", &data, &uuid, &flag, &decoder, &is_bytes, &receiver, &func_name, &return_result, &conn_num) == 0) return null;

    var payload = bytesOf(data) orelse return null;
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
    const result = Client.sendMessage(payload.slice, @truncate(uuid), pflag, pdecoder, is_bytes != 0, return_result != 0, std.mem.span(receiver), std.mem.span(func_name), conn_num);
    py.PyEval_RestoreThread(py_state);
    const msgident = result catch |err| {
        PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        return null;
    };
    // For REQUEST the receiver is a copy made under the channel lock (a view
    // into the channel map could be freed by a concurrent disconnect).
    defer if (pflag == .REQUEST) allocator.free(msgident.receiver);
    return Py_BuildValue("(Ils#)", @as(c_uint, msgident.uuid), @as(c_long, msgident.timestamp), msgident.receiver.ptr, @as(py.Py_ssize_t, @intCast(msgident.receiver.len)));
}

/// The bytes of a `bytes` object or of any buffer; anything else is sent as
/// its UTF-8 `str()`.
pub const Payload = struct {
    slice: []const u8,
    converted: ?*PyObject,

    pub fn deinit(self: *Payload) void {
        if (self.converted) |obj| py.Py_DECREF(obj);
    }
};

pub fn bytesOf(data: *PyObject) ?Payload {
    var size: py.Py_ssize_t = 0;
    var raw: [*c]u8 = undefined;
    if (py.PyBytes_Check(data) != 0) {
        if (py.PyBytes_AsStringAndSize(data, @ptrCast(&raw), &size) < 0) return null;
        return .{ .slice = raw[0..@intCast(size)], .converted = null };
    }
    if (py.PyUnicode_Check(data) != 0) {
        const utf8 = py.PyUnicode_AsUTF8AndSize(data, &size) orelse return null;
        return .{ .slice = @as([*]const u8, @ptrCast(utf8))[0..@intCast(size)], .converted = null };
    }
    if (py.PyObject_CheckBuffer(data) == 0) {
        const text = py.PyObject_Str(data) orelse return null;
        const utf8 = py.PyUnicode_AsUTF8AndSize(text, &size) orelse {
            py.Py_DECREF(text);
            return null;
        };
        return .{ .slice = @as([*]const u8, @ptrCast(utf8))[0..@intCast(size)], .converted = text };
    }
    const converted = py.PyBytes_FromObject(data) orelse return null;
    if (py.PyBytes_AsStringAndSize(converted, @ptrCast(&raw), &size) < 0) {
        py.Py_DECREF(converted);
        return null;
    }
    return .{ .slice = raw[0..@intCast(size)], .converted = converted };
}

/// Send the initial client handshake advertising exported method names.
/// Returns (uuid, timestamp, found_receiver).  Raises ValueError on failure.
pub fn sendHandshakeFromClient(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var methods: [*:0]u8 = undefined;
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "sk", &methods, &conn_num) == 0) return null;
    const py_state = py.PyEval_SaveThread();
    const result = Client.sendHandshake(conn_num, std.mem.span(methods));
    py.PyEval_RestoreThread(py_state);
    const msgident = result catch |err| {
        PyErr_SetString(py.PyExc_ValueError, @errorName(err));
        return null;
    };
    return Py_BuildValue("(Ils#)", @as(c_uint, msgident.uuid), @as(c_long, msgident.timestamp), msgident.receiver.ptr, @as(py.Py_ssize_t, @intCast(msgident.receiver.len)));
}

/// The payload of `msg` as a new reference.  A text payload that is not
/// valid UTF-8 comes back as `bytes`: it is the peer's data, and failing
/// here would lose the message (and, in a dispatcher, the dispatcher).
fn payloadObject(msg: *serde.Message) [*c]PyObject {
    const data: []const u8 = msg.getData();
    const len: py.Py_ssize_t = @intCast(data.len);
    if (!msg.isBytes()) {
        if (py.PyUnicode_DecodeUTF8(data.ptr, len, null)) |text| return text;
        py.PyErr_Clear();
    }
    return py.PyBytes_FromStringAndSize(data.ptr, len);
}

/// A name from the wire as a new `str` reference; invalid UTF-8 is replaced.
fn nameObject(name: []const u8) [*c]PyObject {
    return py.PyUnicode_DecodeUTF8(name.ptr, @intCast(name.len), "replace");
}

/// (data, flag, serde) for a response, or the reason no response can come.
fn responseTuple(msg: *serde.Message) [*c]PyObject {
    defer msg.deinit();
    const flag: c_uint = @backingInt(msg.getFlag());
    const decoder: c_uint = @backingInt(msg.getDecoder());
    return Py_BuildValue("(NII)", payloadObject(msg), flag, decoder);
}

fn reasonString(comptime reason: []const u8) [*c]PyObject {
    return Py_BuildValue("s#", reason.ptr, @as(py.Py_ssize_t, reason.len));
}

/// Take the response for uuid if it already arrived.
/// Returns (data, flag, serde), None when it has not arrived, or
/// "disconnected" when the handle is gone.
pub fn getMessageFromClientStore(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var uuid: c_uint = undefined;
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "Ik", &uuid, &conn_num) == 0) return null;
    const msg = (Client.getMessageByUuid(@truncate(uuid), conn_num) catch return reasonString("disconnected")) orelse return Py_BuildValue("");
    return responseTuple(msg);
}

/// uuids of responses parked since the last drain.  Empty list when none
/// have arrived; "disconnected" when the handle is gone.
pub fn drainParkedResponses(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "k", &conn_num) == 0) return null;
    var uuids: std.ArrayList(u16) = .empty;
    defer uuids.deinit(allocator);
    Client.drainParked(conn_num, &uuids, allocator) catch return reasonString("disconnected");
    const list = py.PyList_New(0) orelse return null;
    for (uuids.items) |uuid| {
        const item = Py_BuildValue("I", @as(c_uint, uuid)) orelse {
            py.Py_DECREF(list);
            return null;
        };
        const rc = py.PyList_Append(list, item);
        py.Py_DECREF(item);
        if (rc != 0) {
            py.Py_DECREF(list);
            return null;
        }
    }
    return list;
}

/// Block (without the GIL) for the response to uuid, up to timeout_ms.
/// Returns (data, flag, serde); None on timeout; "disconnected" or
/// "evicted" once no response can arrive.
pub fn waitMessageFromClientStore(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var uuid: c_uint = undefined;
    var timeout_ms: c_uint = undefined;
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "IIk", &uuid, &timeout_ms, &conn_num) == 0) return null;
    const py_state = py.PyEval_SaveThread();
    const outcome = Client.waitMessage(@truncate(uuid), timeout_ms, conn_num);
    py.PyEval_RestoreThread(py_state);
    return switch (outcome) {
        .message => |msg| responseTuple(msg),
        .timeout => Py_BuildValue(""),
        .disconnected => reasonString("disconnected"),
        .evicted => reasonString("evicted"),
    };
}

/// The caller stopped waiting for uuid; a response that arrives later is
/// dropped.  Nothing to do when the connection is already gone.
pub fn expireMessage(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var uuid: c_uint = undefined;
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "Ik", &uuid, &conn_num) == 0) return null;
    Client.expireMessage(@truncate(uuid), conn_num) catch |err| switch (err) {
        error.ClientNotInitialized => {},
        else => {
            PyErr_SetString(py.PyExc_MemoryError, @errorName(err));
            return null;
        },
    };
    return Py_BuildValue("");
}

/// Dequeue one inbound task from the client's incoming message queue.
/// Returns a task tuple, or None when the queue is empty or the handle is gone.
pub fn getMessageForClientWorker(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "k", &conn_num) == 0) return null;
    const msg = (Client.getMessageForClientWorker(conn_num) catch return Py_BuildValue("")) orelse return Py_BuildValue("");
    return taskTuple(msg);
}

/// (uuid, data, flag, serde, transmitter, receiver, func_name, return_result)
/// for one queued task.  Frees the message.
pub fn taskTuple(msg: *serde.Message) [*c]PyObject {
    defer msg.deinit();
    const uuid: c_uint = msg.getUuid();
    const flag: c_uint = @backingInt(msg.getFlag());
    const decoder: c_uint = @backingInt(msg.getDecoder());
    const return_result: c_int = @intFromBool(msg.getReturnResult());
    return Py_BuildValue(
        "(INIINNNi)",
        uuid,
        payloadObject(msg),
        flag,
        decoder,
        nameObject(msg.getTransmitter()),
        nameObject(msg.getReceiver()),
        nameObject(msg.getFuncName()),
        return_result,
    );
}

/// Install (or with -1, withdraw) the descriptor the native layer signals
/// when the client's task queue gets work.
///
/// setClientRequestFd(conn_num: int, fd: int) -> None
pub fn setClientRequestFd(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var fd: c_int = undefined;
    if (py.PyArg_ParseTuple(args, "ki", &conn_num, &fd) == 0) return null;
    Client.setRequestFd(conn_num, fd) catch {};
    return Py_BuildValue("");
}

/// Install (or with -1, withdraw) the pipe that gets one byte per
/// lifecycle change ('d' disconnect, 'e' eviction).
///
/// setLifecycleFd(conn_num: int, fd: int) -> None
pub fn setLifecycleFd(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var fd: c_int = undefined;
    if (py.PyArg_ParseTuple(args, "ki", &conn_num, &fd) == 0) return null;
    Client.setLifecycleFd(conn_num, fd) catch {};
    return Py_BuildValue("");
}

/// Install (or with -1, withdraw) the descriptor signalled when a response
/// is parked for an asyncio waiter.
///
/// setResponseFd(conn_num: int, fd: int) -> None
pub fn setResponseFd(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var fd: c_int = undefined;
    if (py.PyArg_ParseTuple(args, "ki", &conn_num, &fd) == 0) return null;
    Client.setResponseFd(conn_num, fd) catch {};
    return Py_BuildValue("");
}

pub fn acquireDescriptors(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var n: c_long = 0;
    if (py.PyArg_ParseTuple(args, "l", &n) == 0) return null;
    if (n > 0) @import("../nofile.zig").acquire(@intCast(n));
    return Py_BuildValue("");
}

pub fn releaseDescriptors(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var n: c_long = 0;
    if (py.PyArg_ParseTuple(args, "l", &n) == 0) return null;
    if (n > 0) @import("../nofile.zig").release(@intCast(n));
    return Py_BuildValue("");
}

pub fn bumpFileLimit(_: [*c]PyObject, _: [*c]PyObject) callconv(.c) [*c]PyObject {
    const ok: c_int = if (@import("../nofile.zig").bump()) 1 else 0;
    return Py_BuildValue("i", ok);
}

/// Set the native Zig log level at runtime.
///
/// level values: 0=DEBUG  1=INFO  2=WARNING  3=ERROR  4=OFF (default, silent)
///
/// setLogLevel(level: int) -> None
pub fn setLogLevel(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var level: c_int = 4;
    if (py.PyArg_ParseTuple(args, "i", &level) == 0) return null;
    const clamped: u32 = @intCast(@max(0, @min(4, level)));
    @import("../log.zig").setLevel(clamped);
    return Py_BuildValue("");
}

/// getRuntime() -> str
pub fn getRuntime(_: [*c]PyObject, _: [*c]PyObject) callconv(.c) [*c]PyObject {
    const name = @tagName(@import("../runtime.zig").model());
    return Py_BuildValue("s#", name.ptr, @as(py.Py_ssize_t, @intCast(name.len)));
}

/// setRuntime(name: str) -> None
///
/// Lock this process to "threads" or "evented". A later call must
/// repeat the runtime already locked in this process.
pub fn setRuntime(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var name: [*:0]const u8 = undefined;
    if (PyArg_ParseTuple(args, "s", &name) == 0) return null;
    const value = std.mem.span(name);
    const runtime = @import("../runtime.zig");
    const requested = std.meta.stringToEnum(runtime.Model, value) orelse {
        PyErr_SetString(py.PyExc_ValueError, "runtime must be 'threads' or 'evented'");
        return null;
    };
    runtime.configure(requested) catch |err| {
        var buf: [192]u8 = undefined;
        const msg = switch (err) {
            error.RuntimeMismatch => std.fmt.bufPrintSentinel(
                &buf,
                "runtime is already '{s}'",
                .{@tagName(runtime.model())},
                0,
            ),
        } catch unreachable;
        PyErr_SetString(py.PyExc_ValueError, msg);
        return null;
    };
    return Py_BuildValue("");
}

/// The names in the iterable `names` that are not connected peers.  An
/// unknown connection has none connected.
pub fn missingMembers(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    var names: *PyObject = undefined;
    if (py.PyArg_ParseTuple(args, "kO", &conn_num, &names) == 0) return null;
    const iter = py.PyObject_GetIter(names) orelse return null;
    defer py.Py_DECREF(iter);
    const missing = py.PyList_New(0) orelse return null;
    while (py.PyIter_Next(iter)) |name| {
        defer py.Py_DECREF(name);
        var size: py.Py_ssize_t = undefined;
        const utf8 = py.PyUnicode_AsUTF8AndSize(name, &size) orelse {
            py.Py_DECREF(missing);
            return null;
        };
        const present = Client.hasMember(conn_num, utf8[0..@intCast(size)]) catch false;
        if (!present and py.PyList_Append(missing, name) != 0) {
            py.Py_DECREF(missing);
            return null;
        }
    }
    if (py.PyErr_Occurred() != null) {
        py.Py_DECREF(missing);
        return null;
    }
    return missing;
}

/// Return a JSON-encoded list of currently connected nodes, or None on error.
pub fn getAvailableMembers(_: [*c]PyObject, args: [*c]PyObject) callconv(.c) [*c]PyObject {
    var conn_num: c_ulong = undefined;
    if (py.PyArg_ParseTuple(args, "k", &conn_num) == 0) return null;
    // getAvailableMembers returns allocator-owned memory (always).  We must
    // free it after Py_BuildValue has copied it into a Python string object.
    const members = Client.getAvailableMembers(allocator, conn_num) catch return Py_BuildValue("");
    defer allocator.free(members);
    return Py_BuildValue("s#", members.ptr, members.len);
}
