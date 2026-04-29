//! Defines the `dfcore` Python extension module and its method table.
//!
//! The table is assembled from two const sub-arrays — one per side of the
//! protocol — and a single null sentinel at the very end.  Using separate
//! named arrays makes it easy to see which CFFI functions belong to which
//! role without scrolling through one giant flat list.

const std = @import("std");

/// Keep all log levels compiled in; the runtime gate in log.logFn filters
/// by the Python-controlled g_level atomic.  Users call dfcore.setLogLevel()
/// to enable native debug output at runtime without a recompile.
pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn    = @import("log.zig").logFn,
};

const py = @import("python.zig").c;
const PyObject = py.PyObject;
const PyMethodDef = py.PyMethodDef;
const PyModule_Create = py.PyModule_Create;
const cffi = @import("cffi.zig");

// Server-side methods (Router / Service)
// Imported from cffi/server.zig.  A Service or Router calls these to bind a
// port, dispatch inbound tasks, and advertise its callback set.

const server_methods = [_]PyMethodDef{
    .{
        .ml_name  = "startServer",
        .ml_meth  = cffi.startServer,
        .ml_flags = 1,
        .ml_doc   =
            \\startServer(host, port, mode, app_name, tls, cert_file, key_file) -> int | None
            \\
            \\Bind to host:port and start the server dispatcher thread.
            \\Returns a conn_num handle, or None on failure.
            \\
            \\  tls       - True to enable TLS (requires cert_file and key_file)
            \\  cert_file - path to PEM server certificate (ignored when tls=False)
            \\  key_file  - path to PEM server private key  (ignored when tls=False)
        ,
    },
    .{
        .ml_name  = "stopServer",
        .ml_meth  = cffi.stopServer,
        .ml_flags = 1,
        .ml_doc   =
            \\stopServer(conn_num)
            \\
            \\Signal the server to stop and release all native resources.
        ,
    },
    .{
        .ml_name  = "joinServer",
        .ml_meth  = cffi.joinServer,
        .ml_flags = 1,
        .ml_doc   =
            \\joinServer(conn_num)
            \\
            \\Block until the server dispatcher thread exits.
        ,
    },
    .{
        .ml_name  = "detachServer",
        .ml_meth  = cffi.detachServer,
        .ml_flags = 1,
        .ml_doc   =
            \\detachServer(conn_num)
            \\
            \\Detach the server thread; resources are reclaimed when it exits.
        ,
    },
    .{
        .ml_name  = "sendMessageFromServer",
        .ml_meth  = cffi.sendMessageFromServer,
        .ml_flags = 1,
        .ml_doc   =
            \\sendMessageFromServer(data, uuid, flag, serde, is_bytes, receiver, func_name, return_result, conn_num)
            \\    -> (uuid, timestamp, found_receiver)
            \\
            \\Enqueue an outbound message on the server connection.
        ,
    },
    .{
        .ml_name  = "getMessageForServerWorker",
        .ml_meth  = cffi.getMessageForServerWorker,
        .ml_flags = 1,
        .ml_doc   =
            \\getMessageForServerWorker(conn_num) -> tuple | None
            \\
            \\Dequeue one inbound task from the server message queue.
        ,
    },
    .{
        .ml_name  = "setServiceMethods",
        .ml_meth  = cffi.setServiceMethods,
        .ml_flags = 1,
        .ml_doc   =
            \\setServiceMethods(methods, conn_num)
            \\
            \\Update the comma-separated set of callback names this service advertises.
        ,
    },
    .{
        .ml_name  = "setServiceRequestFd",
        .ml_meth  = cffi.setServiceRequestFd,
        .ml_flags = 1,
        .ml_doc   =
            \\setServiceRequestFd(conn_num, fd)
            \\
            \\Register the fd signalled by the native layer when an incoming request
            \\is pushed onto the Service task queue.  The TaskDispatcher poller
            \\blocks on this fd — no busy-wait or fixed-interval polling.
        ,
    },
};

// Client-side methods
// Imported from cffi/client.zig.  A Client (or a worker node that connects
// through a Router) uses these to open connections, send calls, and poll for
// responses or inbound callback tasks.

