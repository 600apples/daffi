//! Defines the `dfcore` Python extension module and its method table.

const std = @import("std");
const py = @import("python.zig").c;
const PyObject = py.PyObject;
const PyMethodDef = py.PyMethodDef;
const PyModule_Create = py.PyModule_Create;
const cffi = @import("cffi.zig");

var Methods = [_]PyMethodDef{
    .{ .ml_name = "startServer",               .ml_meth = cffi.startServer,               .ml_flags = 1, .ml_doc = "startServer(host, port, mode, password, app_name, tls, cert_file, key_file) -> int | None\n\nBind to host:port and start the server dispatcher thread.\nReturns a conn_num handle, or None on failure.\n\n  tls       - True to enable TLS (requires cert_file and key_file)\n  cert_file - path to PEM server certificate (ignored when tls=False)\n  key_file  - path to PEM server private key (ignored when tls=False)" },
    .{ .ml_name = "stopServer",                .ml_meth = cffi.stopServer,                .ml_flags = 1, .ml_doc = "stopServer(conn_num)\n\nSignal the server to stop and release all native resources." },
    .{ .ml_name = "joinServer",                .ml_meth = cffi.joinServer,                .ml_flags = 1, .ml_doc = "joinServer(conn_num)\n\nBlock until the server dispatcher thread exits." },
    .{ .ml_name = "detachServer",              .ml_meth = cffi.detachServer,              .ml_flags = 1, .ml_doc = "detachServer(conn_num)\n\nDetach the server thread; resources are reclaimed when it exits." },
    .{ .ml_name = "startClient",               .ml_meth = cffi.startClient,               .ml_flags = 1, .ml_doc = "startClient(host, port, password, app_name, tls, ca_file) -> int | None\n\nOpen a TCP connection and return a conn_num handle, or None on failure.\n\n  tls     - True to enable TLS\n  ca_file - path to PEM CA bundle for server cert verification;\n            empty string disables verification" },
    .{ .ml_name = "stopClient",                .ml_meth = cffi.stopClient,                .ml_flags = 1, .ml_doc = "stopClient(conn_num)\n\nClose the client connection and free all associated resources." },
    .{ .ml_name = "sendMessageFromClient",     .ml_meth = cffi.sendMessageFromClient,     .ml_flags = 1, .ml_doc = "sendMessageFromClient(data, uuid, flag, serde, is_bytes, receiver, func_name, return_result, conn_num)\n    -> (uuid, timestamp, found_receiver)\n\nEnqueue an outbound message on the client connection." },
    .{ .ml_name = "sendHandshakeFromClient",   .ml_meth = cffi.sendHandshakeFromClient,   .ml_flags = 1, .ml_doc = "sendHandshakeFromClient(password, methods, conn_num)\n    -> (uuid, timestamp, found_receiver)\n\nSend the initial client handshake." },
    .{ .ml_name = "getAvailableMembers",       .ml_meth = cffi.getAvailableMembers,       .ml_flags = 1, .ml_doc = "getAvailableMembers(conn_num) -> str | None\n\nReturn a JSON-encoded list of currently connected nodes." },
    .{ .ml_name = "sendMessageFromServer",     .ml_meth = cffi.sendMessageFromServer,     .ml_flags = 1, .ml_doc = "sendMessageFromServer(data, uuid, flag, serde, is_bytes, receiver, func_name, return_result, conn_num)\n    -> (uuid, timestamp, found_receiver)\n\nEnqueue an outbound message on the server connection." },
    .{ .ml_name = "getMessageFromClientStore", .ml_meth = cffi.getMessageFromClientStore, .ml_flags = 1, .ml_doc = "getMessageFromClientStore(uuid, conn_num) -> (data, flag, serde) | None\n\nPoll the client message store for a response to uuid." },
    .{ .ml_name = "setTimeoutError",           .ml_meth = cffi.setTimeoutError,           .ml_flags = 1, .ml_doc = "setTimeoutError(uuid, conn_num)\n\nMark a pending message as timed-out so its slot can be reclaimed." },
    .{ .ml_name = "getMessageForClientWorker", .ml_meth = cffi.getMessageForClientWorker, .ml_flags = 1, .ml_doc = "getMessageForClientWorker(conn_num) -> tuple | None\n\nDequeue one inbound task from the client message queue." },
    .{ .ml_name = "getMessageForServerWorker", .ml_meth = cffi.getMessageForServerWorker, .ml_flags = 1, .ml_doc = "getMessageForServerWorker(conn_num) -> tuple | None\n\nDequeue one inbound task from the server message queue." },
    .{ .ml_name = "setServiceMethods",         .ml_meth = cffi.setServiceMethods,         .ml_flags = 1, .ml_doc = "setServiceMethods(methods, conn_num)\n\nUpdate the comma-separated set of callback names this service advertises." },
    .{ .ml_name = "setWakeupFd",               .ml_meth = cffi.setWakeupFd,               .ml_flags = 1, .ml_doc = "setWakeupFd(conn_num, fd)\n\nRegister an eventfd or pipe write-end that the native layer will signal\nwhenever a message is pushed onto the Service task queue.\nCall once after startServer() returns and before the handshake." },
    .{ .ml_name = "setClientWakeupFd",        .ml_meth = cffi.setClientWakeupFd,        .ml_flags = 1, .ml_doc = "setClientWakeupFd(conn_num, fd)\n\nRegister an eventfd or pipe write-end for a Client connection acting as a\nworker in a router topology.\nCalled once after startClient() returns so the Python task dispatcher is\nnotified immediately instead of relying on the 1 ms fallback poll." },
    .{ .ml_name = null, .ml_meth = null, .ml_flags = 0, .ml_doc = null },
};

var module = py.PyModuleDef{
    .m_base = std.mem.zeroes(py.PyModuleDef_Base),
    .m_name = "dfcore",
    .m_doc = "Native Zig extension providing the dfcore messaging transport.",
    .m_size = -1,
    .m_methods = &Methods,
    .m_slots = null,
    .m_traverse = null,
    .m_clear = null,
    .m_free = null,
};

pub export fn PyInit_dfcore() [*]PyObject {
    return PyModule_Create(&module);
}
