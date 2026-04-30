"""
Async task dispatcher — mirrors ``daffi._task_dispatcher`` but uses asyncio
primitives throughout.

The native Zig layer communicates entirely via OS file-descriptors (eventfd /
pipes).  ``asyncio`` monitors raw fds with ``loop.add_reader()``, so the C
extension requires **zero changes** for async support.

Execution model
---------------
* The sync poller thread becomes a single ``asyncio.Task`` —
  :meth:`AsyncTaskDispatcher.handle_task_queue`.
* The sync worker-thread pool becomes a pool of ``asyncio.Task`` objects.
* Fd readability is awaited via a one-shot ``asyncio.Future`` resolved by an
  ``add_reader`` callback; the first readable fd resolves a shared future and
  a non-blocking ``select.select(timeout=0)`` discovers the full set.
* Registered callbacks are run in the default executor (thread-pool) so that
  slow sync callbacks never stall the event loop.  Coroutine callbacks are
  ``await``ed directly.
"""

from __future__ import annotations

import asyncio
import json
import select as _select
import sys
from typing import Any, TYPE_CHECKING

from .. import dfcore
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._serialization import Serializer, SerdeFormat
from daffi._wakeup import WakeupFd, LifecycleSignal
from daffi._bindings import (
    set_request_fd,
    set_lifecycle_fd,
    MessageFlag,
)
from daffi.exceptions import Disconnected, Evicted
from daffi._task_dispatcher import (
    _ConnEntry,
    EventType,
    _SENDERS,
    _tblib_installed,
)

if TYPE_CHECKING:
    from daffi.aio._rpc_proxy import AsyncResponseNotifier, AsyncRpcProxy


# ---------------------------------------------------------------------------
# Async callback executor
# ---------------------------------------------------------------------------

async def _execute_task_async(
    func_name: str,
    serde: SerdeFormat,
    data: bytes,
) -> tuple:
    """Invoke a registered callback and return ``(result, flag, serde)``.

    Coroutine callbacks are ``await``ed directly.  Sync callbacks are run in
    the default executor so they never block the event loop.
    """
    cb = EXECUTOR_REGISTRY.get(func_name)
    args, kwargs = Serializer.deserialize(serde, data)
    try:
        # cb is an Executor wrapper whose __call__ may return a plain value or
        # a coroutine (when the registered function is async def).  We cannot
        # use asyncio.iscoroutinefunction(cb) here because Executor.__call__ is
        # always a plain method — check the return value instead.
        raw = cb(*args, **kwargs)
        if asyncio.iscoroutine(raw):
            result = await raw
        else:
            result = raw
        return result, MessageFlag.RESPONSE, serde
    except asyncio.CancelledError:
        raise
    except Exception:
        if serde == SerdeFormat.OPAQUE:
            serde = SerdeFormat.PICKLE
        err_type, err_obj, tb = sys.exc_info()
        include_tb = _tblib_installed and serde == SerdeFormat.PICKLE
        result = (
            err_type.__name__,
            err_type.__module__,
            str(err_obj),
            tb if include_tb else None,
        )
        return result, MessageFlag.ERROR, serde


# ---------------------------------------------------------------------------
# Lifecycle signal handler (async version)
# ---------------------------------------------------------------------------

async def _handle_lifecycle_signal_async(
    conn: Any,
    conn_num: int,
    reason: bytes,
) -> None:
    """Async counterpart of ``_task_dispatcher._handle_lifecycle_signal``.

    Called from :meth:`AsyncTaskDispatcher.handle_task_queue` on the event
    loop when the Zig native layer writes a lifecycle byte.
    """
    # Import here to avoid a module-level circular import.
    from daffi.aio._rpc_proxy import AsyncResponseNotifier, AsyncRpcProxy

    if reason == LifecycleSignal.INIT:
        # Re-run handshake (blocking call) without blocking the event loop.
        loop = asyncio.get_running_loop()
        handshake = await loop.run_in_executor(
            None, AsyncRpcProxy._process_client_handshake, conn_num
        )
        conn._register_executors()
        return

    if reason == LifecycleSignal.NORMAL:
        await conn.stop()
        return

    if reason == LifecycleSignal.EVICTED:
        err: Exception = Evicted(
            f"This client (app_name={conn.app_name!r}) was evicted — "
            "a new connection with the same app_name took over its slot."
        )
    else:  # DISCONNECTED or unknown
        err = Disconnected(
            "Server disconnected unexpectedly.\n\n"
            "  The router or service this client was connected to has stopped."
        )

    AsyncResponseNotifier.signal_lifecycle_error(conn_num, err)
    conn._connection_error = err
    conn._disconnected = True

    if conn._joining:
        await conn.stop()
    else:
        conn.logger.error(f"Error in connection {conn_num}: {err}")


# ---------------------------------------------------------------------------
# AsyncTaskDispatcher
# ---------------------------------------------------------------------------

