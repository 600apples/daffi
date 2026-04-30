"""
Background threads that dispatch incoming RPC tasks to registered
``@callback`` executors.

Notification strategy
---------------------
For Service connections the native layer writes to a per-connection
``os.eventfd`` (Linux) or pipe (macOS / other) whenever a new message is pushed
onto the task queue.  The poller thread blocks on ``select.select`` over all
registered fds — zero CPU when idle, sub-millisecond wake latency.

For Client connections (bidirectional nodes with registered callbacks) the same
architecture is used if the native side exposes a wakeup fd; otherwise a short
fixed-interval poll (1 ms) is the fallback.

Execution modes
---------------
workers=1 (default)
    Callbacks are executed **inline** inside the poller thread — no queue, no
    extra thread context-switch.  "1 worker" means the poller thread is the
    sole executor; no additional thread is spawned.  This is the fastest mode
    and the right choice for fast / I/O-bound callbacks.

workers=N (thread pool)
    A pool of exactly N dedicated worker **threads** picks tasks off a shared
    ``queue.Queue`` and executes them in parallel.  Good for I/O-bound
    callbacks; the GIL limits CPU parallelism.
"""

import json
import selectors
import sys
from queue import Queue
from threading import Thread, Event
from typing import Any, NamedTuple

from . import dfcore
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._serialization import Serializer, SerdeFormat
from daffi._wakeup import WakeupFd
from daffi._bindings import (
    send_message_from_client,
    send_message_from_service,
    set_request_fd,
    MessageFlag,
)

_tblib_installed = False
try:
    import tblib.pickling_support

    tblib.pickling_support.install()
    _tblib_installed = True
except ImportError:
    # tblib is optional; without it, exception tracebacks in RPC errors will
    # not be picklable and will arrive without a full remote stack trace.
    pass


class EventType(str):
    """String constants for peer-lifecycle event types emitted by daffi."""

    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    EVICTED = "evicted"


_SENDERS = (send_message_from_client, send_message_from_service)


class ConnWakeups(NamedTuple):
    """Both wakeup fds associated with a single connection."""

    task: WakeupFd  # written by Zig when a new task is queued
    stop: WakeupFd  # written by Python when the connection is deregistered


def _invoke_callback(
    func_name: str,
    serde: "SerdeFormat",
    data: bytes,
) -> "tuple[Any, int, SerdeFormat]":
    """Deserialise *data*, call the registered callback, and return the outcome.

    Returns:
        ``(result, flag, serde)`` where *flag* is ``MessageFlag.RESPONSE`` on
        success or ``MessageFlag.ERROR`` on failure, and *serde* may have been
        promoted from ``OPAQUE`` to ``PICKLE`` when an exception is raised
        (error payloads must always be picklable).
    """
    cb = EXECUTOR_REGISTRY.get(func_name)
    args, kwargs = Serializer.deserialize(serde, data)
    try:
        result = cb(*args, **kwargs)
        return result, MessageFlag.RESPONSE, serde
    except:  # noqa: E722
        if serde == SerdeFormat.OPAQUE:
            serde = SerdeFormat.PICKLE
        err_type, err_obj, tb = sys.exc_info()
        # Include the raw traceback only when tblib is installed; without it
        # pickle.dumps(tb) raises PicklingError and would silently kill the
        # worker thread, leaving the caller to time out instead of getting
        # the remote error message.
        include_tb = _tblib_installed and serde == SerdeFormat.PICKLE
        result = (
            err_type.__name__,
            err_type.__module__,
            str(err_obj),
            tb if include_tb else None,
        )
        return result, MessageFlag.ERROR, serde


def _send_response(
    sender,
    result_bytes: bytes,
    flag: int,
    serde: "SerdeFormat",
    transmitter: str,
    func_name: str,
    conn_num: int,
    is_bytes: bool,
    uuid: int,
) -> None:
    sender(
        data=result_bytes,
        flag=flag,
        serde=serde,
        receiver=transmitter,
        func_name=func_name,
        return_result=False,
        conn_num=conn_num,
        is_bytes=is_bytes,
        uuid=uuid,
    )


