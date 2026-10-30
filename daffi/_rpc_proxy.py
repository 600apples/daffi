"""
Call-builder proxies and the :class:`ClientConnection` handle returned by
:meth:`~daffi.app.Client.connect`.

Five call styles are available on every :class:`ClientConnection`:

* :meth:`~ClientConnection.rpc`          — one worker, blocking, returns result
* :meth:`~ClientConnection.rpc_nowait`   — one worker, fire-and-forget
* :meth:`~ClientConnection.cast`         — all matching workers, blocking, returns ``{name: result}`` dict
* :meth:`~ClientConnection.cast_nowait`  — all matching workers, fire-and-forget
* :meth:`~ClientConnection.stream`         — iterate a generator, wait for ack per chunk (backpressure)
* :meth:`~ClientConnection.stream_nowait`  — iterate a generator, fire-and-forget per chunk (no backpressure)
"""

from __future__ import annotations

import json
import math
import time
import logging
import threading
from itertools import repeat
from typing import TYPE_CHECKING, Union, Tuple, List, Optional
from contextlib import contextmanager

if TYPE_CHECKING:
    from daffi.app import Client

from daffi._serialization import SerdeFormat, Serializer
from daffi.exceptions import (
    InitializationError,
    CallTimeout,
    Disconnected,
    Evicted,
    TransmissionFailure,
    RemoteCallError,
)
from daffi.utils.misc import iterable
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._bindings import (
    send_message_from_client,
    wait_message_from_client_store,
    expire_message,
    set_service_methods,
    send_handshake_from_client,
    get_available_members,
    MessageFlag,
)
from . import dfcore

METADATA_SEPARATOR = ","


def connection_lost_error(evicted: bool, app_name: Optional[str] = None) -> Exception:
    """The error for a call or connection that ended because the peer went away."""
    if evicted:
        who = f" (app_name={app_name!r})" if app_name else ""
        return Evicted(
            f"This client{who} was evicted — "
            "a new connection with the same app_name took over its slot."
        )
    return Disconnected(
        "Server disconnected unexpectedly.\n\n"
        "  The router or service this client was connected to has stopped."
    )


def unpack_response(res: Tuple, request_serde: Optional[int]) -> Tuple[bytes, int, int]:
    """Return ``(data, flag, serde)`` for a RESPONSE, or raise the remote error.

    The response must use the request's format; an error may also come as
    JSON (the native layer and OPAQUE callbacks report errors that way).
    Anything else is refused, so a peer cannot get a PICKLE payload loaded
    by a caller that never asked for one.
    """
    data, flag, serde = res
    if request_serde is not None and serde != request_serde:
        if not (flag == MessageFlag.ERROR and serde == SerdeFormat.JSON):
            raise RemoteCallError(
                f"Response format {serde} does not match the request format {request_serde}."
            )
    if flag == MessageFlag.ERROR:
        (error_tuple,), _ = Serializer.deserialize(serde, data)
        err_name, err_module, err_msg, tb = error_tuple
        restored_exc = type(err_name, (RemoteCallError,), {"__module__": err_module})
        if tb:
            raise restored_exc(err_msg).with_traceback(tb)
        raise restored_exc(err_msg)
    return data, flag, serde


@contextmanager
def system_exception_handler(
    msg_template: str,
    errtype: type,
    conn_num: int = 0,
    conn_info: tuple = (),
):
    """Context manager that converts low-level errors from the native extension
    into a friendlier *errtype* exception.

    Args:
        msg_template: A ``str.format``-style template with one ``{}`` placeholder
                      for the original error message.
        errtype:      The exception class to raise.
        conn_num:     Optional native connection handle.  When provided and the
                      error is ``ReceiverNotFound``, the message is enriched with
                      the list of currently connected peers.
        conn_info:    Optional ``(host, port, unix_sock_path)`` tuple used to
                      enrich ``ConnectionRefused`` errors with address details.
    """
    try:
        yield
    except (SystemError, ValueError) as e:
        if isinstance(e, SystemError):
            origin = e.__cause__.args[0] if e.__cause__ else str(e)
        else:
            origin = str(e)

        if origin == "Evicted":
            raise connection_lost_error(True).with_traceback(None) from None
        if "ReceiverNotFound" in origin and conn_num:
            available = get_available_members(conn_num)
            if available:
                peer_parts = []
                for m in available:
                    methods = m.get("methods") or []
                    if methods:
                        cb_list = ", ".join(methods)
                        peer_parts.append(
                            f"      • {m['name']}\n          callbacks: [{cb_list}]"
                        )
                    else:
                        peer_parts.append(
                            f"      • {m['name']}\n          callbacks: (none)"
                        )
                peer_lines = "\n".join(peer_parts)
            else:
                peer_lines = "      (none connected)"
            origin = (
                "ReceiverNotFound\n\n"
                "  The peer is either not connected to the router, or it is\n"
                "  connected but does not have the requested @callback registered.\n"
                f"\n"
                f"  Connected peers:\n{peer_lines}"
            )

        elif "ConnectionRefused" in origin and conn_info:
            import socket as _socket

            host, port, unix_sock_path = conn_info
            if unix_sock_path:
                addr = f"unix://{unix_sock_path}"
                hint = (
                    f"\n  Check that the socket path is writable and not already in use.\n"
                    f"  Remove a stale socket with:  rm -f {unix_sock_path}"
                )
            else:
                addr = f"{host}:{port}"
                in_use = False
                if host and port:
                    try:
                        with _socket.create_connection((host, port), timeout=0.5):
                            in_use = True
                    except OSError:
                        pass
                if in_use:
                    hint = f"\n  Port {port} on {host} is already occupied by another process."
                else:
                    hint = (
                        f"\n  The server could not bind to {addr}.\n"
                        f"  Verify the address is reachable and the port is not blocked."
                    )
            origin = (
                f"ConnectionRefused\n\n"
                f"  Failed to start the server on {addr}.{hint}"
            )

        raise errtype(msg_template.format(origin)).with_traceback(None) from None


