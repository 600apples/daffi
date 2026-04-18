"""
Call-builder proxies and the :class:`ClientConnection` handle returned by
:meth:`~daffi.app.Client.connect`.

Four call styles are available on every :class:`ClientConnection`:

* :meth:`~ClientConnection.rpc`          — one worker, blocking, returns result
* :meth:`~ClientConnection.rpc_nowait`   — one worker, fire-and-forget
* :meth:`~ClientConnection.cast`         — all matching workers, blocking, returns ``{name: result}`` dict
* :meth:`~ClientConnection.cast_nowait`  — all matching workers, fire-and-forget
"""
from __future__ import annotations

import json
import time
import logging
from itertools import repeat
from typing import TYPE_CHECKING, Union, Tuple, List, Optional
from contextlib import contextmanager

if TYPE_CHECKING:
    from daffi.app import Client

from daffi.serialization import SerdeFormat, Serializer
from daffi.utils.misc import iterable
from daffi.registry.executor_registry import EXECUTOR_REGISTRY
from daffi.bindings import (
    send_message_from_client,
    get_message_from_client_store,
    mark_message_as_expired,
    set_service_methods,
    send_handshake_from_client,
    get_available_members,
    MessageFlag,
)


METADATA_SEPARATOR = ","


class BackOff:
    """Adaptive sleep/backoff controller for tight polling loops.

    Starts at a very short sleep interval and gradually increases it during
    idle periods to reduce CPU usage, up to a configurable maximum.  Call
    :meth:`tick` on every loop iteration; call :meth:`reset` to snap back to
    a shorter interval when there is suddenly work to do.

    The counter for each stage is computed as ``round(1 / sleep)`` so that
    every stage occupies roughly **1 second** of wall time, regardless of the
    sleep duration.

    Args:
        step:    Amount (in seconds) to add to the sleep interval each time
                 the internal counter expires.
        max_:    Maximum sleep duration (seconds).
        initial: Starting sleep duration.  Defaults to *step*.

    Example::

        backoff = BackOff(step=0.0001, max_=0.2, initial=0.2)
        while running:
            if got_work():
                backoff.reset(0.0001)   # snap back to fast polling
            time.sleep(backoff.tick())
    """

    __slots__ = ("sleep", "_step", "_max", "_counter")

    def __init__(self, step: float, max_: float, initial: float = None):
        self._step = step
        self._max = max_
        self.sleep: float = initial if initial is not None else step
        self._counter: int = round(1 / self.sleep) if self.sleep > 0 else 1

    def tick(self) -> float:
        """Advance one backoff step and return the current sleep duration."""
        sleep = self.sleep
        if sleep < self._max:
            counter = self._counter - 1
            if counter == 0:
                sleep += self._step
                if sleep >= self._max:
                    sleep = self._max
                counter = round(1 / sleep)
            self.sleep = sleep
            self._counter = counter
        return sleep

    def reset(self, sleep: float) -> None:
        """Reset the sleep interval to *sleep* (e.g. after receiving work).

        The internal counter is recalculated from the new sleep value so the
        hold duration stays consistent with the rest of the stages.
        """
        self.sleep = sleep
        self._counter = round(1 / sleep) if sleep > 0 else 1


class TransmissionFailure(Exception):
    """Raised when a message cannot be delivered (no receiver found, timeout
    during handshake, or unexpected receiver disconnect)."""


class RemoteCallError(Exception):
    """Raised on the caller side when the remote executor raised an exception."""


@contextmanager
def system_exception_handler(msg_template: str, errtype: type):
    """Context manager that converts low-level ``SystemError`` from the native
    extension into a friendlier *errtype* exception.

    Args:
        msg_template: A ``str.format``-style template with one ``{}`` placeholder
                      for the original error message.
        errtype:      The exception class to raise.
    """
    try:
        yield
    except SystemError as e:
        origin_err_name = e.__cause__.args[0]
        raise errtype(msg_template.format(origin_err_name)).with_traceback(
            None
        ) from None


