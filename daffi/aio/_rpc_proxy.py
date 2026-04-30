"""
Async RPC proxies and the :class:`AsyncClientConnection` handle returned by
:meth:`~daffi.aio.app.AsyncClient.connect`.

Design notes
------------
``AsyncResponseNotifier``
    Replaces the sync :class:`~daffi._rpc_proxy.ResponseNotifier`.  A
    permanent ``loop.add_reader`` callback signals an ``asyncio.Condition``
    whenever Zig writes to the response fd.  Multiple concurrent
    ``AsyncRpcResult`` waiters all subscribe to that condition — the same
    fd, zero conflicts.

``AsyncRpcResult``
    Awaits the condition (with a liveness-check timeout cap) instead of
    blocking in ``select.select``.

Proxy classes (``AsyncRpcProxy``, ``AsyncBroadcastProxy``, ``AsyncStreamProxy``,
``AsyncStreamNowaitProxy``)
    All ``__call__`` methods are ``async def``; otherwise the logic mirrors the
    sync counterparts verbatim.
"""

from __future__ import annotations

import asyncio
import json
import time
import logging
import threading
from itertools import repeat
from typing import TYPE_CHECKING, Union, List, Optional, Tuple
from contextlib import contextmanager

if TYPE_CHECKING:
    from daffi.aio.app import AsyncClient

from daffi._serialization import SerdeFormat, Serializer
from daffi.exceptions import (
    CallTimeout,
    TransmissionFailure,
    RemoteCallError,
    InitializationError,
)
from daffi.utils.misc import iterable
from daffi._wakeup import WakeupFd
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._bindings import (
    send_message_from_client,
    get_message_from_client_store,
    mark_message_as_expired,
    set_service_methods,
    send_handshake_from_client,
    set_response_fd,
    get_available_members,
    MessageFlag,
)
from daffi._rpc_proxy import (
    METADATA_SEPARATOR,
    system_exception_handler,
    RpcResult,          # _unpack_response is reused as a classmethod
)


# ---------------------------------------------------------------------------
# AsyncResponseNotifier
# ---------------------------------------------------------------------------