class _BoundRpc:
    """Immutable callable returned by :meth:`RpcProxy.__getattr__`.

    Closes over ``func_name`` at creation time — the parent proxy is never
    mutated, so sharing one :class:`RpcProxy` across multiple threads is safe::

        proxy = conn.rpc(timeout=5)
        t1 = threading.Thread(target=lambda: proxy.echo("a"))
        t2 = threading.Thread(target=lambda: proxy.multiply(3, 4))
        # Both threads capture distinct _BoundRpc objects with their own func_name.
    """

    __slots__ = ("_proxy", "_func_name")

    def __init__(self, proxy: "RpcProxy", func_name: str) -> None:
        self._proxy = proxy
        self._func_name = func_name

    def __str__(self) -> str:
        req_name = "rpc call" if self._proxy.return_result else "rpc_nowait"
        to_receiver = f" to {self._proxy.receiver}" if self._proxy.receiver else ""
        return f"{req_name}{to_receiver}(fn: {self._func_name!r})"

    __repr__ = __str__

    def __call__(self, *args, **kwargs):
        self._proxy.conn._ensure_connected()
        if self._proxy.return_result:
            return self._proxy._process_rpc(self._func_name, *args, **kwargs)
        else:
            self._proxy._process_stream(self._func_name, *args, **kwargs)