class RpcProxy:
    """Lazy call builder returned by :meth:`~daffi.app.ClientConnection.rpc`
    and :meth:`~daffi.app.ClientConnection.rpc_nowait`.

    Attribute access captures the remote function name; calling the proxy
    sends the message::

        result = conn.rpc(timeout=5).add(1, 2)   # blocking — returns result
        conn.rpc_nowait().log_event(payload)      # fire-and-forget
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
        self._func_name = None
        self._receiver = {receiver} if receiver else set()
        self._uuid = None

    def __str__(self):
        req_name = "rpc call" if self.return_result else "stream"
        to_receiver = f" to {self.receiver}" if self.receiver else ""
        details = (
            f"(fn: {self._func_name!r}, uuid: {self._uuid})"
            if self._uuid
            else f"(fn: {self._func_name!r})"
        )
        return f"{req_name}{to_receiver}{details}"

    __repr__ = __str__

    def __call__(self, *args, **kwargs) -> Tuple[int, int]:
        """Send the captured call to the remote node.

        For blocking calls (:meth:`~daffi.app.ClientConnection.rpc`) this
        waits for the response and returns the deserialised result.  For
        fire-and-forget calls (:meth:`~daffi.app.ClientConnection.stream`) it
        returns ``None`` immediately.
        """
        if self.return_result:
            return self._process_rpc(*args, **kwargs)
        else:
            self._process_stream(*args, **kwargs)

    def __getattr__(self, item):
        """Capture the remote function name via attribute access."""
        self._func_name = item
        return self

    def _process_rpc(self, *args, **kwargs):
        """Send a blocking RPC call and return the deserialised result."""
        conn_num = self.conn.client._conn_num
        data, is_bytes = Serializer.serialize(self.serde, *args, **kwargs)
        assert self._func_name is not None
        with system_exception_handler(
            f"Unable to proceed with {self}: {{}}", TransmissionFailure
        ):
            uuid, ts, found_receiver = send_message_from_client(
                data=data,
                flag=MessageFlag.REQUEST,
                serde=self.serde,
                receiver=self.receiver,
                func_name=self._func_name,
                return_result=self.return_result,
                conn_num=conn_num,
                is_bytes=is_bytes,
            )
        self._uuid = uuid
        found_receivers = (
            None
            if not found_receiver
            else set(found_receiver.split(METADATA_SEPARATOR))
        )
        if not found_receivers:
            members = (
                ""
                if not (_memebers := get_available_members(conn_num))
                else f"\nAvailable receivers: {_memebers}"
            )
            raise TransmissionFailure(f"No receivers found for {self}." + members)
        elif missing_receivers := self._receiver - found_receivers:
            self.logger.warning(
                f"Receiver(s): {missing_receivers} seems to be offline."
            )
        result = RpcResult(
            conn_num=conn_num,
            uuid=uuid,
            ts=ts,
            timeout=self.timeout,
            receivers=found_receivers,
            proxy=self,
        )
        data, flag, serde = result.result()
        return Serializer.deserialize(serde, data)[0][0]

    def _process_stream(self, *args, **kwargs):
        """Send one or more fire-and-forget messages without waiting for replies."""
        conn_num = self.conn.client._conn_num
        assert self._func_name is not None
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

        for a, k in items:
            data, is_bytes = Serializer.serialize(self.serde, *a, **k)
            with system_exception_handler(
                f"Unable to proceed with {self}: {{}}", TransmissionFailure
            ):
                uuid, ts, found_receiver = send_message_from_client(
                    data=data,
                    flag=MessageFlag.REQUEST,
                    serde=self.serde,
                    receiver=self.receiver,
                    func_name=self._func_name,
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
                raise TransmissionFailure(f"No receivers found for {self}." + members)
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
        """
        with system_exception_handler(
            "unable to establish handshake: {}", TransmissionFailure
        ):
            data = METADATA_SEPARATOR.join([name for name, _ in EXECUTOR_REGISTRY])
            uuid, ts, found_receiver = send_handshake_from_client(
                password="",
                methods=data,
                conn_num=conn_num,
            )
            try:
                data, _, _ = RpcResult(
                    conn_num=conn_num,
                    uuid=uuid,
                    ts=ts,
                    timeout=5,
                    receivers=None,
                    proxy=None,
                ).result()
                return json.loads(data)
            except TimeoutError:
                raise TransmissionFailure("Handshake failed due to timeout.")

    @classmethod
    def _process_service_handshake(cls, conn_num: int) -> None:
        """Notify the native layer of this service's exported method names.

        Args:
            conn_num: Native connection handle.
        """
        data = METADATA_SEPARATOR.join([name for name, _ in EXECUTOR_REGISTRY])
        set_service_methods(data, conn_num)