class AsyncResponseNotifier:
    """Per-connection async response notifier.

    A single permanent ``loop.add_reader`` watches the native wakeup fd.
    When Zig signals a new response, every waiting :class:`AsyncRpcResult`
    is notified via its own ``asyncio.Event`` — one event per waiter, no
    shared lock, no interaction issues with ``asyncio.wait_for``.

    Class-level registry mirrors :class:`~daffi._rpc_proxy.ResponseNotifier`
    so the rest of the code can switch between the two transparently.
    """

    _instances: dict[int, "AsyncResponseNotifier"] = {}
    _instances_lock = threading.Lock()

    def __init__(self, conn_num: int, loop: asyncio.AbstractEventLoop) -> None:
        self._conn_num = conn_num
        self._wakeup = WakeupFd()
        self._lifecycle_error: Optional[Exception] = None
        self._loop = loop
        # Each active waiter registers its own Event here.
        self._waiters: list[asyncio.Event] = []
        self._waiters_lock = threading.Lock()
        set_response_fd(conn_num, self._wakeup.write_fd)
        loop.add_reader(self._wakeup.read_fd, self._on_readable)

    # ------------------------------------------------------------------
    # Internal notification pipeline
    # ------------------------------------------------------------------

    def _on_readable(self) -> None:
        """Called on the event-loop thread when the response fd fires."""
        self._wakeup.drain()
        # Set every registered waiter event from the event-loop thread.
        # asyncio.Event.set() is thread-safe when called from the same
        # thread as the running loop (which is the case here, since
        # add_reader callbacks run on the loop thread).
        with self._waiters_lock:
            for ev in self._waiters:
                ev.set()

    # ------------------------------------------------------------------
    # Waiter API (used by AsyncRpcResult)
    # ------------------------------------------------------------------

    async def wait(self, timeout: Optional[float] = None) -> bool:
        """Suspend until Zig signals a new response (or *timeout* elapses).

        Each caller gets its own ``asyncio.Event`` that is set by
        ``_on_readable`` — no shared lock, no ``asyncio.Condition``
        interaction issues with ``asyncio.wait_for``.

        Returns:
            ``True`` if woken by a signal, ``False`` if *timeout* elapsed.
        """
        ev = asyncio.Event()
        with self._waiters_lock:
            self._waiters.append(ev)
        signaled = False
        try:
            try:
                await asyncio.wait_for(ev.wait(), timeout=timeout)
                signaled = True
            except (asyncio.TimeoutError, TimeoutError):
                pass
        finally:
            with self._waiters_lock:
                try:
                    self._waiters.remove(ev)
                except ValueError:
                    pass
        return signaled

    # ------------------------------------------------------------------
    # Class-level registry
    # ------------------------------------------------------------------

    @classmethod
    def register(cls, conn_num: int) -> "AsyncResponseNotifier":
        """Create and register a notifier, closing any stale one first."""
        loop = asyncio.get_running_loop()
        with cls._instances_lock:
            old = cls._instances.pop(conn_num, None)
        if old is not None:
            old.close()
        notifier = cls(conn_num, loop)
        with cls._instances_lock:
            cls._instances[conn_num] = notifier
        return notifier

    @classmethod
    def unregister(cls, conn_num: int) -> None:
        """Close and forget the notifier for *conn_num*."""
        with cls._instances_lock:
            n = cls._instances.pop(conn_num, None)
        if n is not None:
            n.close()

    @classmethod
    def for_conn(cls, conn_num: int) -> Optional["AsyncResponseNotifier"]:
        with cls._instances_lock:
            return cls._instances.get(conn_num)

    @classmethod
    def signal_lifecycle_error(cls, conn_num: int, err: Exception) -> None:
        """Wake all waiters with a lifecycle error (disconnect / eviction)."""
        with cls._instances_lock:
            n = cls._instances.get(conn_num)
        if n is None:
            return
        n._lifecycle_error = err
        # Wake every waiting AsyncRpcResult so it re-checks _lifecycle_error.
        with n._waiters_lock:
            for ev in n._waiters:
                ev.set()

    def close(self) -> None:
        """Release the wakeup fd and remove the reader."""
        try:
            self._loop.remove_reader(self._wakeup.read_fd)
        except Exception:
            pass
        try:
            self._wakeup.close()
        except Exception:
            pass


# ---------------------------------------------------------------------------
# AsyncRpcResult
# ---------------------------------------------------------------------------