class RpcProxy:
    """Lazy call builder returned by :meth:`~daffi.app.ClientConnection.rpc`
    and :meth:`~daffi.app.ClientConnection.rpc_nowait`.

    The proxy itself is **immutable** after construction.  :meth:`__getattr__`
    returns a :class:`_BoundRpc` that closes over the function name — the same
    proxy instance can be shared safely across threads::

        proxy = conn.rpc(timeout=5)
        result = proxy.add(1, 2)          # sequential — fine
        # concurrent — also fine, each __getattr__ creates a distinct _BoundRpc:
        with ThreadPoolExecutor() as pool:
            f1 = pool.submit(proxy.echo, "a")
            f2 = pool.submit(proxy.multiply, 3, 4)
    """

    def __init__(
        self,
        conn: "ClientConnection",
        timeout: Union[int, None],
        receiver: Union[str, List[str], None],
        serde: SerdeFormat,
        return_result: bool,
        logger: logging.Logger,
    ):
        self.conn = conn
        self.timeout = int(timeout or 0)
        self.receiver = (
            METADATA_SEPARATOR.join(receiver) if iterable(receiver) else receiver or ""
        )
        self.serde = serde
        self.return_result = return_result
        self.logger = logger
        self._receiver = {receiver} if receiver else set()

    def __str__(self) -> str:
        req_name = "rpc call" if self.return_result else "rpc_nowait"
        to_receiver = f" to {self.receiver}" if self.receiver else ""
        return f"{req_name}{to_receiver}"

    __repr__ = __str__

    def __getattr__(self, item: str) -> "_BoundRpc":
        """Return an immutable callable bound to *item* as the remote function name."""
        return _BoundRpc(self, item)

    def _process_rpc(self, func_name: str, *args, **kwargs):
        """Send a blocking RPC call and return the deserialised result."""
        conn_num = self.conn.client._conn_num
        data, is_bytes = Serializer.serialize(self.serde, *args, **kwargs)
        try:
            uuid, ts, found_receiver = dfcore.sendMessageFromClient(
                data,
                0,
                MessageFlag.REQUEST,
                self.serde,
                is_bytes,
                self.receiver,
                func_name,
                True,
                conn_num,
            )
        except (SystemError, ValueError):
            label = f"rpc call(fn: {func_name!r})"
            with system_exception_handler(
                f"Unable to proceed with {label}: {{}}", TransmissionFailure, conn_num
            ):
                raise
        if not found_receiver:
            members = (
                ""
                if not (_memebers := get_available_members(conn_num))
                else f"\nAvailable receivers: {_memebers}"
            )
            raise TransmissionFailure(
                f"No receivers found for rpc call(fn: {func_name!r})." + members
            )
        found_receivers = set(found_receiver.split(METADATA_SEPARATOR))
        if self._receiver and (missing_receivers := self._receiver - found_receivers):
            self.logger.warning(
                f"Receiver(s): {missing_receivers} seems to be offline."
            )
        data, flag, serde = RpcResult(
            conn_num=conn_num,
            uuid=uuid,
            ts=ts,
            timeout=self.timeout,
            receivers=found_receivers,
            proxy=self,
            serde=self.serde,
        ).result()
        return Serializer.deserialize(serde, data)[0][0]

    def _process_stream(self, func_name: str, *args, **kwargs):
        """Send one or more fire-and-forget messages without waiting for replies."""
        conn_num = self.conn.client._conn_num
        if args:
            data = args[0]
        elif kwargs:
            data = kwargs[next(iter(kwargs))]
        else:
            data = None
        if not iterable(data):
            items = [(args, kwargs)]
        else:
            items = iter(zip(data, repeat({})))
        label = f"rpc_nowait(fn: {func_name!r})"
        for a, k in items:
            data, is_bytes = Serializer.serialize(self.serde, *a, **k)
            with system_exception_handler(
                f"Unable to proceed with {label}: {{}}", TransmissionFailure, conn_num
            ):
                uuid, ts, found_receiver = send_message_from_client(
                    data=data,
                    flag=MessageFlag.REQUEST,
                    serde=self.serde,
                    receiver=self.receiver,
                    func_name=func_name,
                    return_result=self.return_result,
                    conn_num=conn_num,
                    is_bytes=is_bytes,
                )
            if not found_receiver:
                members = (
                    ""
                    if not (_memebers := get_available_members(conn_num))
                    else f"\nAvailable receivers: {_memebers}"
                )
                raise TransmissionFailure(f"No receivers found for {label}." + members)
            elif missing_receivers := self._receiver - set(
                found_receiver.split(METADATA_SEPARATOR)
            ):
                self.logger.warning(
                    f"Receiver(s): {missing_receivers} seems to be offline."
                )

    @classmethod
    def _process_client_handshake(cls, conn_num: int) -> dict:
        """Perform the initial client→server handshake and return the parsed
        JSON response (contains ``meta.type`` indicating router vs service).

        Args:
            conn_num: Native connection handle.

        Raises:
            TransmissionFailure: If the handshake times out or the native layer
                                 raises a ``SystemError``.
            InitializationError: If the server *rejected* the handshake — the
                                 only such case today is a duplicate
                                 ``app_name`` colliding with an existing,
                                 still-live peer.
        """
        with system_exception_handler(
            "unable to establish handshake: {}", TransmissionFailure
        ):
            data = METADATA_SEPARATOR.join([name for name, _ in EXECUTOR_REGISTRY])
            uuid, ts, found_receiver = send_handshake_from_client(
                methods=data,
                conn_num=conn_num,
            )
            try:
                data, _, _ = RpcResult(
                    conn_num=conn_num,
                    uuid=uuid,
                    ts=ts,
                    timeout=30,
                    receivers=None,
                    proxy=None,
                    serde=None,
                ).result()
                payload = json.loads(data)
            except CallTimeout:
                raise TransmissionFailure("Handshake failed due to timeout.")
            # ``meta.error`` is the server's policy-rejection signal
            # (currently: duplicate app_name).  Surface it on the same flag
            # the success path uses — no separate ERROR-flagged response.
            err = (payload.get("meta") or {}).get("error")
            if err:
                raise InitializationError(f"Handshake rejected by server: {err}")
            return payload

    @classmethod
    def _advertise_service_methods(cls, conn_num: int) -> None:
        """Publish this service's callback names before any client connects."""
        data = METADATA_SEPARATOR.join([name for name, _ in EXECUTOR_REGISTRY])
        set_service_methods(data, conn_num)

    @classmethod
    def _process_service_handshake(cls, conn_num: int) -> None:
        """Notify the native layer of this service's exported method names.

        Args:
            conn_num: Native connection handle.
        """
        cls._advertise_service_methods(conn_num)


