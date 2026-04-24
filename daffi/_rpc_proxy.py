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
import select
import time
import logging
import threading
from itertools import repeat
from typing import TYPE_CHECKING, Any, Union, Tuple, List, Optional
from contextlib import contextmanager

if TYPE_CHECKING:
    from daffi.app import Client

from daffi._serialization import SerdeFormat, Serializer
from daffi.utils.misc import iterable
from daffi._wakeup import WakeupFd
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._bindings import (
    send_message_from_client,
    get_message_from_client_store,
    mark_message_as_expired,
    set_service_methods,
    send_handshake_from_client,
    set_client_response_fd,
    get_available_members,
    MessageFlag,
)
from . import dfcore

METADATA_SEPARATOR = ","


class ResponseNotifier:
    """Per-connection wakeup fd shared by every blocking RPC waiter.

    Each :class:`~daffi.app.Client` connection owns exactly one notifier.
    The notifier hands the write-side of an eventfd / pipe to the Zig layer
    via :func:`set_client_response_fd`; Zig writes a single ``u64(1)`` to
    it whenever a new response is inserted into ``ClientMessageStore``.

    Each :meth:`RpcResult.result` call
    blocks **directly** in ``select.select`` on :attr:`read_fd`, with the
    remaining timeout passed straight through.  When several waiters share
    the fd they all wake (``select`` is level-triggered), each tries to
    drain (the read end is non-blocking so the racer that lost just sees
    ``EAGAIN``), and each re-checks the store for its own uuid.  Whoever
    finds their response returns; the others go straight back to
    ``select`` for the next signal.
    """

    _instances: "dict[int, ResponseNotifier]" = {}
    _instances_lock = threading.Lock()

    def __init__(self, conn_num: int) -> None:
        self._conn_num = conn_num
        self._wakeup = WakeupFd()
        set_client_response_fd(conn_num, self._wakeup.write_fd)


    @classmethod
    def register(cls, conn_num: int) -> "ResponseNotifier":
        """Create and register a notifier for *conn_num*.

        If a stale notifier already exists for the same handle (e.g. after
        an unclean reconnect) it is closed first so the fresh one owns
        the slot.
        """
        with cls._instances_lock:
            old = cls._instances.pop(conn_num, None)
        if old is not None:
            old.close()
        notifier = cls(conn_num)
        with cls._instances_lock:
            cls._instances[conn_num] = notifier
        return notifier

    @classmethod
    def unregister(cls, conn_num: int) -> None:
        """Close and forget the notifier registered for *conn_num*, if any."""
        with cls._instances_lock:
            n = cls._instances.pop(conn_num, None)
        if n is not None:
            n.close()

    @classmethod
    def for_conn(cls, conn_num: int) -> "Optional[ResponseNotifier]":
        """Return the notifier for *conn_num*, or ``None`` if not registered."""
        with cls._instances_lock:
            return cls._instances.get(conn_num)

    def close(self) -> None:
        """Release both ends of the wakeup fd.

        Any waiter currently blocked in ``select.select`` will get
        ``OSError: Bad file descriptor`` and bail out of its sleep — the
        next loop iteration in :meth:`RpcResult.result` falls back to
        the short fixed-interval polling path so a teardown in the
        middle of an in-flight call still terminates cleanly.
        """
        try:
            self._wakeup.close()
        except Exception:
            pass

    @property
    def read_fd(self) -> int:
        """File descriptor that callers should pass to ``select.select``."""
        return self._wakeup.read_fd

    def drain(self) -> None:
        """Best-effort drain of pending notifications.

        Safe to call from multiple threads; the underlying ``os.read`` is
        non-blocking (see :class:`~daffi.utils.wakeup.WakeupFd`) so a
        racer that lost the drain just observes ``EAGAIN``.
        """
        self._wakeup.drain()


class TransmissionFailure(Exception):
    """Raised when a message cannot be delivered (no receiver found, timeout
    during handshake, or unexpected receiver disconnect)."""


class RemoteCallError(Exception):
    """Raised on the caller side when the remote executor raised an exception."""


