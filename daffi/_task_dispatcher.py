"""
Background threads (or processes) that dispatch incoming RPC tasks to
registered ``@callback`` executors.

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

workers=N, use_processes=False (default thread pool)
    A pool of N-1 dedicated worker **threads** picks tasks off a shared
    ``queue.Queue`` and executes them in parallel.  Good for I/O-bound
    callbacks; the GIL limits CPU parallelism.

workers=N, use_processes=True (process pool)
    A pool of N-1 worker **processes** is forked at startup.  Each process
    inherits a copy of ``EXECUTOR_REGISTRY`` at fork time, executes the
    callback, and sends the serialised result back to the main process via a
    ``multiprocessing.Queue``.  A lightweight result-collector thread in the
    main process reads that queue and calls the native sender — the native
    connection handle never leaves the main process.

    Use this for CPU-bound callbacks where Python's GIL would otherwise
    serialise execution across threads.

    Limitation: ``@callback`` functions registered *after* the process pool
    has been forked are not visible in the worker processes.  Register all
    callbacks before calling ``start()`` / ``connect()``.
"""

import json
import multiprocessing as mp
import os
import select
import fcntl
import signal
import sys
import time
from queue import Queue
from threading import Thread, Event
from typing import Any

from . import dfcore
from daffi.registry._executor_registry import EXECUTOR_REGISTRY, SharedDict
from daffi._serialization import Serializer, SerdeFormat
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


_HAS_EVENTFD = hasattr(os, "eventfd")

_SENDERS = (send_message_from_client, send_message_from_service)


class _WakeupFd:
    """One-shot notification channel: ``os.eventfd`` on Linux, ``os.pipe`` elsewhere.

    Zig writes to :attr:`write_fd`; Python blocks on :attr:`read_fd` via
    ``select.select``.  Both fds are non-blocking so that a missed signal
    (counter already > 0) never stalls the native thread.
    """

    __slots__ = ("read_fd", "write_fd", "_is_eventfd")

    def __init__(self) -> None:
        if _HAS_EVENTFD:
            # EFD_NONBLOCK — writes from Zig never block; drain from Python is
            # also non-blocking (we guard with select first anyway).
            fd = os.eventfd(0, os.EFD_NONBLOCK)
            self.read_fd: int = fd
            self.write_fd: int = fd  # same fd for eventfd
            self._is_eventfd = True
        else:
            r, w = os.pipe()
            # Make write end non-blocking so Zig is never stalled.
            flags = fcntl.fcntl(w, fcntl.F_GETFL)
            fcntl.fcntl(w, fcntl.F_SETFL, flags | os.O_NONBLOCK)
            self.read_fd = r
            self.write_fd = w
            self._is_eventfd = False

    def drain(self) -> None:
        """Consume pending notification(s) so the fd becomes unreadable again."""
        try:
            # eventfd: 8-byte uint64; pipe: drain up to 4 KiB of pending bytes.
            os.read(self.read_fd, 8 if self._is_eventfd else 4096)
        except OSError:
            pass

    def close(self) -> None:
        """Release both ends of the fd."""
        try:
            os.close(self.read_fd)
        except OSError:
            pass
        if not self._is_eventfd:
            try:
                os.close(self.write_fd)
            except OSError:
                pass