class RpcResult:
    """Waits for the response to one request and returns ``(data, flag, serde)``."""

    # Longest single native wait.  Bounds how late a silent receiver
    # disconnect is noticed.
    _LIVENESS_INTERVAL = 1.0
    # Signal handlers run only once the main thread is back in Python, so it
    # waits in shorter slices to keep Ctrl+C prompt.
    _MAIN_THREAD_SLICE = 0.1

    def __init__(
        self,
        conn_num: int,
        uuid: int,
        ts: int,
        timeout: int,
        receivers: Optional[set] = None,
        proxy: Optional[RpcProxy] = None,
        serde: Optional[int] = None,
    ):
        self.conn_num = conn_num
        self.uuid = uuid
        self.send_ts = ts
        self.timeout = timeout
        self.receivers = receivers
        self.proxy = proxy
        self.serde = serde
        self._started = time.monotonic()

    def result(self) -> Tuple[bytes, int, int]:
        """Block until the response arrives and return ``(data, flag, serde)``.

        The wait itself happens in the native layer without the GIL.  Every
        exit other than a delivered response expires the uuid, so a late
        response is dropped instead of parked.

        Raises:
            RemoteCallError: If the remote returned an error payload.
            TransmissionFailure: If an expected receiver disconnected mid-call.
            Disconnected, Evicted: If the connection ended first.
            CallTimeout: If *timeout* seconds elapse with no response.
        """
        deadline = self._started + self.timeout if self.timeout > 0 else None
        step = (
            self._MAIN_THREAD_SLICE
            if threading.current_thread() is threading.main_thread()
            else self._LIVENESS_INTERVAL
        )
        check_at = self._started + self._LIVENESS_INTERVAL
        try:
            while True:
                wait = step
                if deadline is not None:
                    # Past the deadline this still takes a response that is
                    # already parked (e.g. a cast reply awaited late).
                    wait = max(0.0, min(wait, deadline - time.monotonic()))
                res = wait_message_from_client_store(
                    self.uuid, math.ceil(wait * 1000), self.conn_num
                )
                if res is None:
                    if deadline is not None and time.monotonic() >= deadline:
                        raise self._timeout()
                    if self.receivers and time.monotonic() >= check_at:
                        self._check_receivers()
                        check_at = time.monotonic() + self._LIVENESS_INTERVAL
                    continue
                break
        except BaseException:
            expire_message(self.uuid, self.conn_num)
            raise
        if isinstance(res, str):
            app_name = self.proxy.conn.client.app_name if self.proxy else None
            raise connection_lost_error(res == "evicted", app_name)
        return unpack_response(res, self.serde)

    def _timeout(self) -> CallTimeout:
        return CallTimeout(
            call=str(self.proxy) if self.proxy is not None else f"(uuid: {self.uuid})",
            timeout=self.timeout,
            elapsed=time.monotonic() - self._started,
            receivers=self.receivers or None,
        )

    def _check_receivers(self) -> None:
        current = {m["name"] for m in get_available_members(self.conn_num)}
        if missing_receivers := self.receivers - current:
            raise TransmissionFailure(
                f"The anticipated receivers(s) {missing_receivers}"
                f" unexpectedly disconnected, causing an interruption in the awaiting result of {self.proxy}."
                f" All receivers: {self.receivers}"
            )


class _BoundBroadcast:
    """Immutable callable returned by :meth:`BroadcastProxy.__getattr__`.

    Closes over ``func_name`` at creation time — the parent proxy is never
    mutated, making it safe to share across threads.
    """

    __slots__ = ("_proxy", "_func_name")

    def __init__(self, proxy: "BroadcastProxy", func_name: str) -> None:
        self._proxy = proxy
        self._func_name = func_name

    def __str__(self) -> str:
        kind = "cast" if self._proxy.return_result else "cast_nowait"
        return f"{kind}(fn: {self._func_name!r})"

    __repr__ = __str__

    def __call__(self, *args, **kwargs):
        self._proxy.conn._ensure_connected()
        if self._proxy.return_result:
            return self._proxy._process_call_all(self._func_name, *args, **kwargs)
        self._proxy._process_cast_all(self._func_name, *args, **kwargs)