@contextmanager
def system_exception_handler(msg_template: str, errtype: type, conn_num: int = 0):
    """Context manager that converts low-level errors from the native extension
    into a friendlier *errtype* exception.

    Args:
        msg_template: A ``str.format``-style template with one ``{}`` placeholder
                      for the original error message.
        errtype:      The exception class to raise.
        conn_num:     Optional native connection handle.  When provided and the
                      error is ``ReceiverNotFound``, the message is enriched with
                      the list of currently connected peers.
    """
    try:
        yield
    except (SystemError, ValueError) as e:
        if isinstance(e, SystemError):
            origin = e.__cause__.args[0] if e.__cause__ else str(e)
        else:
            origin = str(e)

        if "ReceiverNotFound" in origin and conn_num:
            available = [m["name"] for m in get_available_members(conn_num)]
            peer_lines = (
                "\n".join(f"      • {p}" for p in available)
                if available
                else "      (none connected)"
            )
            origin = (
                "ReceiverNotFound\n\n"
                "  The peer is either not connected to the router, or it is\n"
                "  connected but does not have the requested @callback registered.\n"
                f"\n"
                f"  Connected peers:\n{peer_lines}"
            )

        raise errtype(msg_template.format(origin)).with_traceback(None) from None


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
        req_name = "rpc call" if self.return_result else "rpc_nowait"
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
            f"Unable to proceed with {self}: {{}}", TransmissionFailure, conn_num
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
                f"Unable to proceed with {self}: {{}}", TransmissionFailure, conn_num
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
                    timeout=30,
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

    # Cap on a single ``select.select`` wait so a silent peer disconnect is
    # detected via the liveness re-check below within at most this many
    # seconds.  Only applied when ``self.receivers`` is non-empty — for an
    # untargeted RPC there is nothing to liveness-check against.
    _LIVENESS_INTERVAL = 1.0

    # Fallback poll interval for environments where no ResponseNotifier is
    # registered (unit tests that exercise the bindings without going
    # through ``Client.connect``).  Kept short so the fallback behaves
    # similarly to the previous adaptive backoff at its tight end.
    _FALLBACK_POLL_INTERVAL = 0.001

    def result(self) -> Tuple[bytes, int, int]:
        """Block until the response arrives and return ``(data, flag, serde)``.

        Each iteration:

        1. Look up the response in the client message store.  Always done
           first — in ``cast()`` all sub-calls share roughly the same
           ``send_ts``, so a peer's response may already be sitting in the
           store from an earlier waiter.  Skipping this just because the
           deadline elapsed would raise a spurious ``TimeoutError``.
        2. Re-evaluate the deadline; raise ``TimeoutError`` if expired.
        3. Block in ``select.select`` on the connection's response wakeup
           fd, with the remaining time (or 1 s liveness cap) used directly
           as the ``select`` timeout.  Any thread that wakes drains the fd
           best-effort — the read end is non-blocking, so concurrent
           waiters racing to drain just see ``EAGAIN`` instead of hanging.

        Raises:
            RemoteCallError: If the remote returned an error payload.
            TransmissionFailure: If an expected receiver disconnected mid-call.
            TimeoutError: If *timeout* seconds elapse with no response.
        """
        notifier = ResponseNotifier.for_conn(self.conn_num)
        wait_fds = [notifier.read_fd] if notifier is not None else []
        deadline = (self.send_ts + self.timeout) if self.timeout > 0 else None

        while True:
            if res := get_message_from_client_store(self.uuid, self.conn_num):
                return self._unpack_response(res)

            if deadline is not None:
                remaining = deadline - time.time()
                if remaining <= 0:
                    mark_message_as_expired(self.uuid, self.conn_num)
                    raise TimeoutError(
                        f"Timeout reached for rpc call with uuid: {self.uuid}."
                    )
            else:
                remaining = None

            # Cap each wait at the liveness interval when we have a known
            # receiver set, so a silent peer disconnect surfaces within
            # ~1 s instead of waiting the full call deadline.
            if remaining is None:
                wait_chunk = self._LIVENESS_INTERVAL if self.receivers else None
            elif self.receivers:
                wait_chunk = min(remaining, self._LIVENESS_INTERVAL)
            else:
                wait_chunk = remaining

            if wait_fds:
                try:
                    readable, _, _ = select.select(wait_fds, [], [], wait_chunk)
                except (OSError, ValueError):
                    # fd was closed (notifier teardown during stop) — fall
                    # back to a brief sleep and let the next iteration
                    # re-evaluate everything.
                    time.sleep(self._FALLBACK_POLL_INTERVAL)
                    readable = ()
                if readable:
                    notifier.drain()
            else:
                # No notifier registered (e.g. RpcResult exercised outside
                # of Client.connect).  Sleep the smaller of the remaining
                # deadline and the fallback interval.
                time.sleep(
                    self._FALLBACK_POLL_INTERVAL
                    if wait_chunk is None
                    else min(wait_chunk, self._FALLBACK_POLL_INTERVAL)
                )

            if self.receivers:
                if missing_receivers := self.receivers - {
                    m["name"] for m in get_available_members(self.conn_num)
                }:
                    raise TransmissionFailure(
                        f"The anticipated receivers(s) {missing_receivers}"
                        f" unexpectedly disconnected, causing an interruption in the awaiting result of {self.proxy}."
                        f" All receivers: {self.receivers}"
                    )

    def _unpack_response(
        self, res: Tuple
    ) -> Tuple[bytes, int, int]:
        """Decode a ``get_message_from_client_store`` tuple into a result.

        Mirrors the original inline logic from ``result()``: a 1-tuple is an
        unexpected error from the native layer, an ``ERROR`` flag carries a
        pickled remote exception, and a normal RESPONSE is returned as-is.
        """
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
                conn_num,
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
                conn_num,
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