class RpcResult:
    """Polls the native message store until the response for a given *uuid*
    arrives, then returns ``(data, flag, serde)``."""

    def __init__(
        self,
        conn_num: int,
        uuid: int,
        ts: int,
        timeout: int,
        receivers: Optional[set] = None,
        proxy: Optional[RpcProxy] = None,
    ):
        self.conn_num = conn_num
        self.uuid = uuid
        self.send_ts = ts
        self.timeout = timeout
        self.receivers = receivers
        self.proxy = proxy

    def result(self) -> Tuple[bytes, int, int]:
        """Block until the response arrives and return ``(data, flag, serde)``.

        Raises:
            RemoteCallError: If the remote returned an error payload.
            TransmissionFailure: If an expected receiver disconnected mid-call.
            TimeoutError: If *timeout* seconds elapse with no response.
        """
        timeout_cond = self._timeout_cond_fn()
        backoff = BackOff(step=0.0001, max_=1, initial=0.000001)
        counter = 0
        while timeout_cond():
            if res := get_message_from_client_store(self.uuid, self.conn_num):
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
            time.sleep(backoff.tick())
            counter = (counter + 1) % 1000
            if counter == 0 and self.receivers:
                if missing_receivers := self.receivers - {
                    m["name"] for m in get_available_members(self.conn_num)
                }:
                    raise TransmissionFailure(
                        f"The anticipated receivers(s) {missing_receivers}"
                        f" unexpectedly disconnected, causing an interruption in the awaiting result of {self.proxy}."
                        f" All receivers: {self.receivers}"
                    )
        else:
            mark_message_as_expired(self.uuid, self.conn_num)
            raise TimeoutError(f"Timeout reached for rpc call with uuid: {self.uuid}.")

    def _timeout_cond_fn(self):
        """Return a zero-argument predicate that is ``True`` while the deadline
        has not been reached (or always-``True`` when *timeout* is zero)."""
        if self.timeout <= 0:
            return lambda: True
        else:
            timeout = self.send_ts + self.timeout
            return lambda: timeout > time.time()