class _ForkedWorker:
    """Thin wrapper around a raw ``os.fork()`` child PID.

    Provides the same ``.is_alive()`` / ``.terminate()`` / ``.join()``
    interface as ``threading.Thread`` so the rest of ``TaskDispatcher`` can
    treat thread-pool and process-pool workers uniformly.

    Using ``os.fork()`` directly (rather than ``multiprocessing.Process``)
    avoids Python's multiprocessing resource-tracker machinery, which can
    deadlock or corrupt its semaphore accounting when processes are nested
    (e.g. a benchmark that itself forks a service subprocess which then tries
    to fork its worker pool via ``mp.Process``).
    """

    __slots__ = ("pid",)

    def __init__(self, pid: int) -> None:
        self.pid = pid

    def is_alive(self) -> bool:
        try:
            os.kill(self.pid, 0)
            return True
        except OSError:
            return False

    def terminate(self) -> None:
        try:
            os.kill(self.pid, signal.SIGTERM)
        except OSError:
            pass

    def join(self, timeout: "float | None" = None) -> None:
        """Wait for the child to exit, optionally up to *timeout* seconds."""
        deadline = (time.monotonic() + timeout) if timeout is not None else None
        while True:
            try:
                pid, _ = os.waitpid(self.pid, os.WNOHANG)
                if pid != 0:
                    return  # reaped
            except ChildProcessError:
                return  # already reaped
            if deadline is not None and time.monotonic() >= deadline:
                return
            time.sleep(0.05)


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
        result = (err_type.__name__, err_type.__module__, str(err_obj), tb if include_tb else None)
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
    """Manages the lifecycle of worker threads or processes that handle incoming
    RPC messages for one or more server/client connections.

    Args:
        workers: Concurrency level for callback execution.

                 * ``1`` (default) — callbacks run **inline** in the poller
                   thread.  Zero overhead; ideal for fast / I/O-bound callbacks.
                 * ``N >= 2`` — a pool of N-1 workers executes callbacks
                   concurrently.  Whether those workers are threads or processes
                   is controlled by *use_processes*.

        use_processes: When ``False`` (default) worker slots are OS threads
                       (good for I/O-bound work).  When ``True`` worker slots
                       are forked **processes** that bypass the GIL — use this
                       for CPU-bound callbacks.  Ignored when ``workers == 1``.

                       Workers are forked at :meth:`_start_workers` time.
                       Callbacks registered *after* that point are propagated
                       to workers automatically via the shared work queue.

    Raises:
        ValueError: If *workers* is less than 1.
    """

    DEFAULT_WORKERS = 1  # inline execution — fastest for typical callbacks

    # Fallback poll interval (seconds) for connections without an eventfd.
    _POLL_INTERVAL = 0.001  # 1 ms

    def __init__(
        self,
        workers: int = DEFAULT_WORKERS,
        use_processes: bool = False,
    ) -> None:
        if workers < 1:
            raise ValueError(
                f"workers must be >= 1 (got {workers!r}). "
                "Use workers=1 for inline (single-threaded) execution."
            )
        self.workers = workers
        self.use_processes = use_processes and workers > 1
        self.connections: set = set()
        self.pollers = (
            dfcore.getMessageForClientWorker,
            dfcore.getMessageForServerWorker,
        )

        # Both modes share the same attribute names; the concrete types differ.
        # mp.Event / mp.Queue work across forked processes; threading counterparts
        # do not — but their APIs are identical so the rest of the code is uniform.
        if self.use_processes:
            # Plain mp.Queue / mp.Event — no "fork" context needed because we
            # spawn workers via os.fork() directly, not via mp.Process.
            self.stop_event = mp.Event()
            self.queue = mp.Queue()
            self._result_queue = mp.Queue()
        else:
            self.stop_event = Event()
            self.queue = Queue()

        # Thread or Process objects for the worker pool (workers >= 2).
        self._workers: list = []
        # Poller thread — always a Thread; None until first start_for_connection.
        self._poller: "Thread | None" = None
        # Result-collector thread — only used in process mode.
        self._collector: "Thread | None" = None

        # conn_num → _WakeupFd
        self._wakeup: dict[int, _WakeupFd] = {}
        # read_fd → connection object
        self._fd_to_conn: dict[int, Any] = {}
        # read_fd → (conn_num, callback, _WakeupFd) for disconnect notifications
        self._disc_by_rfd: dict[int, tuple] = {}

    def _start_workers(self) -> None:
        """Start the worker pool before any native I/O threads are created.

        Safe to call in both thread and process modes:

        * **threads** — they immediately block on ``queue.get()`` and idle
          until the poller delivers work; starting them early costs nothing.
        * **processes** — forking before ``dfcore.startServer()`` /
          ``dfcore.startClient()`` starts Zig-native threads keeps the child
          in a clean single-threaded state, avoiding POSIX fork-safety hazards
          (inherited locks that the child can never release).

        No-op when ``workers == 1`` (inline mode) or the pool is already
        running.
        """
        if self._workers:
            return
        if self.use_processes:
            # Use raw os.fork() rather than mp.Process to completely bypass
            # Python's multiprocessing resource-tracker and semaphore-
            # registration machinery.  That machinery can deadlock or corrupt
            # its accounting in nested-fork scenarios (e.g. a benchmark that
            # forks a service subprocess which then tries to fork worker
            # processes via mp.Process).
            #
            # os.fork() is the raw POSIX syscall — it never touches the
            # resource tracker, never pickles arguments, and always works in
            # any number of nesting levels.  mp.Queue / mp.Event were designed
            # specifically to work across os.fork(), so IPC is unaffected.
            #
            # Upgrade EXECUTOR_REGISTRY to a SharedDict backed by
            # multiprocessing.shared_memory BEFORE forking.  All forked
            # workers inherit the same shared memory handle; any register()
            # or unregister() made in the parent after the fork is
            # immediately visible to every worker on its next get() call —
            # no broadcasting or IPC beyond the lock-protected shared read.
            EXECUTOR_REGISTRY.update_to_use_processes()
            for _ in range(self.workers - 1):
                pid = os.fork()
                if pid == 0:
                    # ── child ──────────────────────────────────────────────
                    # Flush the result queue before hard-exiting so that
                    # mp.Queue's internal feeder thread (started lazily on
                    # first put()) has a chance to drain its buffer into the
                    # pipe before os._exit tears down the process.
                    # os._exit is required (not sys.exit) to avoid running
                    # Python atexit handlers and __del__ finalizers that could
                    # double-close file descriptors inherited from the parent.
                    try:
                        self._worker_loop()
                    except BaseException:
                        pass
                    finally:
                        try:
                            self._result_queue.close()
                            self._result_queue.join_thread()
                        except Exception:
                            pass
                        # Close (not unlink) the shared memory handle so
                        # Python's resource tracker doesn't warn about leaks.
                        if isinstance(EXECUTOR_REGISTRY.registry, SharedDict):
                            EXECUTOR_REGISTRY.registry.child_close()
                    os._exit(0)
                # ── parent ─────────────────────────────────────────────────
                self._workers.append(_ForkedWorker(pid))
            if self._collector is None:
                self._collector = Thread(
                    target=self._result_collector_loop,
                    name="daffi-result-collector",
                    daemon=True,
                )
                self._collector.start()
        else:
            for i in range(self.workers - 1):
                t = Thread(
                    target=self._worker_loop,
                    name=f"daffi-worker-{i}",
                )
                t.start()
                self._workers.append(t)

    def stop_for_connection(self, connection) -> None:
        """Deregister *connection* and, if no connections remain, stop all workers."""
        self.connections.discard(connection)
        conn_num = getattr(connection, "_conn_num", None)
        self._deregister_fds(conn_num)
        if not self.connections:
            self.stop_event.set()
            # Send one sentinel per worker so each exits its loop cleanly.
            for _ in self._workers:
                try:
                    self.queue.put_nowait(None)
                except Exception:
                    pass
            for w in self._workers:
                w.join(timeout=3)
                # Processes may need a hard kill if they don't exit in time.
                if hasattr(w, "terminate") and w.is_alive():
                    w.terminate()
            if self._collector is not None:
                # All workers have exited — no more results can arrive.
                # A single sentinel unblocks the collector after it drains
                # any results that were already queued.
                self._result_queue.put(None)
                self._collector.join()
            if self._poller is not None:
                self._poller.join()

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
        disc = _WakeupFd()
        self._disc_by_rfd[disc.read_fd] = (conn_num, callback, disc)
        set_client_disconnect_fd(conn_num, disc.write_fd)

    def start_for_connection(self, connection) -> None:
        """Register *connection* and start background workers if not already running."""
        assert connection._conn_num is not None
        self.connections.add(connection)

        conn_num: int = connection._conn_num
        wakeup = _WakeupFd()
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
        * ``workers  > 1``: tasks go into ``self.queue`` (thread or process
          queue depending on mode).  EVENTS messages are always run inline
          because their handlers hold a reference to the ``conn`` object.

        Disconnect fds are also monitored here.  When one fires the registered
        callback is invoked directly in this thread.
        """
        inline = self.workers == 1

        while not self.stop_event.is_set():
            wakeup_fds = list(self._fd_to_conn.keys())
            disc_fds = list(self._disc_by_rfd.keys())
            all_fds = wakeup_fds + disc_fds
            if all_fds:
                try:
                    readable, _, _ = select.select(all_fds, [], [], self._POLL_INTERVAL)
                except (ValueError, OSError):
                    readable = []
            else:
                time.sleep(self._POLL_INTERVAL)
                readable = []

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
                        # Event notifications carry conn-bound handlers and must
                        # always run here — they cannot be offloaded to workers.
                        payload = json.loads(data)
                        for handler in conn.event_handlers:
                            handler(payload)
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
                        # Both thread-pool and process-pool receive the same
                        # plain-data tuple.
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

    def _worker_loop(self) -> None:
        """Unified worker body for both thread-pool and process-pool modes.

        Blocks on ``self.queue.get()`` until a task arrives or a ``None``
        sentinel is received.  The sentinel is placed by :meth:`stop_for_connection`
        (one per worker), so no polling or ``stop_event`` check is needed here —
        the worker exits immediately when told to, without waiting for a timeout.

        On task completion the result is either sent directly to the caller
        (thread mode, native handle is local) or pushed onto ``_result_queue``
        for the main-process collector thread to forward (process mode).

        In process mode the registry is a :class:`SharedDict` backed by
        shared memory, so callbacks registered or removed in the parent after
        the fork are automatically visible on every ``get()`` call here.
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
            if self.use_processes:
                # Running inside a forked process — push result back to main
                # process; the collector thread there calls the native sender.
                self._result_queue.put(
                    (
                        uuid,
                        result_bytes,
                        flag,
                        serde,
                        is_bytes,
                        transmitter,
                        func_name,
                        conn_num,
                        server_mode_bool,
                    )
                )
            else:
                # Running inside a thread — the native handle is accessible here.
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

    def _result_collector_loop(self) -> None:
        """Collect results from worker processes and send via the native layer.

        Runs as a daemon thread in the **main process** (process mode only).
        Blocks on ``_result_queue.get()`` until results arrive.  A ``None``
        sentinel placed by :meth:`stop_for_connection` — after all worker
        processes have been joined — signals the end of the stream.  By that
        point every result that was queued by the workers is already in the
        queue, so the collector drains all pending items before exiting.
        """
        for item in iter(self._result_queue.get, None):
            (
                uuid,
                result_bytes,
                flag,
                serde,
                is_bytes,
                transmitter,
                func_name,
                conn_num,
                server_mode_bool,
            ) = item
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