class _StreamBase:
    """Shared init/repr logic for the two stream proxy variants."""

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
        self._func_name: Optional[str] = None
        self._receiver = {receiver} if receiver else set()

    def __str__(self):
        return f"{self.__class__.__name__}(fn: {self._func_name!r}, receiver: {self.receiver!r})"

    __repr__ = __str__

    def __getattr__(self, item: str) -> "_StreamBase":
        self._func_name = item
        return self

    def _send_chunk(self, conn_num: int, chunk, return_result: bool):
        """Serialise and send one chunk; return (uuid, ts, found_receiver)."""
        data, is_bytes = Serializer.serialize(self.serde, chunk)
        with system_exception_handler(
            f"Unable to stream to {self}: {{}}", TransmissionFailure, conn_num
        ):
            uuid, ts, found_receiver = send_message_from_client(
                data=data,
                flag=MessageFlag.REQUEST,
                serde=self.serde,
                receiver=self.receiver,
                func_name=self._func_name,
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
            raise TransmissionFailure(f"No receiver found for {self}." + members)
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

    def __call__(self, gen) -> None:
        """Iterate *gen*, sending each chunk and waiting for an ack before continuing.

        Args:
            gen: A generator, iterator, or any iterable.  Each yielded item is
                 sent as a separate blocking message.  A single non-iterable
                 value is wrapped in a list and sent as one message.

        Raises:
            TransmissionFailure: If no receiver is found for any chunk.
            TimeoutError: If the per-chunk timeout expires waiting for an ack.
        """
        assert self._func_name is not None
        conn_num = self.conn.client._conn_num
        chunks = gen if iterable(gen) else [gen]
        for chunk in chunks:
            uuid, ts, _ = self._send_chunk(conn_num, chunk, return_result=True)
            # Wait for the ack (result is discarded — only backpressure matters).
            RpcResult(
                conn_num=conn_num,
                uuid=uuid,
                ts=ts,
                timeout=self.timeout,
                receivers=self._receiver or None,
                proxy=self,
            ).result()


class StreamNowaitProxy(_StreamBase):
    """Lazy call builder returned by :meth:`~ClientConnection.stream_nowait`.

    Iterates a generator and sends each chunk as a **fire-and-forget** message —
    no acknowledgement is waited for.  The producer can outpace the consumer;
    use this only when you control the rate yourself or can tolerate queue build-up::

        conn.stream_nowait(serde=SerdeFormat.OPAQUE).receive_chunk(data_source())
    """

    def __call__(self, gen) -> None:
        """Iterate *gen* and send each yielded value without waiting for replies.

        Args:
            gen: A generator, iterator, or any iterable.  Each yielded item is
                 sent as a separate fire-and-forget message.

        Raises:
            TransmissionFailure: If no receiver is found for any chunk.
        """
        assert self._func_name is not None
        conn_num = self.conn.client._conn_num
        chunks = gen if iterable(gen) else [gen]
        for chunk in chunks:
            self._send_chunk(conn_num, chunk, return_result=False)


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

    def __init__(self, client: "Client", password: str = ""):
        self.client = client
        self.password = password

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

        Member names are compared without the ``" (this app)"`` suffix that the
        native layer appends to the current client's own entry, so you can
        safely pass the current app's own name if needed.

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
            current = {m["name"].removesuffix(" (this app)") for m in raw}
            if needed.issubset(current):
                return
            if timeout is not None and (time.monotonic() - start) >= timeout:
                missing = needed - current
                raise TimeoutError(
                    f"Timed out after {timeout}s waiting for members: {missing}"
                )
            time.sleep(interval)


class _RetryCallProxy:
    """Proxy returned by every :class:`AutoReconnect` call method.

    Intercepts the remote function name and, when the function is eventually
    called, executes it through :meth:`AutoReconnect._connection` so the
    connection is guaranteed to be alive (or a reconnect is attempted first).

    Usage (transparent — users call the same API as with a plain
    :class:`ClientConnection`)::

        conn = AutoReconnect(client, password)
        result = conn.rpc(timeout=5).add(1, 2)   # retries on connection loss
    """

    __slots__ = ("_ar", "_method", "_args", "_kwargs")

    def __init__(
        self,
        ar: "AutoReconnect",
        method: str,
        args: tuple,
        kwargs: dict,
    ) -> None:
        self._ar = ar
        self._method = method
        self._args = args
        self._kwargs = kwargs

    def __getattr__(self, func_name: str):
        def _invoke(*call_args: Any, **call_kwargs: Any) -> Any:
            conn = self._ar._live_conn()
            proxy = getattr(conn, self._method)(*self._args, **self._kwargs)
            return getattr(proxy, func_name)(*call_args, **call_kwargs)

        return _invoke


class AutoReconnect:
    """Event-driven reconnect adapter wrapping a :class:`ClientConnection`.

    Returned by :meth:`~daffi.app.Client.connect` when ``autoreconnect=True``:

    .. code-block:: python

        conn = ClientConnection(client, password)
        if client._autoreconnect:
            conn = AutoReconnect(conn)

    **For callers** — every call method (:meth:`rpc`, :meth:`cast`, etc.)
    returns a :class:`_RetryCallProxy`.  When invoked the proxy checks that
    the connection is alive (via :meth:`_live_conn`) and reconnects with
    exponential back-off before executing the call.

    **For workers** (nodes that only receive callbacks and never make outgoing
    calls) — when the native layer detects EOF it writes to a pipe registered
    via ``dfcore.setClientDisconnectFd``.  The existing task-dispatcher poller
    thread wakes from ``select.select`` on that pipe and calls
    :meth:`_on_disconnect`, which reconnects without any additional thread.

    No background polling thread is used.

    Example::

        client = Client(app_name="worker", host="127.0.0.1", port=6000,
                        autoreconnect=True, reconnect_delay=2.0)
        conn = client.connect()   # returns AutoReconnect wrapping ClientConnection

    Attributes:
        conn: The wrapped :class:`ClientConnection`.
    """

    def __init__(self, conn: "ClientConnection") -> None:
        self.conn = conn
        # Guards _do_reconnect so concurrent callers (_live_conn from multiple
        # user threads) never attempt simultaneous reconnects.
        self._lock = threading.Lock()
        # For worker connections: register a disconnect notification fd with
        # the task dispatcher so that EOF from the native layer wakes the
        # existing poller thread and triggers _on_disconnect immediately.
        client = conn.client
        if client._task_dispatcher is not None:
            client._task_dispatcher.register_disconnect(
                client._conn_num,
                self._on_disconnect,
            )

    def __str__(self) -> str:
        return f"AutoReconnect[{self.conn.client}]"

    def __repr__(self) -> str:
        return str(self)

    @property
    def client(self):
        """The underlying :class:`~daffi.app.Client`."""
        return self.conn.client

    def _is_alive(self) -> bool:
        """Return ``True`` when the native connection slot is still active."""
        conn_num = self.conn.client._conn_num
        if conn_num is None:
            return False
        try:
            return dfcore.getAvailableMembers(conn_num) is not None
        except Exception:
            return False

    def _on_disconnect(self, old_conn_num: int) -> None:
        """Called by the task-dispatcher poller thread when the native EOF fires.

        Deregisters the dead connection's fds (without stopping the poller
        thread — we are *in* it), then blocks in the retry loop.  Because the
        connection is dead no useful work is lost while this thread is busy
        reconnecting.
        """
        with self._lock:
            client = self.conn.client
            td = client._task_dispatcher
            if td is not None:
                td._deregister_fds(old_conn_num)
                td.connections.discard(client)
            self._do_reconnect()

    def _live_conn(self) -> "ClientConnection":
        """Return the wrapped :class:`ClientConnection`, reconnecting first if needed.

        Used by callers (outgoing RPC).  If a disconnect fd is pending it is
        cancelled here to prevent a double-reconnect when the poller also wakes.
        """
        if not self._is_alive():
            with self._lock:
                if not self._is_alive():
                    # Cancel any pending disc-fd callback to avoid a race.
                    client = self.conn.client
                    td = client._task_dispatcher
                    if td is not None:
                        td._deregister_fds(client._conn_num)
                        td.connections.discard(client)
                    self._do_reconnect()
        return self.conn

    def _do_reconnect(self) -> None:
        """Tear down stale native state and loop until reconnected.

        Must be called with :attr:`_lock` held.  Safe from both the
        task-dispatcher poller thread (via :meth:`_on_disconnect`) and regular
        user threads (via :meth:`_live_conn`).  The task dispatcher is *not*
        stopped — its threads are reused for the new connection.
        """
        client = self.conn.client
        password = self.conn.password

        old_num = client._conn_num
        client._conn_num = None
        client._conn_type = None

        if old_num is not None:
            # Detach the response-notifier thread from the dying connection
            # *before* freeing the native slot.  ``_do_connect`` will create
            # a fresh notifier for the new conn_num.
            ResponseNotifier.unregister(old_num)
            try:
                dfcore.stopClient(old_num)
            except Exception:
                pass

        while True:
            delay = client._reconnect_delay
            client.logger.warning(f"Connection lost — reconnecting in {delay:.1f}s…")
            time.sleep(delay)
            try:
                client._do_connect(password)
                client.logger.debug("Reconnected successfully.")
                # Re-register the disconnect fd for the fresh connection so
                # future drops are also caught without a polling thread.
                if client._task_dispatcher is not None:
                    client._task_dispatcher.register_disconnect(
                        client._conn_num,
                        self._on_disconnect,
                    )
                return
            except Exception as exc:
                client.logger.warning(f"Reconnect failed: {exc}")
                if client._conn_num is not None:
                    # The half-initialised connection may have a notifier
                    # registered by _do_connect — unregister it before we
                    # free the native slot to avoid a leak.
                    ResponseNotifier.unregister(client._conn_num)
                    try:
                        dfcore.stopClient(client._conn_num)
                    except Exception:
                        pass
                    client._conn_num = None

    def rpc(self, *args: Any, **kwargs: Any) -> _RetryCallProxy:
        """Reconnect-aware :meth:`~ClientConnection.rpc` proxy."""
        return _RetryCallProxy(self, "rpc", args, kwargs)

    def rpc_nowait(self, *args: Any, **kwargs: Any) -> _RetryCallProxy:
        """Reconnect-aware :meth:`~ClientConnection.rpc_nowait` proxy."""
        return _RetryCallProxy(self, "rpc_nowait", args, kwargs)

    def cast(self, *args: Any, **kwargs: Any) -> _RetryCallProxy:
        """Reconnect-aware :meth:`~ClientConnection.cast` proxy."""
        return _RetryCallProxy(self, "cast", args, kwargs)

    def cast_nowait(self, *args: Any, **kwargs: Any) -> _RetryCallProxy:
        """Reconnect-aware :meth:`~ClientConnection.cast_nowait` proxy."""
        return _RetryCallProxy(self, "cast_nowait", args, kwargs)

    def stream(self, *args: Any, **kwargs: Any) -> _RetryCallProxy:
        """Reconnect-aware :meth:`~ClientConnection.stream` proxy."""
        return _RetryCallProxy(self, "stream", args, kwargs)

    def stream_nowait(self, *args: Any, **kwargs: Any) -> _RetryCallProxy:
        """Reconnect-aware :meth:`~ClientConnection.stream_nowait` proxy."""
        return _RetryCallProxy(self, "stream_nowait", args, kwargs)

    def wait_for_members(self, *members: str, **kwargs: Any) -> None:
        """Reconnect-aware :meth:`~ClientConnection.wait_for_members` proxy.

        Ensures the connection is alive before polling, so it is safe to call
        even before the first successful reconnect.
        """
        self._live_conn().wait_for_members(*members, **kwargs)

    def stop(self) -> None:
        """Stop the underlying client (no background thread to join)."""
        self.conn.client.stop()
