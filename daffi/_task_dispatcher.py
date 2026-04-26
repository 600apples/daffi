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
from typing import Any

from . import dfcore
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._serialization import Serializer, SerdeFormat
from daffi._wakeup import WakeupFd
from daffi._bindings import (
    send_message_from_client,
    send_message_from_service,
    set_wakeup_fd,
    set_client_wakeup_fd,
    set_client_disconnect_fd,
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
    """String constants for the two peer-lifecycle event types emitted by daffi."""

    CONNECTED    = "connected"
    DISCONNECTED = "disconnected"


_SENDERS = (send_message_from_client, send_message_from_service)


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

        # conn_num → _WakeupFd
        self._wakeup: dict[int, WakeupFd] = {}
        # read_fd → connection object
        self._fd_to_conn: dict[int, Any] = {}
        # read_fd → (conn_num, callback, _WakeupFd) for disconnect notifications
        self._disc_by_rfd: dict[int, tuple] = {}

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
        # Deregister (and close) fds only after the poller has exited for the
        # last-connection case, or immediately for the non-last case (the
        # poller will see a ValueError on the next select call, catch it, and
        # rebuild all_fds without the now-closed fd).
        self._deregister_fds(conn_num)

    def _deregister_fds(self, conn_num) -> None:
        """Remove wakeup and disconnect fds for *conn_num* without stopping threads.

        Safe to call from the poller thread during reconnect.
        """
        if conn_num is None:
            return
        if conn_num in self._wakeup:
            wakeup = self._wakeup.pop(conn_num)
            self._fd_to_conn.pop(wakeup.read_fd, None)
            wakeup.close()
        # Remove any pending disconnect fd for this conn_num.
        to_remove = [
            rfd for rfd, (cn, _, _) in self._disc_by_rfd.items() if cn == conn_num
        ]
        for rfd in to_remove:
            _, _, disc = self._disc_by_rfd.pop(rfd)
            disc.close()

    def register_disconnect(self, conn_num: int, callback) -> None:
        """Register an event-driven disconnect notification for *conn_num*.

        Creates a pipe whose write end is handed to the native layer.  When the
        connection drops the native layer writes to it; the poller thread wakes
        from ``select.select``, drains the fd, and calls *callback(conn_num)*.

        *callback* is invoked **from the poller thread** and may block (e.g.
        during a reconnect retry loop) — that is intentional: the connection is
        dead anyway so stalling the poller is acceptable.
        """
        disc = WakeupFd()
        self._disc_by_rfd[disc.read_fd] = (conn_num, callback, disc)
        set_client_disconnect_fd(conn_num, disc.write_fd)

    def start_for_connection(self, connection) -> None:
        """Register *connection* and start background workers if not already running."""
        assert connection._conn_num is not None
        self.connections.add(connection)

        conn_num: int = connection._conn_num
        wakeup = WakeupFd()
        self._wakeup[conn_num] = wakeup
        self._fd_to_conn[wakeup.read_fd] = connection
        if bool(connection.server_mode):
            set_wakeup_fd(conn_num, wakeup.write_fd)
        else:
            set_client_wakeup_fd(conn_num, wakeup.write_fd)

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

        Shutdown is signalled by writing to ``_stop_wakeup`` which causes
        the selector to return; the loop then checks ``stop_event.is_set()``.
        """
        inline = self.workers == 1
        stop_rfd = self._stop_wakeup.read_fd

        while not self.stop_event.is_set():
            wakeup_fds = list(self._fd_to_conn.keys())
            disc_fds = list(self._disc_by_rfd.keys())
            all_fds = [stop_rfd] + wakeup_fds + disc_fds

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

            # Stop signal: exit the loop immediately without processing tasks.
            if stop_rfd in readable:
                break

            # --- Handle disconnect notifications first ---
            for rfd in readable:
                if rfd not in self._disc_by_rfd:
                    continue
                conn_num, callback, disc = self._disc_by_rfd.pop(rfd)
                disc.drain()
                disc.close()
                try:
                    callback(conn_num)
                except Exception:
                    pass

            # --- Handle normal wakeup notifications ---
            notified: set = set()
            for rfd in readable:
                conn = self._fd_to_conn.get(rfd)
                if conn is None:
                    continue
                wakeup = self._wakeup.get(conn._conn_num)
                if wakeup:
                    wakeup.drain()
                notified.add(conn)

            for conn in list(self.connections):
                is_eventfd_backed = conn._conn_num in self._wakeup
                if is_eventfd_backed and conn not in notified:
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