class AsyncRpcResult:
    """Async counterpart of :class:`~daffi._rpc_proxy.RpcResult`.

    ``await result.result()`` waits on :class:`AsyncResponseNotifier`'s
    ``asyncio.Condition`` instead of blocking in ``select.select``.
    """

    _LIVENESS_INTERVAL = RpcResult._LIVENESS_INTERVAL
    _FALLBACK_POLL_INTERVAL = RpcResult._FALLBACK_POLL_INTERVAL

    def __init__(
        self,
        conn_num: int,
        uuid: int,
        ts: int,
        timeout: int,
        receivers: Optional[set] = None,
        proxy=None,
    ) -> None:
        self.conn_num = conn_num
        self.uuid = uuid
        self.send_ts = ts
        self.timeout = timeout
        self.receivers = receivers
        self.proxy = proxy

    async def result(self) -> Tuple[bytes, int, int]:
        """Await the response and return ``(data, flag, serde)``."""
        notifier = AsyncResponseNotifier.for_conn(self.conn_num)
        deadline = (self.send_ts + self.timeout) if self.timeout > 0 else None

        while True:
            # 1. Check message store first (response may already be there).
            if res := get_message_from_client_store(self.uuid, self.conn_num):
                return self._unpack_response(res)

            # 2. Raise lifecycle error when there is nothing waiting in store.
            if notifier is not None and (
                _err := notifier._lifecycle_error
            ) is not None:
                notifier._lifecycle_error = None
                raise _err

            # 3. Deadline check.
            remaining = (deadline - time.time()) if deadline else None
            if remaining is not None and remaining <= 0:
                mark_message_as_expired(self.uuid, self.conn_num)
                raise CallTimeout(
                    call=str(self.proxy) if self.proxy else f"(uuid: {self.uuid})",
                    timeout=self.timeout,
                    elapsed=time.time() - self.send_ts,
                    receivers=self.receivers or None,
                )

            # 4. Compute how long to wait this iteration.
            if remaining is None:
                wait_chunk = self._LIVENESS_INTERVAL if self.receivers else None
            elif self.receivers:
                wait_chunk = min(remaining, self._LIVENESS_INTERVAL)
            else:
                wait_chunk = remaining

            # 5. Wait for a Zig signal or a timeout.
            signaled = True
            if notifier is not None:
                signaled = await notifier.wait(timeout=wait_chunk)
            else:
                interval = (
                    self._FALLBACK_POLL_INTERVAL
                    if wait_chunk is None
                    else min(wait_chunk, self._FALLBACK_POLL_INTERVAL)
                )
                await asyncio.sleep(interval)
                signaled = False

            # 6. After waking, loop back to step 1 to check the store.
            # NOTE: Do NOT call get_message_from_client_store here — the
            # native store is a destructive pop-on-read; a second call would
            # consume the response before step 1 in the next iteration sees it.
            #
            # Liveness check: only when we timed out (not signaled) and we
            # have a fixed receiver — detect a disconnected peer early.
            if not signaled and self.receivers:
                if missing := self.receivers - {
                    m["name"] for m in get_available_members(self.conn_num)
                }:
                    raise TransmissionFailure(
                        f"The anticipated receivers(s) {missing} unexpectedly"
                        f" disconnected, causing an interruption in the awaiting"
                        f" result of {self.proxy}."
                        f" All receivers: {self.receivers}"
                    )

    @staticmethod
    def _unpack_response(res: Tuple) -> Tuple[bytes, int, int]:
        """Decode a native store tuple — mirrors :meth:`RpcResult._unpack_response`."""
        if len(res) == 1:
            raise RemoteCallError(f"Unexpected response: {res[0]}")
        data, flag, serde = res
        if flag == MessageFlag.ERROR:
            (error_tuple,), _ = Serializer.deserialize(serde, data)
            err_name, err_module, err_msg, tb = error_tuple
            restored_exc = type(
                err_name, (RemoteCallError,), {"__module__": err_module}
            )
            if tb:
                raise restored_exc(err_msg).with_traceback(tb)
            else:
                raise restored_exc(err_msg)
        return data, flag, serde


# ---------------------------------------------------------------------------
# _AsyncBoundRpc — immutable single-call object returned by AsyncRpcProxy.__getattr__
# ---------------------------------------------------------------------------

class _AsyncBoundRpc:
    """Immutable callable that wraps one (proxy, func_name) pair.

    Created by :meth:`AsyncRpcProxy.__getattr__` and immediately awaited::

        await proxy.multiply(6, 7)
        # __getattr__('multiply') → _AsyncBoundRpc(proxy, 'multiply')
        # _AsyncBoundRpc.__call__(6, 7) → sends the RPC

    Because ``func_name`` is stored on *this* object (not on the shared proxy),
    any number of these can be created from the same proxy and gathered
    concurrently without race conditions.
    """

    __slots__ = ("_proxy", "_func_name")

    def __init__(self, proxy: "AsyncRpcProxy", func_name: str) -> None:
        self._proxy = proxy
        self._func_name = func_name

    def __str__(self) -> str:
        req_name = "rpc call" if self._proxy.return_result else "rpc_nowait"
        to_receiver = f" to {self._proxy.receiver}" if self._proxy.receiver else ""
        return f"{req_name}{to_receiver}(fn: {self._func_name!r})"

    __repr__ = __str__

    async def __call__(self, *args, **kwargs):
        await self._proxy.conn._ensure_connected()
        if self._proxy.return_result:
            return await self._proxy._process_rpc(self._func_name, *args, **kwargs)
        else:
            await self._proxy._process_stream(self._func_name, *args, **kwargs)