def _execute_task(
    uuid: int,
    data: bytes,
    serde: SerdeFormat,
    transmitter: str,
    func_name: str,
    return_result: bool,
    conn: Any,
) -> None:
    """Invoke a registered callback and send the response inline.

    Called only for regular RPC tasks on the inline (workers=1) path.
    EVENTS dispatching and worker-pool routing are handled by the caller.
    """
    result, flag, serde = _invoke_callback(func_name, serde, data)

    if return_result:
        result_bytes, is_bytes = Serializer.serialize(serde, result)
        _send_response(
            _SENDERS[bool(conn.server_mode)],
            result_bytes,
            flag,
            serde,
            transmitter,
            func_name,
            conn._conn_num,
            is_bytes,
            uuid,
        )


class TaskDispatcher:
    """Manages the lifecycle of worker threads that handle incoming RPC
    messages for one or more server/client connections.

    Args:
        workers: Concurrency level for callback execution.

                 * ``1`` (default) — callbacks run **inline** in the poller
                   thread.  Zero overhead; ideal for fast / I/O-bound callbacks.
                 * ``N >= 2`` — a pool of exactly N worker threads executes
                   callbacks concurrently.

    Raises:
        ValueError: If *workers* is less than 1.
    """

    DEFAULT_WORKERS = 1  # inline execution — fastest for typical callbacks

    def __init__(
        self,
        workers: int = DEFAULT_WORKERS,
    ) -> None:
        if workers < 1:
            raise ValueError(
                f"workers must be >= 1 (got {workers!r}). "
                "Use workers=1 for inline (single-threaded) execution."
            )
        self.workers = workers
        self.connections: set = set()
        self.pollers = (
            dfcore.getMessageForClientWorker,
            dfcore.getMessageForServerWorker,
        )

        self.stop_event = Event()
        self.queue: Queue = Queue()

        # Thread objects for the worker pool (workers >= 2).
        self._workers: list = []
        # Poller thread — always a Thread; None until first start_for_connection.
        self._poller: "Thread | None" = None

        self._stop_wakeup: WakeupFd = WakeupFd()

        # conn_num → ConnWakeups(task, stop)
        self._conn_wakeups: dict[int, ConnWakeups] = {}
        # task wakeup read_fd → connection object (poller drains + notifies)
        self._task_fd_to_conn: dict[int, Any] = {}
        # stop wakeup read_fd → connection object (poller just wakes + rebuilds)
        self._stop_fd_to_conn: dict[int, Any] = {}

    def _start_workers(self) -> None:
        """Start the worker-thread pool.

        Worker threads immediately block on ``queue.get()`` and idle until
        the poller delivers work; starting them early costs nothing.

        No-op when ``workers == 1`` (inline mode) or the pool is already
        running.
        """
        if self._workers or self.workers == 1:
            return
        for i in range(self.workers):
            t = Thread(
                target=self._worker_loop,
                name=f"daffi-worker-{i}",
            )
            t.start()
            self._workers.append(t)

    def stop_for_connection(self, connection) -> None:
        """Deregister *connection* and, if no connections remain, stop all workers.

        **Ordering guarantee**: the poller thread is joined *before* any
        wakeup/disconnect fds are closed.  Closing an fd while the poller is
        blocked in ``select.select`` on that same fd is undefined behaviour
        on macOS (the fd number may be reused by the OS, causing select to
        report activity on the wrong resource, or worse, a SIGSEGV when
        kqueue's internal state is corrupted).

        The poller uses ``select.select(timeout=None)`` (infinite wait) and
        is woken via ``_stop_wakeup`` rather than via a fixed poll interval.
        This means idle poller threads block without ever acquiring the GIL.
        """
        self.connections.discard(connection)
        conn_num = getattr(connection, "_conn_num", None)
        if not self.connections:
            # Signal the poller to exit.  Order matters:
            # 1. set stop_event so the loop condition is True after wakeup.
            # 2. write to _stop_wakeup so select.select(None) returns.
            # 3. join the poller (it will exit cleanly after seeing stop_event).
            # 4. close _stop_wakeup fd — safe because the poller has exited.
            self.stop_event.set()
            self._stop_wakeup.signal()
            # Send one sentinel per worker so each exits its loop cleanly.
            for _ in self._workers:
                try:
                    self.queue.put_nowait(None)
                except Exception:
                    pass
            for w in self._workers:
                w.join(timeout=3)
            if self._poller is not None:
                self._poller.join()
            self._stop_wakeup.close()
            # Reset so the dispatcher can be reused if new connections arrive
            # later (e.g. a Service that temporarily has no clients between a
            # readiness probe disconnecting and the real test clients connecting).
            self._poller = None
            self._workers.clear()
            self._stop_wakeup = WakeupFd()
            self.stop_event.clear()
        # Deregister (and close) fds only after the poller has exited for the
        # last-connection case, or immediately for the non-last case (the
        # poller will see a ValueError on the next select call, catch it, and
        # rebuild all_fds without the now-closed fd).
        self._deregister_fds(conn_num)

    def _deregister_fds(self, conn_num) -> None:
        """Remove per-connection fds for *conn_num* without stopping threads.

        Signals the per-connection stop wakeup fd before closing anything so
        the poller (blocked in ``sel.select(timeout=None)``) wakes up and
        rebuilds its selector without the deregistered fds.

        Safe to call from any thread during reconnect.  The lifecycle pipe
        is managed separately by the watcher thread in
        :meth:`~daffi.app.Client._start_disconnect_watcher`.
        """
        if conn_num is None:
            return
        fds = self._conn_wakeups.pop(conn_num, None)
        if fds is None:
            return
        self._task_fd_to_conn.pop(fds.task.read_fd, None)
        self._stop_fd_to_conn.pop(fds.stop.read_fd, None)
        # Wake the poller BEFORE closing fds so it exits sel.select cleanly.
        fds.stop.signal()
        fds.stop.close()
        fds.task.close()

    def start_for_connection(self, connection) -> None:
        """Register *connection* and start background workers if not already running."""
        assert connection._conn_num is not None
        self.connections.add(connection)

        conn_num: int = connection._conn_num
        server = bool(connection.server_mode)

        task = WakeupFd()
        stop = WakeupFd()
        self._conn_wakeups[conn_num] = ConnWakeups(task, stop)
        self._task_fd_to_conn[task.read_fd] = connection
        self._stop_fd_to_conn[stop.read_fd] = connection

        set_request_fd(conn_num, task.write_fd, server_mode=server)
        if server:
            # Kick once so tasks that arrived between startServer() opening the
            # port and this set_request_fd() call are not silently lost.
            task.signal()

        if self._poller is None:
            # Workers may already be running (pre-started by _start_workers()
            # before dfcore.startServer/Client); _start_workers() is a no-op
            # if the pool is already populated.
            self._start_workers()

            self._poller = Thread(
                target=self.handle_task_queue,
                name="daffi-poller",
                daemon=True,
            )
            self._poller.start()
        else:
            # Poller is already running but blocked in sel.select(timeout=None)
            # with a stale fd set.  Signal _stop_wakeup so it wakes up and
            # rebuilds its selector to include the newly registered fds.
            self._stop_wakeup.signal()

    # ------------------------------------------------------------------

    def handle_task_queue(self) -> None:
        """Wait for native notifications, then execute or enqueue each task.

        * ``workers == 1``: callbacks run inline — no queue, no hand-off.
        * ``workers  > 1``: tasks go into ``self.queue``.  EVENTS messages are
          always run inline because their handlers hold a reference to the
          ``conn`` object.

        I/O multiplexing strategy
        -------------------------
        The poller uses ``selectors.DefaultSelector`` (kqueue on macOS, epoll
        on Linux) with ``timeout=None`` (infinite wait).

        The selector watches three kinds of fds:

        * **global stop** (``_stop_wakeup``) — written by ``stop_for_connection``
          when the last connection is removed (``stop_event`` is also set), and
          by ``start_for_connection`` when a new connection is added (so the
          poller rebuilds its fd set to include the new wakeup fds).

        * **per-connection task wakeup** (``_wakeup``) — written by the Zig
          native layer via ``set_request_fd`` whenever a new task is pushed to a
          connection's queue.  This now applies to *both* server and client
          connections.

        * **per-connection stop wakeup** (``_conn_stop``) — written by Python
          from ``_deregister_fds`` when a specific connection is being removed.
          This wakes ``sel.select(timeout=None)`` so the poller rebuilds its fd
          set without the deregistered connection.

        The poller rebuilds the selector on every iteration.  This is efficient
        because an iteration only runs when a real event occurs; idle threads
        never execute the loop body.
        """
        inline = self.workers == 1
        stop_rfd = self._stop_wakeup.read_fd

        while not self.stop_event.is_set():
            all_fds = (
                [stop_rfd] + list(self._task_fd_to_conn) + list(self._stop_fd_to_conn)
            )

            # Build a fresh selector with the current fd set.  We rebuild it
            # on every iteration rather than maintaining it incrementally so
            # that closed fds (after _deregister_fds) are never selected on.
            readable: set = set()
            sel = selectors.DefaultSelector()
            try:
                for fd in all_fds:
                    try:
                        sel.register(fd, selectors.EVENT_READ)
                    except (ValueError, OSError):
                        pass
                events = sel.select(timeout=None)
                readable = {key.fd for key, _ in events}
            except OSError:
                pass
            finally:
                sel.close()

            # Global stop: exit when stop_event is set; otherwise a new
            # connection was added — drain and rebuild.
            if stop_rfd in readable:
                if self.stop_event.is_set():
                    break
                self._stop_wakeup.drain()

            # --- Handle wakeup notifications ---
            notified: set = set()
            for rfd in readable:
                conn = self._task_fd_to_conn.get(rfd)
                if conn is None:
                    continue
                fds = self._conn_wakeups.get(conn._conn_num)
                if fds:
                    fds.task.drain()
                notified.add(conn)

            for conn in list(self.connections):
                if (
                    conn._conn_num in self._conn_wakeups
                    and conn not in notified
                    and notified
                ):
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
                        receiver,
                        func_name,
                        return_result,
                    ) = task

                    if flag == MessageFlag.EVENTS:
                        self._dispatch_event(conn, json.loads(data))
                    elif inline:
                        _execute_task(
                            uuid,
                            data,
                            serde,
                            transmitter,
                            func_name,
                            return_result,
                            conn,
                        )
                    else:
                        self.queue.put(
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
    def _dispatch_event(conn, payload: dict) -> None:
        """Route an EVENTS payload to the typed handlers registered on *conn*.

        Called inline on the poller thread (never enqueued) so that handlers
        always execute in arrival order and have immediate access to the
        connection object.

        Routing rules
        -------------
        * ``EventType.CONNECTED``               → :attr:`_on_member_added_handlers`
        * ``EventType.DISCONNECTED`` / EVICTED  → :attr:`_on_member_removed_handlers`

        Both handler lists are iterated in registration order.
        Eviction is treated as a departure so ``on_member_removed`` fires for
        both clean disconnects and last-connection-wins evictions.
        """
        event_type: str = payload["type"]
        member: str = payload["member"]

        if event_type == EventType.CONNECTED:
            for handler in conn._on_member_added_handlers:
                handler(member)
        elif event_type in (EventType.DISCONNECTED, EventType.EVICTED):
            for handler in conn._on_member_removed_handlers:
                handler(member)

    def _worker_loop(self) -> None:
        """Thread-pool worker body.

        Blocks on ``self.queue.get()`` until a task arrives or a ``None``
        sentinel is received.  The sentinel is placed by :meth:`stop_for_connection`
        (one per worker), so no polling or ``stop_event`` check is needed here —
        the worker exits immediately when told to, without waiting for a timeout.
        """
        for task in iter(self.queue.get, None):
            (
                uuid,
                data,
                flag,
                serde,
                transmitter,
                func_name,
                return_result,
                conn_num,
                server_mode_bool,
            ) = task

            result, flag, serde = _invoke_callback(func_name, serde, data)

            if not return_result:
                continue

            result_bytes, is_bytes = Serializer.serialize(serde, result)
            _send_response(
                _SENDERS[server_mode_bool],
                result_bytes,
                flag,
                serde,
                transmitter,
                func_name,
                conn_num,
                is_bytes,
                uuid,
            )