const client_methods = [_]PyMethodDef{
    .{
        .ml_name  = "startClient",
        .ml_meth  = cffi.startClient,
        .ml_flags = 1,
        .ml_doc   =
            \\startClient(host, port, app_name, tls, ca_file) -> int | None
            \\
            \\Open a TCP connection and return a conn_num handle, or None on failure.
            \\
            \\  tls     - True to enable TLS
            \\  ca_file - path to PEM CA bundle for server cert verification;
            \\            empty string disables verification
        ,
    },
    .{
        .ml_name  = "stopClient",
        .ml_meth  = cffi.stopClient,
        .ml_flags = 1,
        .ml_doc   =
            \\stopClient(conn_num)
            \\
            \\Close the client connection and free all associated resources.
        ,
    },
    .{
        .ml_name  = "sendMessageFromClient",
        .ml_meth  = cffi.sendMessageFromClient,
        .ml_flags = 1,
        .ml_doc   =
            \\sendMessageFromClient(data, uuid, flag, serde, is_bytes, receiver, func_name, return_result, conn_num)
            \\    -> (uuid, timestamp, found_receiver)
            \\
            \\Enqueue an outbound message on the client connection.
        ,
    },
    .{
        .ml_name  = "sendHandshakeFromClient",
        .ml_meth  = cffi.sendHandshakeFromClient,
        .ml_flags = 1,
        .ml_doc   =
            \\sendHandshakeFromClient(methods, conn_num)
            \\    -> (uuid, timestamp, found_receiver)
            \\
            \\Send the initial client handshake.
        ,
    },
    .{
        .ml_name  = "getAvailableMembers",
        .ml_meth  = cffi.getAvailableMembers,
        .ml_flags = 1,
        .ml_doc   =
            \\getAvailableMembers(conn_num) -> str | None
            \\
            \\Return a JSON-encoded list of currently connected nodes.
        ,
    },
    .{
        .ml_name  = "getMessageFromClientStore",
        .ml_meth  = cffi.getMessageFromClientStore,
        .ml_flags = 1,
        .ml_doc   =
            \\getMessageFromClientStore(uuid, conn_num) -> (data, flag, serde) | None
            \\
            \\Poll the client message store for a response to uuid.
        ,
    },
    .{
        .ml_name  = "setTimeoutError",
        .ml_meth  = cffi.setTimeoutError,
        .ml_flags = 1,
        .ml_doc   =
            \\setTimeoutError(uuid, conn_num)
            \\
            \\Mark a pending message as timed-out so its slot can be reclaimed.
        ,
    },
    .{
        .ml_name  = "getMessageForClientWorker",
        .ml_meth  = cffi.getMessageForClientWorker,
        .ml_flags = 1,
        .ml_doc   =
            \\getMessageForClientWorker(conn_num) -> tuple | None
            \\
            \\Dequeue one inbound task from the client message queue.
        ,
    },
    .{
        .ml_name  = "setClientRequestFd",
        .ml_meth  = cffi.setClientRequestFd,
        .ml_flags = 1,
        .ml_doc   =
            \\setClientRequestFd(conn_num, fd)
            \\
            \\Register the fd signalled by the native layer when an incoming request
            \\is pushed onto a Client task queue (worker in a router topology).
            \\The TaskDispatcher poller blocks on this fd — no busy-wait.
        ,
    },
    .{
        .ml_name  = "setLifecycleFd",
        .ml_meth  = cffi.setLifecycleFd,
        .ml_flags = 1,
        .ml_doc   =
            \\setLifecycleFd(conn_num, fd)
            \\
            \\Register the single pipe write-end for the non-autoreconnect disconnect
            \\watcher.  One byte is written to it when the connection ends:
            \\  'd' -> normal disconnect  (Python raises ConnectionError)
            \\  'e' -> client evicted     (Python raises EvictedError)
            \\Using one fd avoids a select() on multiple pipes in the watcher thread.
        ,
    },
    .{
        .ml_name  = "setResponseFd",
        .ml_meth  = cffi.setResponseFd,
        .ml_flags = 1,
        .ml_doc   =
            \\setResponseFd(conn_num, fd)
            \\
            \\Register an eventfd or pipe write-end that the native layer signals
            \\whenever a new response is inserted into the client message store.
            \\Python's RpcResult waiters block on the corresponding read end with
            \\a select-based deadline instead of polling the store.
        ,
    },
};

// ── Logging / utility methods ─────────────────────────────────────────────────
const util_methods = [_]PyMethodDef{
    .{
        .ml_name  = "setLogLevel",
        .ml_meth  = cffi.setLogLevel,
        .ml_flags = 1,
        .ml_doc   =
            \\setLogLevel(level: int) -> None
            \\
            \\Set the native Zig log level at runtime:
            \\  0 → DEBUG    (most verbose)
            \\  1 → INFO
            \\  2 → WARNING
            \\  3 → ERROR
            \\  4 → OFF      (default — silent)
            \\
            \\Typically called with the numeric equivalent of the Python
            \\root-logger level so that native log messages appear iff the
            \\Python logger would also emit them.
        ,
    },
};

// ── Combined method table ─────────────────────────────────────────────────────
var methods = server_methods ++ client_methods ++ util_methods ++ [_]PyMethodDef{
    .{ .ml_name = null, .ml_meth = null, .ml_flags = 0, .ml_doc = null },
};

var module = py.PyModuleDef{
    .m_base     = std.mem.zeroes(py.PyModuleDef_Base),
    .m_name     = "dfcore",
    .m_doc      = "Native Zig extension providing the dfcore messaging transport.",
    .m_size     = -1,
    .m_methods  = &methods,
    .m_slots    = null,
    .m_traverse = null,
    .m_clear    = null,
    .m_free     = null,
};

pub export fn PyInit_dfcore() [*]PyObject {
    return PyModule_Create(&module);
}
