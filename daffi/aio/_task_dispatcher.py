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
* Every fd has its own ``add_reader`` callback that records the fd as ready
  and wakes the poller, which then services exactly those fds.
* Coroutine callbacks are ``await``ed directly.  Sync callbacks run on
  daemon threads so a slow one never stalls the event loop.
* ``stop`` cancels whatever is still running and does not wait for it.
"""

from __future__ import annotations

import asyncio
import concurrent.futures
import functools
import json
import os
import queue
import threading
from typing import Any

from .. import dfcore
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._serialization import Serializer, SerdeFormat
from daffi._wakeup import WakeupFd, LifecycleSignal
from daffi._bindings import (
    set_request_fd,
    set_lifecycle_fd,
    MessageFlag,
)
from daffi.exceptions import Evicted
from daffi._rpc_proxy import connection_lost_error
from daffi._task_dispatcher import (
    _ConnEntry,
    EventType,
    _error_result,
    _send_reply,
)


class _DaemonExecutor(concurrent.futures.Executor):
    """Runs sync callbacks on daemon threads.

    Unlike ``ThreadPoolExecutor`` (and so the loop's default executor),
    neither ``stop()`` nor interpreter exit waits for a callback that is
    still running.
    """

    def __init__(self, max_workers: int) -> None:
        self._max_workers = max_workers
        self._tasks: queue.SimpleQueue = queue.SimpleQueue()
        self._lock = threading.Lock()
        self._threads = 0
        self._idle = 0

    def submit(self, fn, /, *args, **kwargs) -> concurrent.futures.Future:
        future: concurrent.futures.Future = concurrent.futures.Future()
        with self._lock:
            if self._idle:
                self._idle -= 1
                spawn = False
            else:
                spawn = self._threads < self._max_workers
                self._threads += spawn
        self._tasks.put((future, fn, args, kwargs))
        if spawn:
            threading.Thread(target=self._work, name="daffi-aio-callback", daemon=True).start()
        return future

    def _work(self) -> None:
        while True:
            future, fn, args, kwargs = self._tasks.get()
            if future.set_running_or_notify_cancel():
                try:
                    future.set_result(fn(*args, **kwargs))
                except BaseException as exc:
                    future.set_exception(exc)
            with self._lock:
                self._idle += 1


def _new_callback_executor() -> None:
    """A forked child has none of the parent's threads."""
    global _callback_executor
    _callback_executor = _DaemonExecutor(min(32, (os.cpu_count() or 1) + 4))


_new_callback_executor()
if hasattr(os, "register_at_fork"):
    os.register_at_fork(after_in_child=_new_callback_executor)


async def _invoke_callback_async(
    func_name: str,
    serde: SerdeFormat,
    data: bytes,
) -> tuple:
    """Async counterpart of :func:`daffi._task_dispatcher._invoke_callback`."""
    try:
        cb = EXECUTOR_REGISTRY.get(func_name)
        if cb is None:
            raise LookupError(f"Callback {func_name!r} is not registered.")
        args, kwargs = Serializer.deserialize(serde, data)
        if cb.is_coroutine:
            result = await cb(*args, **kwargs)
        else:
            result = await asyncio.get_running_loop().run_in_executor(
                _callback_executor, functools.partial(cb, *args, **kwargs)
            )
        return result, MessageFlag.RESPONSE, serde
    except asyncio.CancelledError:
        raise
    except:  # noqa: E722
        return _error_result(serde)


class AsyncTaskDispatcher:
    """Async counterpart of :class:`~daffi._task_dispatcher.TaskDispatcher`.

    Uses ``asyncio.Task`` for the poller and worker pool and ``asyncio.Queue``
    for inter-task work delivery.

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
        self.queue: asyncio.Queue = asyncio.Queue()

        self._workers: list[asyncio.Task] = []
        self._poller: asyncio.Task | None = None
        # Background stop() calls started by lifecycle signals.
        self._stop_tasks: set[asyncio.Task] = set()

        self._conns: dict[int, _ConnEntry] = {}
        self._rfd_to_conn_num: dict[int, int] = {}
        self._ready: set[int] = set()
        self._kick: asyncio.Future | None = None

    # ------------------------------------------------------------------
    # Worker pool
    # ------------------------------------------------------------------

    def _start_workers(self) -> None:
        """Create ``workers`` worker tasks if not already running
        (``workers >= 2`` only)."""
        if self._workers or self.workers == 1:
            return
        loop = asyncio.get_running_loop()
        for i in range(self.workers):
            t = loop.create_task(self._worker_loop(), name=f"daffi-aio-worker-{i}")
            self._workers.append(t)

    async def _worker_loop(self) -> None:
        me = asyncio.current_task()
        queue = self.queue
        while me in self._workers:
            task = await queue.get()
            try:
                await self._run_task(*task)
            except Exception:
                task[-1].exception("Task execution failed")
            finally:
                queue.task_done()

    async def _run_task(
        self,
        uuid: int,
        data: bytes,
        serde: SerdeFormat,
        transmitter: str,
        func_name: str,
        return_result: bool,
        conn_num: int,
        server_mode: bool,
        logger,
    ) -> None:
        outcome = await _invoke_callback_async(func_name, serde, data)
        # A connection stopped during the callback gets no reply.
        if return_result and conn_num in self._conns:
            _send_reply(server_mode, conn_num, uuid, transmitter, func_name, outcome, logger)

    # ------------------------------------------------------------------
    # Fd management
    # ------------------------------------------------------------------

    def _watch(self, fd: int, conn_num: int) -> None:
        self._rfd_to_conn_num[fd] = conn_num
        asyncio.get_running_loop().add_reader(fd, self._on_readable, fd)

    def _unwatch(self, fd: int) -> None:
        self._rfd_to_conn_num.pop(fd, None)
        self._ready.discard(fd)
        try:
            asyncio.get_running_loop().remove_reader(fd)
        except (OSError, ValueError):
            pass

    def _on_readable(self, fd: int) -> None:
        self._ready.add(fd)
        self._wake_poller()

    def _wake_poller(self) -> None:
        kick = self._kick
        if kick is not None and not kick.done():
            kick.set_result(None)

    def _deregister_fds(self, conn_num: int | None) -> None:
        """The native layer gives the fd up first, so it never writes to a
        closed (or reused) descriptor."""
        entry = self._conns.pop(conn_num, None)
        if entry is None:
            return
        set_request_fd(conn_num, -1, server_mode=bool(entry.conn.server_mode))
        self._unwatch(entry.wakeup.read_fd)
        entry.wakeup.close()
        if entry.conn.server_mode is None:
            set_lifecycle_fd(conn_num, -1)
        self._unwatch(entry.lifecycle.read_fd)
        entry.lifecycle.close()

    # ------------------------------------------------------------------
    # Connection registration
    # ------------------------------------------------------------------

    def start_for_connection(self, connection: Any) -> None:
        """Register *connection* and start the poller task if not running."""
        assert connection._conn_num is not None
        conn_num: int = connection._conn_num

        wakeup = WakeupFd()
        lc = WakeupFd(pipe=True)
        self._conns[conn_num] = _ConnEntry(conn=connection, wakeup=wakeup, lifecycle=lc)
        self._watch(wakeup.read_fd, conn_num)
        self._watch(lc.read_fd, conn_num)

        set_request_fd(
            conn_num, wakeup.write_fd, server_mode=bool(connection.server_mode)
        )
        if connection.server_mode is None:
            set_lifecycle_fd(conn_num, lc.write_fd)

        self.connections.add(connection)
        self._start_workers()
        if self._poller is None:
            self._poller = asyncio.get_running_loop().create_task(
                self.handle_task_queue(), name="daffi-aio-poller"
            )

    async def stop_for_connection(self, connection: Any) -> None:
        """Deregister *connection*; the last one also cancels every task.

        Nothing is awaited: a callback still running is cancelled, or, if it
        is sync, abandoned on its thread, and its reply is dropped.
        """
        self.connections.discard(connection)
        self._deregister_fds(getattr(connection, "_conn_num", None))
        if self.connections:
            return

        current = asyncio.current_task()
        # A new poller may start while this one winds down; the old one exits
        # as soon as it sees it is no longer the current poller.
        poller, self._poller = self._poller, None
        workers, self._workers = self._workers, []
        self.queue = asyncio.Queue()
        self._wake_poller()
        for task in (*workers, poller):
            if task is not None and task is not current:
                task.cancel()

    # ------------------------------------------------------------------
    # Poller coroutine
    # ------------------------------------------------------------------

    async def handle_task_queue(self) -> None:
        """Service ready fds one at a time until this task is retired."""
        loop = asyncio.get_running_loop()
        me = asyncio.current_task()
        while self._poller is me:
            if not self._ready:
                self._kick = loop.create_future()
                try:
                    await self._kick
                finally:
                    self._kick = None
                continue
            await self._service(self._ready.pop())

    async def _service(self, fd: int) -> None:
        conn_num = self._rfd_to_conn_num.get(fd)
        entry = self._conns.get(conn_num) if conn_num is not None else None
        if entry is None:
            return
        if fd == entry.lifecycle.read_fd:
            reason = entry.lifecycle.read(1)
            if reason:
                try:
                    await self._handle_lifecycle_signal(entry.conn, conn_num, reason)
                except Exception:
                    entry.conn.logger.exception("Lifecycle handling failed")
        else:
            entry.wakeup.drain()
            await self._drain_tasks(entry.conn, conn_num)

    async def _drain_tasks(self, conn: Any, conn_num: int) -> None:
        """Take every queued task of *conn*.

        The native layer signals the fd once and not again until the queue
        has been seen empty, so this must keep going until it is.
        """
        poller = self.pollers[bool(conn.server_mode)]
        while conn in self.connections:
            task = poller(conn_num)
            if task is None:
                return
            try:
                await self._dispatch_task(conn, conn_num, task)
            except Exception:
                conn.logger.exception("Task dispatch failed")

    async def _dispatch_task(self, conn: Any, conn_num: int, task: tuple) -> None:
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
            return
        task_item = (
            uuid,
            data,
            serde,
            transmitter,
            func_name,
            return_result,
            conn_num,
            bool(conn.server_mode),
            conn.logger,
        )
        if self.workers == 1:
            await self._run_task(*task_item)
        else:
            self.queue.put_nowait(task_item)

    async def _handle_lifecycle_signal(
        self, conn: Any, conn_num: int, reason: bytes
    ) -> None:
        """Async counterpart of ``_task_dispatcher._handle_lifecycle_signal``.

        ``stop()`` cancels the poller, so it runs as its own task.
        """
        from daffi.aio._rpc_proxy import AsyncResponseNotifier, AsyncRpcProxy

        if reason == LifecycleSignal.INIT:
            await asyncio.get_running_loop().run_in_executor(
                None, AsyncRpcProxy._process_client_handshake, conn_num
            )
            conn._register_executors()
            return

        if reason == LifecycleSignal.NORMAL:
            self._stop_in_background(conn)
            return

        evicted = reason == LifecycleSignal.EVICTED
        if not evicted and isinstance(conn._connection_error, Evicted):
            # The server closes an evicted connection; that close is not news.
            return
        err = connection_lost_error(evicted, conn.app_name)
        AsyncResponseNotifier.signal_lifecycle_error(conn_num, err)
        conn._connection_error = err
        conn._disconnected = True

        if conn._joining:
            self._stop_in_background(conn)
        else:
            conn.logger.error(f"Error in connection {conn_num}: {err}")

    def _stop_in_background(self, conn: Any) -> None:
        task = asyncio.ensure_future(conn.stop())
        self._stop_tasks.add(task)
        task.add_done_callback(self._stop_tasks.discard)

    @staticmethod
    async def _dispatch_event(conn: Any, payload: dict) -> None:
        """Route an EVENTS payload to the connection's typed handlers.

        Both sync and coroutine handlers are supported; one failing handler
        does not stop the others.
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
            try:
                result = handler(member)
                if asyncio.iscoroutine(result):
                    await result
            except Exception:
                conn.logger.exception(f"Event handler {handler!r} failed")