class BroadcastProxy:
    """Lazy call builder returned by :meth:`~daffi.app.ClientConnection.cast`
    and :meth:`~daffi.app.ClientConnection.cast_nowait`.

    Sends the captured call to **every** connected peer that exposes the
    requested method (or to an explicit list of receivers).

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
        self._func_name: Optional[str] = None
        if receiver is None:
            self._explicit_receivers: Optional[List[str]] = None
        elif isinstance(receiver, str):
            self._explicit_receivers = [receiver]
        else:
            self._explicit_receivers = list(receiver)

    def __getattr__(self, item: str) -> "BroadcastProxy":
        """Capture the remote function name via attribute access."""
        self._func_name = item
        return self

    def __call__(self, *args, **kwargs):
        """Dispatch the broadcast call.

        Returns a ``{name: result}`` dict for :meth:`~ClientConnection.cast`,
        or ``None`` for :meth:`~ClientConnection.cast_nowait`.
        """
        if self.return_result:
            return self._process_call_all(*args, **kwargs)
        self._process_cast_all(*args, **kwargs)

    def _resolve_receivers(self, conn_num: int) -> List[str]:
        """Return the list of peer names to target.

        Uses the explicit list when provided; otherwise auto-discovers every
        connected peer that exposes :attr:`_func_name`.
        """
        if self._explicit_receivers is not None:
            return self._explicit_receivers
        result = []
        for m in get_available_members(conn_num):
            name: str = m.get("name", "")
            # Skip the self-reference inserted by the native layer.
            if name.endswith(" (this app)"):
                continue
            methods = m.get("methods") or []
            if self._func_name in methods:
                result.append(name)
        return result

    def _process_call_all(self, *args, **kwargs) -> dict:
        """Fan out to all matching peers and collect ``{name: result}`` dict.

        Each peer's result is awaited individually.  If a peer raises an
        exception the exception object is stored as the dict value (rather
        than propagating immediately) so results from other peers are still
        returned.
        """
        conn_num = self.conn.client._conn_num
        data, is_bytes = Serializer.serialize(self.serde, *args, **kwargs)
        receivers = self._resolve_receivers(conn_num)
        if not receivers:
            available = [m["name"] for m in get_available_members(conn_num)]
            raise TransmissionFailure(
                f"No receivers found for call_all(fn={self._func_name!r})."
                + (f"\nAvailable peers: {available}" if available else "")
            )
        # Send to each receiver and collect (uuid → name) handles.
        pending: dict[str, RpcResult] = {}
        for receiver_name in receivers:
            with system_exception_handler(
                f"Unable to dispatch call_all to {receiver_name!r}: {{}}",
                TransmissionFailure,
            ):
                uuid, ts, found = send_message_from_client(
                    data=data,
                    flag=MessageFlag.REQUEST,
                    serde=self.serde,
                    receiver=receiver_name,
                    func_name=self._func_name,
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

    def _process_cast_all(self, *args, **kwargs) -> None:
        """Fan out to all matching peers, fire-and-forget."""
        conn_num = self.conn.client._conn_num
        data, is_bytes = Serializer.serialize(self.serde, *args, **kwargs)
        receivers = self._resolve_receivers(conn_num)
        if not receivers:
            available = [m["name"] for m in get_available_members(conn_num)]
            raise TransmissionFailure(
                f"No receivers found for cast_all(fn={self._func_name!r})."
                + (f"\nAvailable peers: {available}" if available else "")
            )
        for receiver_name in receivers:
            with system_exception_handler(
                f"Unable to dispatch cast_all to {receiver_name!r}: {{}}",
                TransmissionFailure,
            ):
                send_message_from_client(
                    data=data,
                    flag=MessageFlag.REQUEST,
                    serde=self.serde,
                    receiver=receiver_name,
                    func_name=self._func_name,
                    return_result=False,
                    conn_num=conn_num,
                    is_bytes=is_bytes,
                )


class ClientConnection:
    """Proxy returned by :meth:`~daffi.app.Client.connect`.

    Four call styles are available:

    * :meth:`rpc`         — one worker, blocking, returns result
    * :meth:`rpc_nowait`  — one worker, fire-and-forget
    * :meth:`cast`        — all matching workers, blocking, returns ``{name: result}``
    * :meth:`cast_nowait` — all matching workers, fire-and-forget

    Example::

        conn = client.connect()

        # One worker — blocking
        result = conn.rpc(timeout=5).add(1, 2)

        # One worker — fire-and-forget
        conn.rpc_nowait().log_event(payload)

        # All workers — collect all results
        results = conn.cast().add(1, 2)     # {"worker-1": 3, "worker-2": 3}

        # All workers — no results
        conn.cast_nowait().invalidate_cache(key)
    """

    def __init__(self, client: "Client"):
        self.client = client

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

    # ------------------------------------------------------------------
    # Deprecated aliases — kept for backward compatibility
    # ------------------------------------------------------------------

    def stream(
        self,
        receiver: Union[str, None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> RpcProxy:
        """Deprecated — use :meth:`rpc_nowait` instead."""
        import warnings
        warnings.warn(
            "stream() is deprecated, use rpc_nowait() instead",
            DeprecationWarning,
            stacklevel=2,
        )
        return self.rpc_nowait(receiver=receiver, serde=serde)

    def call(
        self,
        timeout: Union[int, None] = None,
        receiver: Union[str, None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> RpcProxy:
        """Deprecated — use :meth:`rpc` instead."""
        import warnings
        warnings.warn(
            "call() is deprecated, use rpc() instead",
            DeprecationWarning,
            stacklevel=2,
        )
        return self.rpc(timeout=timeout, receiver=receiver, serde=serde)

    def call_all(
        self,
        timeout: Union[int, None] = None,
        receiver: Union[str, List[str], None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> BroadcastProxy:
        """Deprecated — use :meth:`cast` instead."""
        import warnings
        warnings.warn(
            "call_all() is deprecated, use cast() instead",
            DeprecationWarning,
            stacklevel=2,
        )
        return self.cast(timeout=timeout, receiver=receiver, serde=serde)

    def cast_all(
        self,
        receiver: Union[str, List[str], None] = None,
        serde: SerdeFormat = SerdeFormat.PICKLE,
    ) -> BroadcastProxy:
        """Deprecated — use :meth:`cast_nowait` instead."""
        import warnings
        warnings.warn(
            "cast_all() is deprecated, use cast_nowait() instead",
            DeprecationWarning,
            stacklevel=2,
        )
        return self.cast_nowait(receiver=receiver, serde=serde)
