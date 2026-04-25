"""
Typed Python bindings for the ``dfcore`` native extension.

All functions delegate directly to C-level calls exposed by the Zig
``dfcore`` shared library, providing type annotations and docstrings so
the rest of the Python code does not call ``dfcore.*`` directly.
"""

from __future__ import annotations

import ctypes
import json
from . import dfcore
from enum import IntEnum
from typing import Union, Tuple

from daffi._serialization import SerdeFormat


class MessageFlag(IntEnum):
    """Wire-level message type codes.

    Values must match the ``MessageFlag`` enum in the Zig
    ``core/serde/message.zig`` source.
    """

    HANDSHAKE = 0
    REQUEST = 1
    RESPONSE = 2
    ERROR = 3
    EVENTS = 4


def send_message_from_client(
    data: Union[str, bytes],
    flag: MessageFlag,
    serde: SerdeFormat,
    receiver: str,
    func_name: str,
    return_result: bool,
    conn_num: int,
    is_bytes: bool = True,
    uuid: int = 0,
) -> Tuple[int, int, str]:
    """Send a message from a client connection.

    Args:
        data:          Serialised payload (bytes or str depending on *serde*).
        flag:          Message type — one of :class:`MessageFlag`.
        serde:         Serialisation format — one of :class:`~daffi.serialization.SerdeFormat`.
        receiver:      Target node name, or an empty string for any node.
        func_name:     Name of the remote callback to invoke.
        return_result: ``True`` if the caller expects a response message.
        conn_num:      Native connection handle returned by ``dfcore.startClient``.
        is_bytes:      Whether *data* is raw bytes (``True``) or a UTF-8 string.
        uuid:          Message UUID for correlating responses. ``0`` lets the
                       native layer assign one.

    Returns:
        A ``(uuid, timestamp, found_receiver)`` tuple.
    """
    if is_bytes:
        data = bytes(data)
        data = ctypes.create_string_buffer(data, len(data))
    else:
        data = str(data)
        encoded = data.encode()
        data = ctypes.create_string_buffer(encoded, len(encoded))
    return dfcore.sendMessageFromClient(
        data, uuid, flag, serde, is_bytes, receiver, func_name, return_result, conn_num
    )


def send_handshake_from_client(
    methods: str, conn_num: int
) -> Tuple[int, int, str]:
    """Send the initial client handshake carrying the node's exported method list.

    Args:
        methods:  Comma-separated list of callback names this client exposes.
        conn_num: Native connection handle.

    Returns:
        A ``(uuid, timestamp, found_receiver)`` tuple for the handshake message.
    """
    return dfcore.sendHandshakeFromClient(methods, conn_num)


def get_available_members(conn_num: int) -> list:
    """Return the list of currently connected nodes.

    Args:
        conn_num: Native connection handle.

    Returns:
        A list of member-info dicts, or an empty list when none are available.
    """
    members = dfcore.getAvailableMembers(conn_num)
    return json.loads(members)["members"] if members else []


def send_message_from_service(
    data: Union[str, bytes],
    flag: MessageFlag,
    serde: SerdeFormat,
    receiver: str,
    func_name: str,
    return_result: bool,
    conn_num: int,
    is_bytes: bool = True,
    uuid: int = 0,
) -> Tuple[int, int, str]:
    """Send a message from a service connection.

    Identical signature to :func:`send_message_from_client` but routes through
    the server-side native send path.
    """
    if is_bytes:
        data = bytes(data)
        data = ctypes.create_string_buffer(data, len(data))
    else:
        data = str(data)
        encoded = data.encode()
        data = ctypes.create_string_buffer(encoded, len(encoded))
    return dfcore.sendMessageFromServer(
        data, uuid, flag, serde, is_bytes, receiver, func_name, return_result, conn_num
    )


def get_message_from_client_store(uuid: int, conn_num: int) -> Tuple:
    """Poll the native client message store for a response to *uuid*.

    Args:
        uuid:     Message UUID previously returned by :func:`send_message_from_client`.
        conn_num: Native connection handle.

    Returns:
        A ``(data, flag, serde)`` tuple when the response is ready, or ``None``
        if it has not arrived yet.
    """
    return dfcore.getMessageFromClientStore(uuid, conn_num)


def mark_message_as_expired(uuid: int, conn_num: int) -> None:
    """Mark a pending message as timed-out so the native layer can clean it up.

    Args:
        uuid:     Message UUID to expire.
        conn_num: Native connection handle.
    """
    dfcore.setTimeoutError(uuid, conn_num)


def set_wakeup_fd(conn_num: int, fd: int) -> None:
    """Register the eventfd (or pipe write-end) that the native layer writes to
    whenever a new message is pushed onto the Service task queue for *conn_num*.

    Call once immediately after :func:`~daffi.bindings.startServer` returns and
    before the handshake advertises the service's methods to clients.

    Args:
        conn_num: Native connection handle returned by ``dfcore.startServer``.
        fd:       An ``os.eventfd`` fd (Linux) or the **write end** of an
                  ``os.pipe()`` (macOS / fallback).
    """
    dfcore.setWakeupFd(conn_num, fd)


def set_client_disconnect_fd(conn_num: int, fd: int) -> None:
    """Register the pipe write-end written to once by the native layer when the
    client connection is lost.  Python selects on the corresponding read end so
    AutoReconnect can react without a polling thread.
    """
    dfcore.setClientDisconnectFd(conn_num, fd)


def set_client_response_fd(conn_num: int, fd: int) -> None:
    """Register the eventfd / pipe write-end the native layer writes to whenever
    a new response is inserted into the client message store.

    Python's :class:`~daffi._rpc_proxy.RpcResult` waiters block on the
    corresponding read end with a select-based deadline instead of polling the
    store, so a slow remote call no longer burns CPU on a busy-wait loop.

    Args:
        conn_num: Native connection handle returned by :func:`~daffi.bindings.startClient`.
        fd:       An ``os.eventfd`` (Linux) or the **write end** of an
                  ``os.pipe()`` (macOS / fallback).
    """
    dfcore.setClientResponseFd(conn_num, fd)


def set_client_wakeup_fd(conn_num: int, fd: int) -> None:
    """Register the eventfd (or pipe write-end) for a Client connection used
    as a worker in a router topology.

    The native layer writes to *fd* whenever a new task arrives on the
    client's task queue, allowing the Python poller to block on
    ``select.select`` rather than sleeping for 1 ms between polls.

    Call once immediately after :func:`~daffi.bindings.startClient` returns.

    Args:
        conn_num: Native connection handle returned by ``dfcore.startClient``.
        fd:       An ``os.eventfd`` fd (Linux) or the **write end** of an
                  ``os.pipe()`` (macOS / fallback).
    """
    dfcore.setClientWakeupFd(conn_num, fd)


def set_service_methods(methods: str, conn_num: int) -> None:
    """Notify the native layer of the methods this service exposes.

    Called after every new ``@callback`` registration so that the router can
    route requests to this service.

    Args:
        methods:  Comma-separated list of callback names.
        conn_num: Native connection handle.
    """
    dfcore.setServiceMethods(methods, conn_num)