class BroadcastProxy:
    """Lazy call builder returned by :meth:`~daffi.app.ClientConnection.cast`
    and :meth:`~daffi.app.ClientConnection.cast_nowait`.

    The proxy itself is **immutable** after construction.  :meth:`__getattr__`
    returns a :class:`_BoundBroadcast` that closes over the function name.

    * :meth:`~ClientConnection.cast` issues an rpc to each peer, waits for all
      responses, and returns a ``{peer_name: result_or_exception}`` dict.
    * :meth:`~ClientConnection.cast_nowait` fires-and-forgets — returns ``None`` immediately.

    Works with a single :class:`~daffi.app.Service` (one-key dict) as well as
    a :class:`~daffi.app.Router` backed by many workers.
    """

    def __init__(
        self,
        conn: "ClientConnection",
        timeout: Union[int, None],
        receiver: Union[str, List[str], None],
        serde: SerdeFormat,
        return_result: bool,
        logger: logging.Logger,
    ):
        self.conn = conn
        self.timeout = int(timeout or 0)
        self.serde = serde
        self.return_result = return_result
        self.logger = logger
        if receiver is None:
            self._explicit_receivers: Optional[List[str]] = None
        elif isinstance(receiver, str):
            self._explicit_receivers = [receiver]
        else:
            self._explicit_receivers = list(receiver)

    def __getattr__(self, item: str) -> "_BoundBroadcast":
        """Return an immutable callable bound to *item* as the remote function name."""
        return _BoundBroadcast(self, item)

    def _resolve_receivers(self, conn_num: int, func_name: str) -> List[str]:
        """Return the list of peer names to target.

        Uses the explicit list when provided; otherwise auto-discovers every
        connected peer that exposes *func_name*.
        """
        if self._explicit_receivers is not None:
            return self._explicit_receivers
        self_name = self.conn.client.app_name
        result = []
        for m in get_available_members(conn_num):
            name: str = m.get("name", "")
            # Skip ourselves — a client connected to a router receives its own
            # entry back in the member list and must not broadcast to itself.
            if name == self_name:
                continue
            methods = m.get("methods") or []
            if func_name in methods:
                result.append(name)
        return result

    def _process_call_all(self, func_name: str, *args, **kwargs) -> dict:
        """Fan out to all matching peers and collect ``{name: result}`` dict.

        Each peer's result is awaited individually.  If a peer raises an
        exception the exception object is stored as the dict value (rather
        than propagating immediately) so results from other peers are still
        returned.
        """
        conn_num = self.conn.client._conn_num
        data, is_bytes = Serializer.serialize(self.serde, *args, **kwargs)
        receivers = self._resolve_receivers(conn_num, func_name)
        if not receivers:
            available = [m["name"] for m in get_available_members(conn_num)]
            raise TransmissionFailure(
                f"No receivers found for call_all(fn={func_name!r})."
                + (f"\nAvailable peers: {available}" if available else "")
            )
        # Send to each receiver and collect (uuid → name) handles.
        pending: dict[str, RpcResult] = {}
        for receiver_name in receivers:
            with system_exception_handler(
                f"Unable to dispatch call_all to {receiver_name!r}: {{}}",
                TransmissionFailure,
                conn_num,
            ):
                uuid, ts, found = send_message_from_client(
                    data=data,
                    flag=MessageFlag.REQUEST,
                    serde=self.serde,
                    receiver=receiver_name,
                    func_name=func_name,
                    return_result=True,
                    conn_num=conn_num,
                    is_bytes=is_bytes,
                )
            if found:
                pending[receiver_name] = RpcResult(
                    conn_num=conn_num,
                    uuid=uuid,
                    ts=ts,
                    timeout=self.timeout,
                    receivers={receiver_name},
                    serde=self.serde,
                )
            else:
                self.logger.warning(
                    f"call_all: receiver {receiver_name!r} not reachable, skipping."
                )
        # Wait for every response and collect into a dict.
        results: dict = {}
        for name, rpc_result in pending.items():
            try:
                result_data, _, serde_r = rpc_result.result()
                results[name] = Serializer.deserialize(serde_r, result_data)[0][0]
            except Exception as exc:
                results[name] = exc
        return results

    def _process_cast_all(self, func_name: str, *args, **kwargs) -> None:
        """Fan out to all matching peers, fire-and-forget."""
        conn_num = self.conn.client._conn_num
        data, is_bytes = Serializer.serialize(self.serde, *args, **kwargs)
        receivers = self._resolve_receivers(conn_num, func_name)
        if not receivers:
            available = [m["name"] for m in get_available_members(conn_num)]
            raise TransmissionFailure(
                f"No receivers found for cast_all(fn={func_name!r})."
                + (f"\nAvailable peers: {available}" if available else "")
            )
        for receiver_name in receivers:
            with system_exception_handler(
                f"Unable to dispatch cast_all to {receiver_name!r}: {{}}",
                TransmissionFailure,
                conn_num,
            ):
                send_message_from_client(
                    data=data,
                    flag=MessageFlag.REQUEST,
                    serde=self.serde,
                    receiver=receiver_name,
                    func_name=func_name,
                    return_result=False,
                    conn_num=conn_num,
                    is_bytes=is_bytes,
                )