# ---------------------------------------------------------------------------
# AsyncRpcProxy
# ---------------------------------------------------------------------------

class AsyncRpcProxy:
    """Async lazy call builder returned by :meth:`~AsyncClientConnection.rpc`
    and :meth:`~AsyncClientConnection.rpc_nowait`.

    Attribute access returns a lightweight :class:`_AsyncBoundRpc` object that
    closes over the function name at capture time.  The proxy itself is never
    mutated after construction, so the same instance can be shared safely
    across any number of concurrent coroutines::

        proxy = conn.rpc(timeout=5)
        # All three coroutines are safe to gather — no shared mutable state:
        results = await asyncio.gather(
            proxy.echo("a"),
            proxy.echo("b"),
            proxy.multiply(3, 4),
        )
    """

    def __init__(
        self,
        conn: "AsyncClientConnection",
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

    def __getattr__(self, item: str) -> "_AsyncBoundRpc":
        # Return a new immutable callable that closes over `item` by value.
        # The proxy itself is NOT mutated — concurrent coroutines that hold a
        # reference to this proxy are completely isolated from each other.
        return _AsyncBoundRpc(self, item)

    async def _process_rpc(self, func_name: str, *args, **kwargs):
        conn_num = self.conn.client._conn_num
        data, is_bytes = Serializer.serialize(self.serde, *args, **kwargs)
        label = f"rpc call(fn: {func_name!r})"
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
        found_receivers = (
            None
            if not found_receiver
            else set(found_receiver.split(METADATA_SEPARATOR))
        )
        if not found_receivers:
            members = (
                ""
                if not (_m := get_available_members(conn_num))
                else f"\nAvailable receivers: {_m}"
            )
            raise TransmissionFailure(f"No receivers found for {label}." + members)
        elif missing := self._receiver - found_receivers:
            self.logger.warning(f"Receiver(s): {missing} seems to be offline.")
        result = AsyncRpcResult(
            conn_num=conn_num,
            uuid=uuid,
            ts=ts,
            timeout=self.timeout,
            receivers=found_receivers,
            proxy=self,
        )
        data, flag, serde = await result.result()
        return Serializer.deserialize(serde, data)[0][0]

    async def _process_stream(self, func_name: str, *args, **kwargs):
        conn_num = self.conn.client._conn_num
        if args:
            data = args[0]
        elif kwargs:
            data = kwargs[next(iter(kwargs))]
        else:
            data = None
        items = [(args, kwargs)] if not iterable(data) else iter(zip(data, repeat({})))
        label = f"rpc_nowait(fn: {func_name!r})"
        for a, k in items:
            payload, is_bytes = Serializer.serialize(self.serde, *a, **k)
            with system_exception_handler(
                f"Unable to proceed with {label}: {{}}", TransmissionFailure, conn_num
            ):
                uuid, ts, found_receiver = send_message_from_client(
                    data=payload,
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
                    if not (_m := get_available_members(conn_num))
                    else f"\nAvailable receivers: {_m}"
                )
                raise TransmissionFailure(f"No receivers found for {label}." + members)
            elif missing := self._receiver - set(
                found_receiver.split(METADATA_SEPARATOR)
            ):
                self.logger.warning(f"Receiver(s) {missing} seems to be offline.")

    @classmethod
    def _process_client_handshake(cls, conn_num: int) -> dict:
        """Sync handshake — delegates to the sync ``RpcProxy`` implementation.

        Called via ``loop.run_in_executor`` so it does not block the event
        loop.  The :class:`AsyncResponseNotifier` is already registered before
        this runs, so the notifier's ``add_reader`` fires when Zig responds.
        However, inside the executor thread the sync :class:`RpcResult` is
        used (which polls via ``select.select``) — this is correct because
        ``run_in_executor`` runs in a thread separate from the event loop.
        """
        from daffi._rpc_proxy import RpcProxy as _SyncRpcProxy
        return _SyncRpcProxy._process_client_handshake(conn_num)


# ---------------------------------------------------------------------------
# _AsyncBoundBroadcast — immutable callable returned by AsyncBroadcastProxy.__getattr__
# ---------------------------------------------------------------------------

class _AsyncBoundBroadcast:
    """Immutable callable that wraps one (broadcast_proxy, func_name) pair.

    Created by :meth:`AsyncBroadcastProxy.__getattr__` — func_name is frozen
    at capture time so concurrent coroutines are fully isolated.
    """

    __slots__ = ("_proxy", "_func_name")

    def __init__(self, proxy: "AsyncBroadcastProxy", func_name: str) -> None:
        self._proxy = proxy
        self._func_name = func_name

    def __str__(self) -> str:
        kind = "cast" if self._proxy.return_result else "cast_nowait"
        return f"{kind}(fn: {self._func_name!r})"

    __repr__ = __str__

    async def __call__(self, *args, **kwargs):
        await self._proxy.conn._ensure_connected()
        if self._proxy.return_result:
            return await self._proxy._process_call_all(self._func_name, *args, **kwargs)
        await self._proxy._process_cast_all(self._func_name, *args, **kwargs)


# ---------------------------------------------------------------------------
# AsyncBroadcastProxy
# ---------------------------------------------------------------------------

class AsyncBroadcastProxy:
    """Async counterpart of :class:`~daffi._rpc_proxy.BroadcastProxy`.

    The proxy itself is immutable after construction.  :meth:`__getattr__`
    returns a :class:`_AsyncBoundBroadcast` that closes over the function name,
    so the same proxy can be shared across concurrent coroutines safely.
    """

    def __init__(
        self,
        conn: "AsyncClientConnection",
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

    def __getattr__(self, item: str) -> "_AsyncBoundBroadcast":
        return _AsyncBoundBroadcast(self, item)

    def _resolve_receivers(self, conn_num: int, func_name: str) -> List[str]:
        if self._explicit_receivers is not None:
            return self._explicit_receivers
        self_name = self.conn.client.app_name
        result = []
        for m in get_available_members(conn_num):
            name: str = m.get("name", "")
            if name == self_name:
                continue
            if func_name in (m.get("methods") or []):
                result.append(name)
        return result

    async def _process_call_all(self, func_name: str, *args, **kwargs) -> dict:
        conn_num = self.conn.client._conn_num
        data, is_bytes = Serializer.serialize(self.serde, *args, **kwargs)
        receivers = self._resolve_receivers(conn_num, func_name)
        if not receivers:
            available = [m["name"] for m in get_available_members(conn_num)]
            raise TransmissionFailure(
                f"No receivers found for call_all(fn={func_name!r})."
                + (f"\nAvailable peers: {available}" if available else "")
            )
        pending: dict[str, AsyncRpcResult] = {}
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
                pending[receiver_name] = AsyncRpcResult(
                    conn_num=conn_num,
                    uuid=uuid,
                    ts=ts,
                    timeout=self.timeout,
                    receivers={receiver_name},
                )
            else:
                self.logger.warning(
                    f"call_all: receiver {receiver_name!r} not reachable, skipping."
                )
        results: dict = {}
        for name, rpc_result in pending.items():
            try:
                result_data, _, serde_r = await rpc_result.result()
                results[name] = Serializer.deserialize(serde_r, result_data)[0][0]
            except Exception as exc:
                results[name] = exc
        return results

    async def _process_cast_all(self, func_name: str, *args, **kwargs) -> None:
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


# ---------------------------------------------------------------------------
# Async stream proxies
# ---------------------------------------------------------------------------

class _AsyncStreamBase:
    """Shared init for the two async stream variants.

    Like :class:`AsyncRpcProxy`, the stream proxy itself is immutable after
    construction.  :meth:`__getattr__` returns a :class:`_AsyncBoundStream`
    that closes over the function name — safe to use concurrently.
    """

    def __init__(
        self,
        conn: "AsyncClientConnection",
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

    def __getattr__(self, item: str) -> "_AsyncBoundStream":
        return _AsyncBoundStream(self, item)

    async def _send_chunk(
        self, func_name: str, conn_num: int, chunk, return_result: bool
    ) -> Tuple[int, int, str]:
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
                if not (_m := get_available_members(conn_num))
                else f"\nAvailable receivers: {_m}"
            )
            raise TransmissionFailure(f"No receiver found for {label}." + members)
        elif missing := self._receiver - set(found_receiver.split(METADATA_SEPARATOR)):
            self.logger.warning(f"Receiver(s) {missing} seem to be offline.")
        return uuid, ts, found_receiver


class _AsyncBoundStream:
    """Immutable callable returned by :meth:`_AsyncStreamBase.__getattr__`.

    Closes over ``func_name`` at creation time — concurrent streams on the
    same parent proxy don't share any mutable state.
    """

    __slots__ = ("_proxy", "_func_name")

    def __init__(self, proxy: "_AsyncStreamBase", func_name: str) -> None:
        self._proxy = proxy
        self._func_name = func_name

    def __str__(self) -> str:
        return (
            f"{self._proxy.__class__.__name__}(fn: {self._func_name!r},"
            f" receiver: {self._proxy.receiver!r})"
        )

    __repr__ = __str__

    async def __call__(self, gen) -> None:
        raise NotImplementedError("Use AsyncStreamProxy or AsyncStreamNowaitProxy.")


class AsyncStreamProxy(_AsyncStreamBase):
    """Async backpressure stream — waits for ack before sending next chunk::

        await conn.stream().receive_chunk(data_source())
    """

    def __getattr__(self, item: str) -> "_AsyncBoundStreamBlocking":
        return _AsyncBoundStreamBlocking(self, item)


class _AsyncBoundStreamBlocking(_AsyncBoundStream):
    """Bound call for :class:`AsyncStreamProxy` — awaits each chunk ack."""

    async def __call__(self, gen) -> None:  # type: ignore[override]
        await self._proxy.conn._ensure_connected()
        conn_num = self._proxy.conn.client._conn_num
        chunks = gen if iterable(gen) else [gen]
        for chunk in chunks:
            uuid, ts, _ = await self._proxy._send_chunk(
                self._func_name, conn_num, chunk, return_result=True
            )
            await AsyncRpcResult(
                conn_num=conn_num,
                uuid=uuid,
                ts=ts,
                timeout=self._proxy.timeout,
                receivers=self._proxy._receiver or None,
                proxy=self._proxy,
            ).result()


class AsyncStreamNowaitProxy(_AsyncStreamBase):
    """Async fire-and-forget stream — sends each chunk without waiting::

        await conn.stream_nowait().receive_chunk(data_source())
    """

    def __getattr__(self, item: str) -> "_AsyncBoundStreamNowait":
        return _AsyncBoundStreamNowait(self, item)


class _AsyncBoundStreamNowait(_AsyncBoundStream):
    """Bound call for :class:`AsyncStreamNowaitProxy` — fire-and-forget."""

    async def __call__(self, gen) -> None:  # type: ignore[override]
        await self._proxy.conn._ensure_connected()
        conn_num = self._proxy.conn.client._conn_num
        chunks = gen if iterable(gen) else [gen]
        for chunk in chunks:
            await self._proxy._send_chunk(
                self._func_name, conn_num, chunk, return_result=False
            )


# ---------------------------------------------------------------------------
# AsyncClientConnection
# ---------------------------------------------------------------------------

class AsyncClientConnection:
    """Async proxy returned by :meth:`~daffi.aio.app.AsyncClient.connect`.

    Mirrors :class:`~daffi._rpc_proxy.ClientConnection` but every call style
    returns a coroutine::

        result = await conn.rpc(timeout=5).multiply(6, 7)
        await conn.rpc_nowait().log_event(payload)
        results = await conn.cast().multiply(6, 7)   # {worker: result}
        await conn.cast_nowait().invalidate_cache(key)
        await conn.stream().receive_chunk(data_source())
        await conn.stream_nowait().receive_chunk(data_source())
    """

    def __init__(self, client: "AsyncClient") -> None:
        self.client = client

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _ensure_connected(self) -> None:
        """Detect a background disconnect and attempt one reconnect."""
        client = self.client
        if not client._disconnected:
            return
        client.logger.info(
            "Connection was lost in the background; attempting one reconnect..."
        )
        if not await client._try_reconnect():
            raise TransmissionFailure(
                "Client was disconnected and the reconnect attempt failed."
            )

    # ------------------------------------------------------------------
    # Event handler registration (delegates to the underlying client)
    # ------------------------------------------------------------------

    def on_member_added(self, handler):
        """Register *handler* to be called whenever a peer joins the network.

        Delegates to :meth:`~daffi.app.AsyncClient.on_member_added` on the
        underlying client.  Can be used as a decorator or a plain call.
        """
        return self.client.on_member_added(handler)

    def on_member_removed(self, handler):
        """Register *handler* to be called whenever a peer leaves the network.

        Delegates to :meth:`~daffi.app.AsyncClient.on_member_removed` on the
        underlying client.  Can be used as a decorator or a plain call.
        """
        return self.client.on_member_removed(handler)

    # ------------------------------------------------------------------
    # Primary API
    # ------------------------------------------------------------------

    def rpc(
        self,
        timeout: Union[int, None] = None,
        receiver: Union[str, None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> AsyncRpcProxy:
        """Configure a blocking call and return an async proxy.

        Example::

            result = await conn.rpc(timeout=5).add(1, 2)
        """
        return AsyncRpcProxy(
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
    ) -> AsyncRpcProxy:
        """Configure a fire-and-forget call and return an async proxy.

        Example::

            await conn.rpc_nowait().log_event(payload)
        """
        return AsyncRpcProxy(
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
    ) -> AsyncBroadcastProxy:
        """Broadcast to all matching workers; collect ``{name: result}`` dict.

        Example::

            results = await conn.cast().add(1, 2)
        """
        return AsyncBroadcastProxy(
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
    ) -> AsyncBroadcastProxy:
        """Fire-and-forget broadcast to all matching workers."""
        return AsyncBroadcastProxy(
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
    ) -> AsyncStreamProxy:
        """Stream a generator with per-chunk backpressure.

        Example::

            await conn.stream().receive_chunk(data_source())
        """
        return AsyncStreamProxy(
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
    ) -> AsyncStreamNowaitProxy:
        """Fire-and-forget generator stream (no backpressure)."""
        return AsyncStreamNowaitProxy(
            conn=self,
            receiver=receiver,
            serde=SerdeFormat.OPAQUE,
            timeout=None,
            logger=self.client.logger,
        )

    async def wait_for_members(
        self,
        *members: str,
        timeout: Union[float, None] = None,
        interval: float = 1.0,
    ) -> None:
        """Async-block until all requested peers appear in the network.

        Example::

            await conn.wait_for_members("worker-1", "worker-2", timeout=30)
        """
        if not members:
            return
        needed = set(members)
        import time as _time
        start = _time.monotonic()
        while True:
            current = {m["name"] for m in get_available_members(self.client._conn_num)}
            if needed.issubset(current):
                return
            if timeout is not None and (_time.monotonic() - start) >= timeout:
                raise TimeoutError(
                    f"Timed out after {timeout}s waiting for members: {needed - current}"
                )
            await asyncio.sleep(interval)
