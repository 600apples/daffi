"""
Background threads that dispatch incoming RPC tasks to registered ``@callback``
executors.

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

workers=N (N >= 2)
    A pool of N-1 dedicated worker threads picks tasks off a shared
    ``queue.Queue`` and executes them in parallel.  Use this when callbacks
    are CPU-bound or block for a significant time and you need concurrent
    execution across multiple simultaneous inbound requests.
"""

import json
import os
import select
import fcntl
import sys
import time
from queue import Queue, Empty
from threading import Thread, Event
from typing import Any

from . import dfcore
from daffi.registry.executor_registry import EXECUTOR_REGISTRY
from daffi.serialization import Serializer, SerdeFormat
from daffi.bindings import (
    send_message_from_client,
    send_message_from_service,
    set_wakeup_fd,
    set_client_wakeup_fd,
    MessageFlag,
)

try:
    import tblib.pickling_support

    tblib.pickling_support.install()
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
            self.write_fd: int = fd   # same fd for eventfd
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


def _execute_task(
    uuid: int,
    data: bytes,
    flag: int,
    serde: SerdeFormat,
    transmitter: str,
    func_name: str,
    return_result: bool,
    conn: Any,
) -> None:
    """Execute one inbound RPC task and send the response.

    Shared by the inline (workers=0) and threaded (workers>0) paths so the
    execution logic lives in exactly one place.
    """
    if flag == MessageFlag.EVENTS:
        payload = json.loads(data)
        for handler in conn.event_handlers:
            handler(payload)
        return

    cb = EXECUTOR_REGISTRY.get(func_name)
    args, kwargs = Serializer.deserialize(serde, data)
    try:
        result = cb(*args, **kwargs)
        flag = MessageFlag.RESPONSE
    except:
        flag = MessageFlag.ERROR
        if serde == SerdeFormat.RAW:
            serde = SerdeFormat.PICKLE
        err_type, err_obj, tb = sys.exc_info()
        if serde == SerdeFormat.PICKLE:
            result = (err_type.__name__, err_type.__module__, str(err_obj), tb)
        else:
            result = (err_type.__name__, err_type.__module__, str(err_obj), None)

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
    """Manages the lifecycle of threads that process incoming messages for one
    or more server/client connections.

    Args:
        workers: Concurrency level for callback execution.

                 * ``1`` (default) — callbacks run **inline** in the poller
                   thread.  Zero overhead from thread hand-off; ideal for
                   fast / I/O-bound callbacks.  "1 worker" = the poller thread
                   itself; no extra thread is spawned.
                 * ``N >= 2`` — a pool of N worker threads executes callbacks
                   concurrently from a shared queue.  Use when callbacks are
                   CPU-bound or block for a significant time and you need
                   parallel execution across simultaneous inbound requests.

    Raises:
        ValueError: If *workers* is less than 1.
    """

    DEFAULT_WORKERS = 1  # inline execution — fastest for typical callbacks

    # Fallback poll interval (seconds) for connections without an eventfd.
    _POLL_INTERVAL = 0.001  # 1 ms

    def __init__(self, workers: int = DEFAULT_WORKERS) -> None:
        if workers < 1:
            raise ValueError(
                f"workers must be >= 1 (got {workers!r}). "
                "Use workers=1 for inline (single-threaded) execution."
            )
        self.workers = workers
        self.connections: set = set()
        self.stop_event = Event()
        self.pollers = (
            dfcore.getMessageForClientWorker,
            dfcore.getMessageForServerWorker,
        )
        self.threads: list[Thread] = []
        self.queue: Queue = Queue()
        # conn_num → _WakeupFd
        self._wakeup: dict[int, _WakeupFd] = {}
        # read_fd → connection object
        self._fd_to_conn: dict[int, Any] = {}

    def stop_for_connection(self, connection) -> None:
        """Deregister *connection* and, if no connections remain, stop all threads."""
        self.connections.discard(connection)
        conn_num = getattr(connection, "_conn_num", None)
        if conn_num is not None and conn_num in self._wakeup:
            wakeup = self._wakeup.pop(conn_num)
            self._fd_to_conn.pop(wakeup.read_fd, None)
            wakeup.close()
        if not self.connections:
            self.stop_event.set()
            for thread in self.threads:
                thread.join()

    def start_for_connection(self, connection) -> None:
        """Register *connection* and start background threads if not already running."""
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

        if not self.threads:
            # workers=1 → inline; workers>=2 → dedicated thread pool.
            for i in range(self.workers - 1):
                t = Thread(
                    target=self._worker_loop,
                    name=f"daffi-worker-{i}",
                )
                t.start()
                self.threads.append(t)

            poller_thread = Thread(
                target=self.handle_task_queue,
                name="daffi-poller",
                daemon=True,
            )
            poller_thread.start()
            self.threads.append(poller_thread)

    # ------------------------------------------------------------------

    def handle_task_queue(self) -> None:
        """Wait for native notifications, then execute or enqueue each task.

        * ``workers == 0``: callbacks run here, inline — no queue, no thread hop.
        * ``workers  > 0``: tasks are put into the shared queue for worker threads.
        """
        inline = self.workers == 1

        while not self.stop_event.is_set():
            read_fds = list(self._fd_to_conn.keys())
            if read_fds:
                try:
                    readable, _, _ = select.select(read_fds, [], [], self._POLL_INTERVAL)
                except (ValueError, OSError):
                    readable = []
            else:
                time.sleep(self._POLL_INTERVAL)
                readable = []

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
                        uuid, data, flag, serde,
                        transmitter, receiver, func_name, return_result,
                    ) = task

                    if inline:
                        # Fast path: execute right here, zero thread overhead.
                        _execute_task(
                            uuid, data, flag, serde,
                            transmitter, func_name, return_result, conn,
                        )
                    else:
                        self.queue.put((
                            uuid, data, flag, serde,
                            transmitter, func_name, return_result, conn,
                        ))

    def _worker_loop(self) -> None:
        """Worker thread body: dequeue and execute tasks (workers > 0 mode)."""
        while not self.stop_event.is_set():
            try:
                uuid, data, flag, serde, transmitter, func_name, return_result, conn = (
                    self.queue.get(timeout=1)
                )
            except Empty:
                continue
            _execute_task(uuid, data, flag, serde, transmitter, func_name, return_result, conn)