class _BoundStream:
    """Immutable callable returned by :meth:`_StreamBase.__getattr__`.

    Closes over ``func_name`` at creation time — the parent stream proxy is
    never mutated.  Subclassed by :class:`_BoundStreamBlocking` and
    :class:`_BoundStreamNowait` which implement the concrete ``__call__``.
    """

    __slots__ = ("_proxy", "_func_name")

    def __init__(self, proxy: "_StreamBase", func_name: str) -> None:
        self._proxy = proxy
        self._func_name = func_name

    def __str__(self) -> str:
        return (
            f"{self._proxy.__class__.__name__}(fn: {self._func_name!r},"
            f" receiver: {self._proxy.receiver!r})"
        )

    __repr__ = __str__


class _BoundStreamBlocking(_BoundStream):
    """Bound call for :class:`StreamProxy` — waits for ack per chunk."""

    def __call__(self, gen) -> None:
        self._proxy.conn._ensure_connected()
        conn_num = self._proxy.conn.client._conn_num
        chunks = gen if iterable(gen) else [gen]
        for chunk in chunks:
            uuid, ts, _ = self._proxy._send_chunk(
                self._func_name, conn_num, chunk, return_result=True
            )
            RpcResult(
                conn_num=conn_num,
                uuid=uuid,
                ts=ts,
                timeout=self._proxy.timeout,
                receivers=self._proxy._receiver or None,
                proxy=self._proxy,
                serde=self._proxy.serde,
            ).result()


class _BoundStreamNowait(_BoundStream):
    """Bound call for :class:`StreamNowaitProxy` — fire-and-forget per chunk."""

    def __call__(self, gen) -> None:
        self._proxy.conn._ensure_connected()
        conn_num = self._proxy.conn.client._conn_num
        chunks = gen if iterable(gen) else [gen]
        for chunk in chunks:
            self._proxy._send_chunk(
                self._func_name, conn_num, chunk, return_result=False
            )


class _StreamBase:
    """Shared init for the two stream proxy variants.

    The proxy itself is **immutable** after construction.  :meth:`__getattr__`
    is overridden by each subclass to return the appropriate bound object.
    """

    def __init__(
        self,
        conn: "ClientConnection",
        receiver: Union[str, None],
        serde: SerdeFormat,
        timeout: Union[int, None],
        logger: logging.Logger,
    ):
        self.conn = conn
        self.receiver = receiver or ""
        self.serde = serde
        self.timeout = int(timeout or 0)
        self.logger = logger
        self._receiver = {receiver} if receiver else set()

    def __str__(self) -> str:
        return f"{self.__class__.__name__}(receiver: {self.receiver!r})"

    __repr__ = __str__

    def _send_chunk(self, func_name: str, conn_num: int, chunk, return_result: bool):
        """Serialise and send one chunk; return (uuid, ts, found_receiver)."""
        label = f"{self.__class__.__name__}(fn: {func_name!r})"
        data, is_bytes = Serializer.serialize(self.serde, chunk)
        with system_exception_handler(
            f"Unable to stream to {label}: {{}}", TransmissionFailure, conn_num
        ):
            uuid, ts, found_receiver = send_message_from_client(
                data=data,
                flag=MessageFlag.REQUEST,
                serde=self.serde,
                receiver=self.receiver,
                func_name=func_name,
                return_result=return_result,
                conn_num=conn_num,
                is_bytes=is_bytes,
            )
        if not found_receiver:
            members = (
                ""
                if not (_members := get_available_members(conn_num))
                else f"\nAvailable receivers: {_members}"
            )
            raise TransmissionFailure(f"No receiver found for {label}." + members)
        elif missing := self._receiver - set(found_receiver.split(METADATA_SEPARATOR)):
            self.logger.warning(f"Receiver(s) {missing} seem to be offline.")
        return uuid, ts, found_receiver


class StreamProxy(_StreamBase):
    """Lazy call builder returned by :meth:`~ClientConnection.stream`.

    Iterates a generator and sends each chunk as a **blocking** RPC call —
    the client waits for the remote callback to complete before sending the
    next chunk.  This provides natural backpressure: the producer can never
    get ahead of the consumer.

    The callback's return value is discarded; only the ack matters::

        def data_source():
            for i in range(5):
                yield f"chunk-{i}".encode()

        conn.stream(serde=SerdeFormat.OPAQUE).receive_chunk(data_source())
    """

    def __getattr__(self, item: str) -> "_BoundStreamBlocking":
        return _BoundStreamBlocking(self, item)


class StreamNowaitProxy(_StreamBase):
    """Lazy call builder returned by :meth:`~ClientConnection.stream_nowait`.

    Iterates a generator and sends each chunk as a **fire-and-forget** message —
    no acknowledgement is waited for.  The producer can outpace the consumer;
    use this only when you control the rate yourself or can tolerate queue build-up::

        conn.stream_nowait(serde=SerdeFormat.OPAQUE).receive_chunk(data_source())
    """

    def __getattr__(self, item: str) -> "_BoundStreamNowait":
        return _BoundStreamNowait(self, item)