class AsyncTaskDispatcher:
    """Async counterpart of :class:`~daffi._task_dispatcher.TaskDispatcher`.

    Uses ``asyncio.Task`` for the poller and worker pool, ``asyncio.Event``
    for the stop signal, and ``asyncio.Queue`` for inter-task work delivery.

    The public API (``start_for_connection`` / ``stop_for_connection``) mirrors
    the sync version except that ``stop_for_connection`` is ``async def``.
    """

    DEFAULT_WORKERS = 1

    def __init__(self, workers: int = DEFAULT_WORKERS) -> None:
        if workers < 1:
            raise ValueError(f"workers must be >= 1 (got {workers!r})")
        self.workers = workers
        self.connections: set = set()
        self.pollers = (
            dfcore.getMessageForClientWorker,
            dfcore.getMessageForServerWorker,
        )

        self.stop_event: asyncio.Event = asyncio.Event()
        self.queue: asyncio.Queue = asyncio.Queue()

        self._workers: list[asyncio.Task] = []
        self._poller: asyncio.Task | None = None

        self._conns: dict[int, _ConnEntry] = {}
        self._rfd_to_conn_num: dict[int, int] = {}

    # ------------------------------------------------------------------
    # Worker pool
    # ------------------------------------------------------------------

    def _start_workers(self) -> None:
        """Create worker tasks if not already running (workers >= 2 only)."""
        if self._workers:
            return
        loop = asyncio.get_event_loop()
        for i in range(self.workers - 1):
            t = loop.create_task(
                self._worker_loop(), name=f"daffi-aio-worker-{i}"
            )
            self._workers.append(t)

    async def _worker_loop(self) -> None:
        """Pull tasks from the async queue and execute them."""
        while True:
            try:
                task = await self.queue.get()
            except asyncio.CancelledError:
                break
            if task is None:
                self.queue.task_done()
                break
            (
                uuid,
                data,
                _flag,
                serde,
                transmitter,
                func_name,
                return_result,
                conn_num,
                server_mode_bool,
            ) = task
            try:
                result, flag, out_serde = await _execute_task_async(
                    func_name, serde, data
                )
                if return_result:
                    result_bytes, is_bytes = Serializer.serialize(out_serde, result)
                    _SENDERS[server_mode_bool](
                        data=result_bytes,
                        flag=flag,
                        serde=out_serde,
                        receiver=transmitter,
                        func_name=func_name,
                        return_result=False,
                        conn_num=conn_num,
                        is_bytes=is_bytes,
                        uuid=uuid,
                    )
            except asyncio.CancelledError:
                raise
            except Exception:
                pass
            finally:
                self.queue.task_done()

    # ------------------------------------------------------------------
    # Fd management (mirrors sync version exactly)
    # ------------------------------------------------------------------

    def _deregister_fds(self, conn_num: int | None) -> None:
        if conn_num is None:
            return
        entry = self._conns.get(conn_num)
        if entry is not None:
            self._rfd_to_conn_num.pop(entry.wakeup.read_fd, None)
            entry.wakeup.close()

    def _close_lifecycle(self, conn_num: int | None) -> None:
        entry = self._conns.pop(conn_num, None)
        if entry is not None:
            self._rfd_to_conn_num.pop(entry.lifecycle.read_fd, None)
            entry.lifecycle.close()

    # ------------------------------------------------------------------
    # Connection registration
    # ------------------------------------------------------------------

    def start_for_connection(self, connection: Any) -> None:
        """Register *connection* and start the poller task if not running."""
        assert connection._conn_num is not None
        self.connections.add(connection)
        conn_num: int = connection._conn_num

        wakeup = WakeupFd()
        lc = WakeupFd(pipe=True)

        self._conns[conn_num] = _ConnEntry(
            conn=connection, wakeup=wakeup, lifecycle=lc
        )
        self._rfd_to_conn_num[wakeup.read_fd] = conn_num
        self._rfd_to_conn_num[lc.read_fd] = conn_num

        set_request_fd(conn_num, wakeup.write_fd, server_mode=bool(connection.server_mode))
        if connection.server_mode is None:
            set_lifecycle_fd(conn_num, lc.write_fd)

        self._start_workers()

        if self._poller is None:
            loop = asyncio.get_event_loop()
            self._poller = loop.create_task(
                self.handle_task_queue(), name="daffi-aio-poller"
            )

    async def stop_for_connection(self, connection: Any) -> None:
        """Deregister *connection* and — when no connections remain — tear
        down all tasks and release fd resources."""
        self.connections.discard(connection)
        conn_num: int | None = getattr(connection, "_conn_num", None)

        if not self.connections:
            self.stop_event.set()
            in_poller = asyncio.current_task() is self._poller

            if not in_poller:
                # Wake the poller so it sees stop_event on its next iteration.
                entry = self._conns.get(conn_num)
                if entry is not None:
                    entry.lifecycle.write(LifecycleSignal.STOP)

            # Cancel worker tasks.
            for w in self._workers:
                w.cancel()
            if self._workers:
                await asyncio.gather(*self._workers, return_exceptions=True)
            self._workers.clear()

            if self._poller is not None and not in_poller:
                self._poller.cancel()
                try:
                    await self._poller
                except (asyncio.CancelledError, Exception):
                    pass
                self._poller = None

            # Close lifecycle fd only after the poller has exited.
            self._close_lifecycle(conn_num)

        # Always deregister the wakeup fd.
        self._deregister_fds(conn_num)

    # ------------------------------------------------------------------
    # Poller coroutine
    # ------------------------------------------------------------------

    async def handle_task_queue(self) -> None:
        """Core event loop: wait for any fd to become readable, dispatch.

        Uses ``loop.add_reader()`` + a shared ``asyncio.Future`` instead of
        ``selectors.DefaultSelector``.  After the future resolves, a
        non-blocking ``select.select(timeout=0)`` discovers the full set of
        currently readable fds — the same dispatch logic as the sync version
        then runs inline.
        """
        loop = asyncio.get_running_loop()
        inline = self.workers == 1

        while not self.stop_event.is_set():
            all_fds = list(self._rfd_to_conn_num.keys())
            if not all_fds:
                await asyncio.sleep(0.001)
                continue

            # One shared future; first readable fd resolves it.
            wakeup: asyncio.Future = loop.create_future()

            def _make_cb(f: asyncio.Future):
                def _cb() -> None:
                    if not f.done():
                        f.set_result(None)
                return _cb

            registered: list[int] = []
            for fd in all_fds:
                try:
                    loop.add_reader(fd, _make_cb(wakeup))
                    registered.append(fd)
                except (OSError, ValueError):
                    pass

            if not registered:
                await asyncio.sleep(0.001)
                continue

            try:
                await wakeup
            except asyncio.CancelledError:
                break
            finally:
                for fd in registered:
                    try:
                        loop.remove_reader(fd)
                    except (OSError, ValueError):
                        pass

            if self.stop_event.is_set():
                break

            # Discover the full set of readable fds without blocking.
            try:
                readable_list, _, _ = _select.select(all_fds, [], [], 0)
                readable = set(readable_list)
            except (OSError, ValueError):
                continue

            # --- Dispatch ---
            lifecycle_stop = False
            notified: set = set()
            for rfd in readable:
                conn_num = self._rfd_to_conn_num.get(rfd)
                if conn_num is None:
                    continue
                entry = self._conns.get(conn_num)
                if entry is None:
                    continue
                if rfd == entry.lifecycle.read_fd:
                    reason = entry.lifecycle.read(1)
                    if not reason or reason == LifecycleSignal.STOP:
                        lifecycle_stop = True
                        break
                    await _handle_lifecycle_signal_async(entry.conn, conn_num, reason)
                elif rfd == entry.wakeup.read_fd:
                    entry.wakeup.drain()
                    notified.add(entry.conn)

            if lifecycle_stop:
                break

            for conn in list(self.connections):
                if conn not in notified:
                    continue
                poller = self.pollers[bool(conn.server_mode)]
                while not self.stop_event.is_set():
                    task = poller(conn._conn_num)
                    if task is None:
                        break
                    (
                        uuid,
                        data,
                        flag,
                        serde,
                        transmitter,
                        _receiver,
                        func_name,
                        return_result,
                    ) = task

                    if flag == MessageFlag.EVENTS:
                        await self._dispatch_event(conn, json.loads(data))
                    elif inline:
                        result, out_flag, out_serde = await _execute_task_async(
                            func_name, serde, data
                        )
                        if return_result:
                            result_bytes, is_bytes = Serializer.serialize(
                                out_serde, result
                            )
                            _SENDERS[bool(conn.server_mode)](
                                data=result_bytes,
                                flag=out_flag,
                                serde=out_serde,
                                receiver=transmitter,
                                func_name=func_name,
                                return_result=False,
                                conn_num=conn._conn_num,
                                is_bytes=is_bytes,
                                uuid=uuid,
                            )
                    else:
                        await self.queue.put(
                            (
                                uuid,
                                data,
                                flag,
                                serde,
                                transmitter,
                                func_name,
                                return_result,
                                conn._conn_num,
                                bool(conn.server_mode),
                            )
                        )

    @staticmethod
    async def _dispatch_event(conn: Any, payload: dict) -> None:
        """Route an EVENTS payload to the connection's typed handlers.

        Both sync and coroutine handlers are supported.
        """
        event_type: str = payload["type"]
        member: str = payload["member"]
        if event_type == EventType.CONNECTED:
            handlers = conn._on_member_added_handlers
        elif event_type == EventType.DISCONNECTED:
            handlers = conn._on_member_removed_handlers
        else:
            return
        for handler in handlers:
            result = handler(member)
            if asyncio.iscoroutine(result):
                await result
