"""
Typed Python bindings for the ``dfcore`` native extension.

All functions delegate directly to C-level calls exposed by the Zig
``dfcore`` shared library, providing type annotations and docstrings so
the rest of the Python code does not call ``dfcore.*`` directly.
"""

from __future__ import annotations

import json
import threading
from . import dfcore
from enum import IntEnum
from typing import Union, Tuple

from daffi._serialization import SerdeFormat

_members_cache: dict[int, list] = {}
_members_lock = threading.Lock()


def invalidate_members(conn_num: int | None = None) -> None:
    """Drop cached membership for *conn_num*, or for every connection."""
    with _members_lock:
        if conn_num is None:
            _members_cache.clear()
        else:
            _members_cache.pop(conn_num, None)


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
        data:          Serialised payload.  ``bytes`` and ``str`` are passed
                       to the native layer without a copy.
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
    return dfcore.sendMessageFromClient(
        data, uuid, flag, serde, is_bytes, receiver, func_name, return_result, conn_num
    )


def send_handshake_from_client(methods: str, conn_num: int) -> Tuple[int, int, str]:
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
    with _members_lock:
        cached = _members_cache.get(conn_num)
        if cached is not None:
            return cached
    members_json = dfcore.getAvailableMembers(conn_num)
    members = json.loads(members_json)["members"] if members_json else []
    with _members_lock:
        _members_cache[conn_num] = members
    return members


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
    return dfcore.sendMessageFromServer(
        data, uuid, flag, serde, is_bytes, receiver, func_name, return_result, conn_num
    )


def get_message_from_client_store(
    uuid: int, conn_num: int
) -> Union[Tuple[Union[bytes, str], int, int], str, None]:
    """Take the response to *uuid* if it already arrived.

    Returns:
        ``(data, flag, serde)``; ``None`` when it has not arrived yet; or
        ``"disconnected"`` when the connection is gone.
    """
    return dfcore.getMessageFromClientStore(uuid, conn_num)


def drain_parked_responses(conn_num: int) -> Union[list, str]:
    """uuids of responses parked since the last drain.

    Returns a list of request ids, or ``"disconnected"`` when the handle
    is gone.  The payloads stay in the store until
    :func:`get_message_from_client_store`.
    """
    return dfcore.drainParkedResponses(conn_num)


def wait_message_from_client_store(
    uuid: int, timeout_ms: int, conn_num: int
) -> Union[Tuple[Union[bytes, str], int, int], str, None]:
    """Wait up to *timeout_ms* for the response to *uuid*, without the GIL.

    Returns:
        ``(data, flag, serde)``; ``None`` on timeout; or ``"disconnected"`` /
        ``"evicted"`` once no response can arrive.
    """
    return dfcore.waitMessageFromClientStore(uuid, timeout_ms, conn_num)


def expire_message(uuid: int, conn_num: int) -> None:
    """Stop waiting for *uuid*: a response that arrives later is dropped."""
    dfcore.expireMessage(uuid, conn_num)


def set_request_fd(conn_num: int, fd: int, *, server_mode: bool) -> None:
    """Register the fd the native layer signals whenever an **incoming request**
    (a call to one of this connection's ``@callback`` functions) is pushed onto
    the task queue for *conn_num*.

    The :class:`~daffi._task_dispatcher.TaskDispatcher` poller blocks on this
    fd so it wakes only when real work arrives — no busy-wait or fixed-interval
    polling.

    Works for both Service and Client connections — *server_mode* selects the
    correct native entry point, since the two connection types are managed by
    separate pools in the native layer.

    Args:
        conn_num:    Native connection handle.
        fd:          An ``os.eventfd`` (Linux) or the **write end** of an
                     ``os.pipe()`` (macOS / fallback).
        server_mode: ``True`` for Service connections, ``False`` for Client.

    Pass ``-1`` to withdraw the fd before closing it.
    """
    if server_mode:
        dfcore.setServiceRequestFd(conn_num, fd)
    else:
        dfcore.setClientRequestFd(conn_num, fd)


def set_lifecycle_fd(conn_num: int, fd: int) -> None:
    """Register the lifecycle pipe write-end for the connection watcher thread.

    The native layer writes exactly one byte to signal why the connection ended:

    * ``b'd'`` — normal disconnect  → Python raises :class:`~daffi.exceptions.Disconnected`
    * ``b'e'`` — client evicted     → Python raises :class:`~daffi.exceptions.Evicted`

    Pass ``-1`` to withdraw the fd before closing it.
    """
    dfcore.setLifecycleFd(conn_num, fd)


def set_response_fd(conn_num: int, fd: int) -> None:
    """Register the fd the native layer signals whenever a **response** is
    parked in the client message store for an asyncio waiter.

    Blocking waiters use :func:`wait_message_from_client_store` instead.
    Pass ``-1`` to withdraw the fd before closing it.

    Args:
        conn_num: Native connection handle returned by ``dfcore.startClient``.
        fd:       An ``os.eventfd`` (Linux) or the **write end** of an
                  ``os.pipe()`` (macOS / fallback).
    """
    dfcore.setResponseFd(conn_num, fd)


def set_service_methods(methods: str, conn_num: int) -> None:
    """Notify the native layer of the methods this service exposes.

    Called after every new ``@callback`` registration so that the router can
    route requests to this service.

    Args:
        methods:  Comma-separated list of callback names.
        conn_num: Native connection handle.
    """
    dfcore.setServiceMethods(methods, conn_num)