class ClientConnection:
    """Proxy returned by :meth:`~daffi.app.Client.connect`.

    Six call styles are available:

    * :meth:`rpc`            — one worker, blocking, returns result
    * :meth:`rpc_nowait`     — one worker, fire-and-forget
    * :meth:`cast`           — all matching workers, blocking, returns ``{name: result}``
    * :meth:`cast_nowait`    — all matching workers, fire-and-forget
    * :meth:`stream`         — iterate a generator, wait for ack per chunk (backpressure)
    * :meth:`stream_nowait`  — iterate a generator, fire-and-forget per chunk (no backpressure)

    Example::

        conn = client.connect()

        result = conn.rpc(timeout=5).add(1, 2)
        conn.rpc_nowait().log_event(payload)
        results = conn.cast().add(1, 2)           # {"worker-1": 3, "worker-2": 3}
        conn.cast_nowait().invalidate_cache(key)

        # Blocking stream — waits for ack per chunk (safe, natural backpressure)
        conn.stream(serde=SerdeFormat.OPAQUE).receive_chunk(data_source())

        # Fire-and-forget stream — no ack, user controls rate
        conn.stream_nowait(serde=SerdeFormat.OPAQUE).receive_chunk(data_source())
    """

    def __init__(self, client: "Client"):
        self.client = client

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _ensure_connected(self) -> None:
        """Detect a background disconnect and attempt one reconnect.

        Called at the start of every outgoing call (rpc, cast, stream …).
        When the client is healthy this is a single attribute read and
        immediate return.  When a background disconnect was flagged it logs,
        attempts one :meth:`~daffi.app.Client._try_reconnect`, and raises
        :exc:`~daffi.exceptions.TransmissionFailure` if the attempt fails so
        callers always get an actionable error instead of a cryptic
        native-layer message.
        """
        client = self.client
        if not client._disconnected:
            return
        if isinstance(client._connection_error, Evicted):
            # Reconnecting would evict the connection that took the name.
            raise client._connection_error
        client.logger.info(
            "Connection was lost in the background; attempting one reconnect..."
        )
        if not client._try_reconnect():
            raise TransmissionFailure(
                "Client was disconnected and the reconnect attempt failed."
            )

    # ------------------------------------------------------------------
    # Primary API
    # ------------------------------------------------------------------

    def rpc(
        self,
        timeout: Union[int, None] = None,
        receiver: Union[str, None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> RpcProxy:
        """Configure a **blocking** call to a single worker and return a proxy.

        The proxy executes the actual remote call when you access an attribute
        and call it::

            result = conn.rpc(timeout=5).add(1, 2)

        Args:
            timeout:  Seconds to wait for the response.  ``None`` (or ``0``)
                      means wait indefinitely.
            receiver: Name of the target worker.  ``None`` picks a worker
                      using round-robin among all peers that expose the
                      requested method.
            serde:    Serialisation format.  Defaults to
                      :attr:`~daffi.serialization.SerdeFormat.PICKLE`.

        Example::

            result = conn.rpc(timeout=10).add(1, 2)         # any worker
            result = conn.rpc(receiver="w1").add(1, 2)      # pinned worker
        """
        return RpcProxy(
            conn=self,
            timeout=timeout,
            receiver=receiver,
            serde=serde,
            return_result=True,
            logger=self.client.logger,
        )

    def rpc_nowait(
        self,
        receiver: Union[str, None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> RpcProxy:
        """Configure a **fire-and-forget** call to a single worker and return a proxy.

        Returns immediately without waiting for the remote callback to complete.
        No result is returned.

        Args:
            receiver: Name of the target worker.  ``None`` picks one using
                      round-robin.
            serde:    Serialisation format.  Defaults to
                      :attr:`~daffi.serialization.SerdeFormat.PICKLE`.

        Example::

            conn.rpc_nowait().log_event(payload)
            conn.rpc_nowait(receiver="worker-1").notify(msg)
        """
        return RpcProxy(
            conn=self,
            timeout=None,
            receiver=receiver,
            serde=serde,
            return_result=False,
            logger=self.client.logger,
        )

    def cast(
        self,
        timeout: Union[int, None] = None,
        receiver: Union[str, List[str], None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> BroadcastProxy:
        """Configure a **blocking broadcast** to all matching workers and return a proxy.

        Every peer that exposes the requested method receives an rpc call.
        All responses are collected and returned as a ``{worker_name: result}``
        dict.  If a worker raises an exception its exception object is stored
        as the value so other workers' results are still available.

        Works with a single :class:`~daffi.app.Service` too — the dict will
        simply have one key.

        Args:
            timeout:  Per-worker timeout in seconds.  ``None`` waits forever.
            receiver: Explicit target name(s).  ``None`` auto-discovers all
                      peers that expose the method.
            serde:    Serialisation format.

        Example::

            results = conn.cast().add(1, 2)
            # {"worker-1": 3, "worker-2": 3}

            results = conn.cast(receiver=["w1", "w2"]).ping()
        """
        return BroadcastProxy(
            conn=self,
            timeout=timeout,
            receiver=receiver,
            serde=serde,
            return_result=True,
            logger=self.client.logger,
        )

    def cast_nowait(
        self,
        receiver: Union[str, List[str], None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> BroadcastProxy:
        """Configure a **fire-and-forget broadcast** to all matching workers and return a proxy.

        Every peer that exposes the requested method receives the call.  No
        responses are waited for.

        Args:
            receiver: Explicit target name(s).  ``None`` auto-discovers all
                      peers that expose the method.
            serde:    Serialisation format.

        Example::

            conn.cast_nowait().invalidate_cache(key)
            conn.cast_nowait(receiver=["w1", "w2"]).shutdown()
        """
        return BroadcastProxy(
            conn=self,
            timeout=None,
            receiver=receiver,
            serde=serde,
            return_result=False,
            logger=self.client.logger,
        )

    def stream(
        self,
        receiver: Union[str, None] = None,
        serde: SerdeFormat = SerdeFormat.OPAQUE,
        timeout: Union[int, None] = None,
    ) -> StreamProxy:
        """Stream a generator to a remote callback with **per-chunk backpressure**.

        Sends each yielded value as a blocking RPC and waits for the remote
        callback to complete before sending the next chunk.  This prevents
        the producer from outpacing the consumer and keeps the service queue
        at most one message deep.

        The callback's return value is discarded — only the acknowledgement
        matters.

        Args:
            receiver: Pin to a specific worker by name.  ``None`` picks one
                      using round-robin.
            serde:    Serialisation format.  Defaults to
                      :attr:`~daffi.serialization.SerdeFormat.OPAQUE`.
            timeout:  Seconds to wait per chunk before raising
                      :exc:`TimeoutError`.  ``None`` waits forever.

        Example::

            def data_source():
                for i in range(5):
                    yield f"chunk-{i}".encode()

            conn.stream(serde=SerdeFormat.OPAQUE).receive_chunk(data_source())
        """
        return StreamProxy(
            conn=self,
            receiver=receiver,
            serde=serde,
            timeout=timeout,
            logger=self.client.logger,
        )

    def stream_nowait(
        self,
        receiver: Union[str, None] = None,
        serde: SerdeFormat = SerdeFormat.OPAQUE,
    ) -> StreamNowaitProxy:
        """Stream a generator to a remote callback **fire-and-forget** (no backpressure).

        Sends each yielded value without waiting for the remote callback to
        complete.  The producer can outpace the consumer; messages accumulate
        in the service queue.  Use this only when you control the rate
        yourself or when losing messages is acceptable.

        Args:
            receiver: Pin to a specific worker by name.  ``None`` picks one
                      using round-robin.
            serde:    Serialisation format.  Defaults to
                      :attr:`~daffi.serialization.SerdeFormat.OPAQUE`.

        Example::

            conn.stream_nowait(serde=SerdeFormat.OPAQUE).receive_chunk(data_source())
        """
        return StreamNowaitProxy(
            conn=self,
            receiver=receiver,
            serde=serde,
            timeout=None,
            logger=self.client.logger,
        )

    def wait_for_members(
        self,
        *members: str,
        timeout: Union[float, None] = None,
        interval: float = 1.0,
    ) -> None:
        """Block until all requested members are visible in the network.

        Polls the native ChannelsMapper every *interval* seconds and returns
        as soon as every requested peer name appears in the member list.  Use
        this to synchronise a multi-worker environment before issuing RPC calls
        that require specific peers to be online.

        Args:
            *members: One or more peer names to wait for.
            timeout:  Maximum seconds to wait.  ``None`` (default) waits
                      indefinitely.  Raises :exc:`TimeoutError` when exceeded.
            interval: Poll interval in seconds.  Default ``1.0``.

        Raises:
            TimeoutError: When *timeout* is set and not all members appeared
                          within that time.

        Example::

            conn = client.connect()

            # Wait until both workers are online before issuing any calls.
            conn.wait_for_members("worker-1", "worker-2")

            # With a deadline — raises TimeoutError after 30 s.
            conn.wait_for_members("worker-1", timeout=30)
        """
        if not members:
            return
        needed = set(members)
        start = time.monotonic()
        while True:
            raw = get_available_members(self.client._conn_num)
            current = {m["name"] for m in raw}
            if needed.issubset(current):
                return
            if timeout is not None and (time.monotonic() - start) >= timeout:
                missing = needed - current
                raise TimeoutError(
                    f"Timed out after {timeout}s waiting for members: {missing}"
                )
            time.sleep(interval)
