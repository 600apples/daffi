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
    A pool of N-1 dedicated worker **threads** picks tasks off a shared
    ``queue.Queue`` and executes them in parallel.  Good for I/O-bound
    callbacks; the GIL limits CPU parallelism.
"""

import json
import selectors
import sys
import threading
from queue import Queue
from threading import Thread, Event
from typing import Any, NamedTuple

from . import dfcore
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._serialization import Serializer, SerdeFormat
from daffi._wakeup import WakeupFd, LifecycleSignal
from daffi._bindings import (
    send_message_from_client,
    send_message_from_service,
    set_request_fd,
    set_lifecycle_fd,
    MessageFlag,
)
from daffi.exceptions import Disconnected, Evicted
from daffi._rpc_proxy import ResponseNotifier, RpcProxy

_tblib_installed = False
try:
    import tblib.pickling_support

    tblib.pickling_support.install()
    _tblib_installed = True
except ImportError:
    # tblib is optional; without it, exception tracebacks in RPC errors will
    # not be picklable and will arrive without a full remote stack trace.
    pass


class _ConnEntry(NamedTuple):
    """All fd-related state for one registered connection, keyed by conn_num."""

    conn: Any
    wakeup: WakeupFd  # task-arrival channel (eventfd on Linux, pipe on macOS)
    lifecycle: WakeupFd  # lifecycle / stop channel (always a pipe)


class EventType(str):
    """String constants for the two peer-lifecycle event types emitted by daffi."""

    CONNECTED = "connected"
    DISCONNECTED = "disconnected"


_SENDERS = (send_message_from_client, send_message_from_service)


def _handle_lifecycle_signal(conn, conn_num: int, reason: bytes) -> None:
    """React to a lifecycle byte written by the native layer into a Client's
    lifecycle fd.  Executed inline on the poller thread.

    ``LifecycleSignal.INIT`` re-runs the handshake and returns normally.

    All disconnect variants (DISCONNECTED, EVICTED, NORMAL) wake in-flight
    RPC waiters, store the error on *conn*, log it if the caller is not
    blocking in ``join()``, then always call ``conn.stop()`` to release
    resources.  By the time ``stop()`` is called every in-flight waiter has
    already received the error via ``signal_lifecycle_error``, so there is
    no race with ``RpcResult.result()``.
    """
    if reason == LifecycleSignal.INIT:
        RpcProxy._process_client_handshake(conn_num)
        conn._register_executors()
        return

    if reason == LifecycleSignal.NORMAL:
        # Graceful server-side shutdown — mirror a user-initiated stop():
        # tear down cleanly, unblock join() if waiting, surface no error.
        conn.stop()
        return

    if reason == LifecycleSignal.EVICTED:
        err: Exception = Evicted(
            f"This client (app_name={conn.app_name!r}) was evicted — "
            "a new connection with the same app_name took over its slot."
        )
    else:  # DISCONNECTED or any unknown byte
        err = Disconnected(
            "Server disconnected unexpectedly.\n\n"
            "  The router or service this client was connected to has stopped."
        )

    ResponseNotifier.signal_lifecycle_error(conn_num, err)
    conn._connection_error = err
    conn._disconnected = True

    if not conn._joining:
        conn.logger.debug(f"Error in connection {conn_num}: {err!r}")
    conn.stop()


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
        result, is_bytes = Serializer.serialize(serde, result)
        _SENDERS[bool(conn.server_mode)](
            data=result,
            flag=flag,
            serde=serde,
            receiver=transmitter,
            func_name=func_name,
            return_result=False,
            conn_num=conn._conn_num,
            is_bytes=is_bytes,
            uuid=uuid,
        )


class TaskDispatcher:
    """Manages the lifecycle of worker threads that handle incoming RPC
    messages for one or more server/client connections.

    Args:
        workers: Concurrency level for callback execution.

                 * ``1`` (default) — callbacks run **inline** in the poller
                   thread.  Zero overhead; ideal for fast / I/O-bound callbacks.
                 * ``N >= 2`` — a pool of N-1 worker threads executes callbacks
                   concurrently.

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

        # conn_num → _ConnEntry  (all fd-related state for a connection)
        self._conns: dict[int, _ConnEntry] = {}
        # read_fd → conn_num  (covers both wakeup and lifecycle fds; used to
        # route readable events back to the right _ConnEntry without scanning)
        self._rfd_to_conn_num: dict[int, int] = {}

    def _start_workers(self) -> None:
        """Start the worker-thread pool.

        Worker threads immediately block on ``queue.get()`` and idle until
        the poller delivers work; starting them early costs nothing.

        No-op when ``workers == 1`` (inline mode) or the pool is already
        running.
        """
        if self._workers:
            return
        for i in range(self.workers - 1):
            t = Thread(
                target=self._worker_loop,
                name=f"daffi-worker-{i}",
            )
            t.start()
            self._workers.append(t)

    def stop_for_connection(self, connection) -> None:
        """Deregister *connection* and, if no connections remain, stop all workers.

        **Ordering guarantee**: the poller thread is joined *before* any
        wakeup/lifecycle fds are closed.  Closing an fd while the poller is
        blocked in ``select`` on that same fd is undefined behaviour on macOS
        (the fd number may be reused, causing select to report activity on the
        wrong resource, or a SIGSEGV from kqueue's internal state).

        The poller blocks indefinitely on ``DefaultSelector.select(timeout=None)``.
        It is woken by writing ``LifecycleSignal.STOP`` to the connection's
        lifecycle fd — every connection always has one (created in
        :meth:`start_for_connection`).
        """
        self.connections.discard(connection)
        conn_num = getattr(connection, "_conn_num", None)
        if not self.connections:
            # 1. flip stop_event so the loop exits after the next wakeup.
            # 2. write b"s" to the lifecycle fd to unblock select (skip when
            #    called from the poller thread itself to avoid a deadlock —
            #    the poller will exit naturally because stop_event is set).
            # 3. join workers and poller (skip poller join when inside it).
            # 4. close fds (safe — poller has fully exited or will exit).
            self.stop_event.set()
            in_poller = threading.current_thread() is self._poller
            if not in_poller:
                entry = self._conns.get(conn_num)
                if entry is not None:
                    entry.lifecycle.write(LifecycleSignal.STOP)
            # Send one sentinel per worker so each exits its loop cleanly.
            for _ in self._workers:
                try:
                    self.queue.put_nowait(None)
                except Exception:
                    pass
            for w in self._workers:
                w.join(timeout=3)
            if self._poller is not None and not in_poller:
                self._poller.join()
            # Close lifecycle fds after the poller has exited so we never
            # close an fd that the poller is still blocked on.
            self._close_lifecycle(conn_num)
        # Deregister (and close) fds only after the poller has exited for the
        # last-connection case, or immediately for the non-last case (the
        # poller will see a ValueError on the next select call, catch it, and
        # rebuild all_fds without the now-closed fd).
        self._deregister_fds(conn_num)

    def _deregister_fds(self, conn_num) -> None:
        """Close the wakeup fd for *conn_num* and remove it from the reverse map.

        Safe to call at any time (including from the poller thread during
        reconnect).  The lifecycle fd is intentionally left open here — it is
        closed by :meth:`_close_lifecycle` only after the poller has exited.
        """
        if conn_num is None:
            return
        entry = self._conns.get(conn_num)
        if entry is not None:
            self._rfd_to_conn_num.pop(entry.wakeup.read_fd, None)
            entry.wakeup.close()

    def _close_lifecycle(self, conn_num) -> None:
        """Close the lifecycle fd and remove the entire entry for *conn_num*.

        Must only be called after the poller has exited (no concurrent select).
        """
        entry = self._conns.pop(conn_num, None)
        if entry is not None:
            self._rfd_to_conn_num.pop(entry.lifecycle.read_fd, None)
            entry.lifecycle.close()

    def start_for_connection(self, connection) -> None:
        """Register *connection* and start background workers if not already running."""
        assert connection._conn_num is not None
        self.connections.add(connection)

        conn_num: int = connection._conn_num

        wakeup = WakeupFd()
        # Lifecycle fd is always a pipe so reason bytes survive the round-trip.
        # Service connections use it only for b"s" (STOP); Client connections
        # also have the write-end handed to the native layer so Zig can write
        # LifecycleSignal bytes directly into the poller's fd set.
        lc = WakeupFd(pipe=True)

        self._conns[conn_num] = _ConnEntry(conn=connection, wakeup=wakeup, lifecycle=lc)
        self._rfd_to_conn_num[wakeup.read_fd] = conn_num
        self._rfd_to_conn_num[lc.read_fd] = conn_num

        set_request_fd(
            conn_num, wakeup.write_fd, server_mode=bool(connection.server_mode)
        )
        if connection.server_mode is None:
            set_lifecycle_fd(conn_num, lc.write_fd)

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

    # ------------------------------------------------------------------

    def handle_task_queue(self) -> None:
        """Wait for native notifications, then execute or enqueue each task.

        * ``workers == 1``: callbacks run inline — no queue, no hand-off.
        * ``workers  > 1``: tasks go into ``self.queue``.  EVENTS messages are
          always run inline because their handlers hold a reference to the
          ``conn`` object.

        Disconnect fds are also monitored here.  When one fires the registered
        callback is invoked directly in this thread.

        I/O multiplexing strategy
        -------------------------
        The poller uses ``selectors.DefaultSelector`` (kqueue on macOS, epoll
        on Linux) with ``timeout=None`` (infinite wait).  This has two
        advantages over ``select.select``:

        1. **No fd-number limit.** ``select.select`` silently misbehaves or
           raises ``ValueError`` when any fd number ≥ 1024 (macOS / POSIX
           ``FD_SETSIZE``).  With N router-connected clients each holding 7-9
           fds this threshold is reached around N = 110-140.  kqueue and epoll
           have no such limitation.

        2. **Zero idle GIL pressure.** A fixed poll interval (e.g. 1 ms)
           forces every idle poller to wake up, acquire the GIL, find nothing
           to do, and sleep again — with N clients this creates N spurious GIL
           acquisitions per millisecond, starving the main thread.  With
           ``timeout=None`` idle threads stay fully asleep.

        The poller rebuilds the selector on every iteration.  This is
        efficient because an iteration only runs when a real event occurs
        (a task arrives, a disconnect fires, or shutdown is requested);
        idle threads never execute the loop body.  The cost of one
        kqueue/epoll open + a handful of kevent/epoll_ctl registrations
        per event is negligible.

        Shutdown is signalled by writing ``LifecycleSignal.STOP`` to the
        connection's lifecycle fd, which causes the selector to return; the
        loop then checks ``stop_event.is_set()``.
        """
        inline = self.workers == 1

        while not self.stop_event.is_set():
            # Build a fresh selector over every registered fd (wakeup + lifecycle).
            # Rebuilt each iteration so closed fds never sneak back in.
            all_fds = list(self._rfd_to_conn_num.keys())
            readable = set()
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

            # --- Dispatch all readable fds in one pass ---
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
                    _handle_lifecycle_signal(entry.conn, conn_num, reason)
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
        * ``EventType.CONNECTED``    → :attr:`_on_member_added_handlers`   (receives member name)
        * ``EventType.DISCONNECTED`` → :attr:`_on_member_removed_handlers` (receives member name)

        Both handler lists are iterated in registration order.
        """
        event_type: str = payload["type"]
        member: str = payload["member"]

        if event_type == EventType.CONNECTED:
            for handler in conn._on_member_added_handlers:
                handler(member)
        elif event_type == EventType.DISCONNECTED:
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
            _SENDERS[server_mode_bool](
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
