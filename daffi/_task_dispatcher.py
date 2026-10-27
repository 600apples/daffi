"""
Background threads that dispatch incoming RPC tasks to registered
``@callback`` executors.

Notification strategy
---------------------
For Service connections the native layer writes to a per-connection
``os.eventfd`` (Linux) or pipe (macOS / other) whenever a new message is pushed
onto the task queue.  The poller thread blocks in one long-lived
``selectors.DefaultSelector`` over all registered fds — zero CPU when idle,
sub-millisecond wake latency.

For Client connections (bidirectional nodes with registered callbacks) the same
architecture is used if the native side exposes a wakeup fd; otherwise a short
fixed-interval poll (1 ms) is the fallback.

Execution modes
---------------
workers=1 (default)
    Callbacks are executed **inline** inside the poller thread — no queue, no
    extra thread context-switch.  "1 worker" means the poller thread is the
    sole executor; no additional thread is spawned.  This is the fastest mode
    and the right choice for fast / I/O-bound callbacks.  A client connected
    to a Service never executes callbacks, so it always stays in this mode:
    the poller only waits for disconnect, eviction, and handshake notices.

workers=N (thread pool)
    N threads and a private queue are added for **that connection only**.
    A callback on one client is never handed to another client's threads.
    Good for I/O-bound callbacks; the GIL limits CPU parallelism.
"""

import json
import os
import selectors
import sys
import threading
from queue import Queue
from threading import Thread, Event
from typing import Any, NamedTuple

from . import dfcore
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi._serialization import Serializer, SerdeFormat
from daffi._wakeup import LifecycleSignal, WakeupFd, note_descriptors
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

# One poller for the whole process. A poller thread per client makes a few
# thousand clients exhaust the OS thread cap before they have done any work.
# Worker threads are not shared: each connection that asks for N workers gets
# N threads that execute only that connection's callbacks.
_shared_dispatcher: "TaskDispatcher | None" = None
_shared_dispatcher_lock = threading.Lock()


def shared_dispatcher() -> "TaskDispatcher":
    """Return the process-wide poller. Worker threads stay per connection."""
    global _shared_dispatcher
    with _shared_dispatcher_lock:
        if _shared_dispatcher is None:
            _shared_dispatcher = TaskDispatcher()
        return _shared_dispatcher


def _drop_shared_dispatcher_after_fork() -> None:
    """The child keeps the object and loses the poller thread.

    macOS does not give the child the parent's kqueue, so the inherited
    selector cannot be waited on. Drop it. The next connection in the child
    opens its own. The parent is unchanged.
    """
    global _shared_dispatcher, _shared_dispatcher_lock
    old = _shared_dispatcher
    _shared_dispatcher = None
    _shared_dispatcher_lock = threading.Lock()
    if old is None:
        return
    try:
        old._close_selector()
    except Exception:
        pass
    channels = [old._control]
    for entry in old._conns.values():
        channels.append(entry.wakeup)
        channels.append(entry.lifecycle)
    for channel in channels:
        try:
            channel.close()
        except Exception:
            pass


if hasattr(os, "register_at_fork"):
    os.register_at_fork(after_in_child=_drop_shared_dispatcher_after_fork)


class _Pool:
    """Worker threads that execute callbacks for one connection."""

    def __init__(self) -> None:
        self.queue: Queue = Queue()
        self.threads: list[Thread] = []
        self.closed = False
        self.lock = threading.Lock()


def _pool_size(connection) -> int:
    """How many private worker threads *connection* gets.

    A client whose peer is a Service has nothing to execute, so it stays at
    1: the shared poller only delivers notifications. ``1`` means inline on
    that poller. ``N >= 2`` is a private pool for this connection alone.
    """
    if (
        getattr(connection, "server_mode", None) is None
        and getattr(connection, "_conn_type", None) == "service"
    ):
        return 1
    try:
        n = int(getattr(connection, "workers", 1))
    except (TypeError, ValueError):
        return 1
    return n if n >= 1 else 1


def _handle_lifecycle_signal(conn, conn_num: int, reason: bytes) -> None:
    """React to a lifecycle byte written by the native layer into a Client's
    lifecycle fd.  Executed inline on the poller thread.

    ``LifecycleSignal.INIT`` re-runs the handshake and returns normally.

    All disconnect variants (DISCONNECTED, EVICTED, NORMAL) wake in-flight
    RPC waiters, store the error on *conn*, then either:

    * **joining path** — call ``conn.stop()`` so ``join()`` unblocks.
      ``stop_for_connection`` detects it is being called from the poller
      thread and skips joining itself, avoiding a deadlock.
    * **non-joining path** — log the error and return.  ``conn.stop()`` is
      intentionally *not* called here: the user's thread may still be inside
      a Zig RPC call, and calling ``dfcore.stopClient`` concurrently from the
      poller would deadlock on the per-connection Zig lock.  The in-flight
      waiter is already woken by ``signal_lifecycle_error``; the user's
      ``finally`` block is responsible for calling ``client.stop()``.
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

    if conn._joining:
        conn.stop()
    else:
        conn.logger.error(f"Error in connection {conn_num}: {err}")


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
    import asyncio as _asyncio

    cb = EXECUTOR_REGISTRY.get(func_name)
    args, kwargs = Serializer.deserialize(serde, data)
    try:
        if _asyncio.iscoroutinefunction(cb):
            raise TypeError(
                f"Callback {func_name!r} is an async def coroutine and cannot be "
                "used with the synchronous dispatcher. "
                "Use daffi.aio (AsyncClient / AsyncService) instead."
            )
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

    The poller is shared. Callback threads are not: ``connection.workers``
    decides them when the connection is registered.

    * ``1`` (default) — callbacks run **inline** in the poller thread.
    * ``N >= 2`` — N threads and a private queue for that connection only.
    """

    DEFAULT_WORKERS = 1  # inline execution — fastest for typical callbacks

    def __init__(self) -> None:
        self.connections: set = set()
        self.pollers = (
            dfcore.getMessageForClientWorker,
            dfcore.getMessageForServerWorker,
        )

        self.stop_event = Event()
        # conn_num → private callback pool (only when that connection asked
        # for 2 or more workers).
        self._pools: dict[int, _Pool] = {}
        # Poller thread — always a Thread; None until first start_for_connection.
        self._poller: "Thread | None" = None
        self._poller_lock = threading.Lock()
        # Stays open for the life of the dispatcher. Writing it wakes the
        # poller so it can register a new connection, or drop an fd from
        # kqueue before that fd is closed. Closing an fd a kqueue is still
        # waiting on is undefined on macOS.
        self._control = WakeupFd(pipe=True)
        self._retire_lock = threading.Lock()
        self._retired: list[tuple[int, threading.Event]] = []

        # conn_num → _ConnEntry  (all fd-related state for a connection)
        self._conns: dict[int, _ConnEntry] = {}
        # read_fd → conn_num  (covers both wakeup and lifecycle fds; used to
        # route readable events back to the right _ConnEntry without scanning)
        self._rfd_to_conn_num: dict[int, int] = {}
        # One selector for the life of the poller. Rebuilt only when an fd
        # disappears out from under a wait (see handle_task_queue).
        self._selector: selectors.BaseSelector | None = None
        self._selector_fds: set[int] = set()

    def _start_connection_workers(self, connection) -> None:
        """Start *connection*'s private callback threads, if it asked for any.

        Idempotent. ``workers == 1`` leaves the connection inline on the poller.
        A later call does not add a second pool.
        """
        conn_num = connection._conn_num
        if conn_num in self._pools:
            return
        n = _pool_size(connection)
        if n == 1:
            return
        pool = _Pool()
        for i in range(n):
            thread = Thread(
                target=self._worker_loop,
                args=(pool.queue,),
                name=f"daffi-worker-{conn_num}-{i}",
            )
            thread.start()
            pool.threads.append(thread)
        self._pools[conn_num] = pool

    def _stop_connection_workers(self, conn_num) -> None:
        """Stop the private pool for *conn_num*, if it has one."""
        pool = self._pools.get(conn_num)
        if pool is None:
            return
        with pool.lock:
            pool.closed = True
            self._pools.pop(conn_num, None)
            for _ in pool.threads:
                try:
                    pool.queue.put_nowait(None)
                except Exception:
                    pass
        for thread in pool.threads:
            thread.join(timeout=3)

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
        # This connection's callback threads stop with it. Other connections
        # keep theirs. The poller stays up while anyone is left.
        if conn_num is not None:
            self._stop_connection_workers(conn_num)
        if not self.connections:
            # 1. flip stop_event so the loop exits after the next wakeup.
            # 2. write b"s" to the lifecycle fd to unblock select (skip when
            #    called from the poller thread itself to avoid a deadlock —
            #    the poller will exit naturally because stop_event is set).
            # 3. join workers and poller (skip poller join when inside it).
            # 4. close fds (safe — poller has fully exited or will exit).
            # The snapshot is taken under the same lock that starts a new
            # poller, so a later client restarts a fresh thread instead of
            # this join waiting on that new thread.
            with self._poller_lock:
                self.stop_event.set()
                poller = self._poller
                in_poller = threading.current_thread() is poller
            if not in_poller:
                entry = self._conns.get(conn_num)
                if entry is not None:
                    entry.lifecycle.write(LifecycleSignal.STOP)
            if poller is not None and not in_poller:
                poller.join()
        # Wakeup first, then lifecycle. While the poller is still running it
        # unregisters the fd and only then is the fd closed.
        self._deregister_fds(conn_num)
        self._close_lifecycle(conn_num)

    def _retire(self, fd: int, close) -> None:
        """Unregister *fd* from the poller, then call *close*.

        The poller thread closes immediately. Any other thread waits until
        the poller has dropped the fd from its selector, so kqueue is not
        still waiting on it.
        """
        poller = self._poller
        if (
            poller is None
            or not poller.is_alive()
            or threading.current_thread() is poller
        ):
            if self._selector is not None and threading.current_thread() is poller:
                try:
                    self._selector.unregister(fd)
                except (KeyError, ValueError, OSError):
                    pass
                self._selector_fds.discard(fd)
            close()
            return
        done = threading.Event()
        with self._retire_lock:
            self._retired.append((fd, done))
        self._control.signal()
        done.wait(timeout=5)
        close()

    def _release_retired(self) -> None:
        """Unregister fds a stopper is waiting on, then let it close them."""
        with self._retire_lock:
            pending = self._retired
            self._retired = []
        selector = self._selector
        for fd, done in pending:
            if selector is not None:
                try:
                    selector.unregister(fd)
                except (KeyError, ValueError, OSError):
                    pass
            self._selector_fds.discard(fd)
            done.set()

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
            fd = entry.wakeup.read_fd
            self._rfd_to_conn_num.pop(fd, None)
            self._retire(fd, entry.wakeup.close)

    def _close_lifecycle(self, conn_num) -> None:
        """Close the lifecycle fd and remove the entire entry for *conn_num*.

        The poller unregisters the fd before it is closed. After the poller
        has exited the close happens immediately.
        """
        entry = self._conns.pop(conn_num, None)
        if entry is not None:
            fd = entry.lifecycle.read_fd
            self._rfd_to_conn_num.pop(fd, None)
            self._retire(fd, entry.lifecycle.close)

    def start_for_connection(self, connection) -> None:
        """Register *connection* and start its private callback threads.

        Threads are started before the connection is visible to the poller, so
        the first task cannot land on the shared waiter by mistake.
        """
        assert connection._conn_num is not None
        self._start_connection_workers(connection)
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
        # The poller may already be blocked in select. This wakes it so the
        # new fds are registered before the next wait.
        self._control.signal()

        with self._poller_lock:
            # The previous generation is joined before stop_for_connection
            # returns, so a dead poller here has already closed its selector.
            if self._poller is None or not self._poller.is_alive():
                self.stop_event.clear()
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
        * ``workers  > 1``: tasks go into that connection's private queue.
          EVENTS messages are always run inline because their handlers hold
          a reference to the ``conn`` object.

        Disconnect fds are also monitored here.  When one fires the registered
        callback is invoked directly in this thread.

        I/O multiplexing strategy
        -------------------------
        The poller uses one ``selectors.DefaultSelector`` (kqueue on macOS,
        epoll on Linux) with ``timeout=None`` (infinite wait).  This has two
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

        The selector stays open for the life of the poller.  Descriptors are
        registered when a connection is added and dropped when it leaves, so a
        call does not pay for a new kqueue plus ``kevent``/``epoll_ctl`` on
        every wakeup.  If a wait fails because an fd was closed underneath it,
        the selector is discarded and the next iteration registers whatever
        is still in the map.

        Shutdown is signalled by writing ``LifecycleSignal.STOP`` to the
        connection's lifecycle fd, which causes the selector to return; the
        loop then checks ``stop_event.is_set()``.
        """
        try:
            self._poll_loop()
        finally:
            self._close_selector()
            # Unblock anyone waiting to close an fd. The selector is already
            # shut, so the close is no longer racing a wait.
            self._release_retired()

    def _poll_loop(self) -> None:
        while not self.stop_event.is_set():
            if not self._sync_selector():
                # No fds yet (or all of them failed to register). Don't spin.
                self.stop_event.wait(0.001)
                continue
            assert self._selector is not None
            try:
                events = self._selector.select(timeout=None)
                readable = {key.fd for key, _ in events}
            except (OSError, ValueError):
                # OSError: an fd was closed under the wait. ValueError: the
                # kqueue object itself was closed (a forked child, or stop).
                self._close_selector()
                continue

            if self._control.read_fd in readable:
                self._control.drain()
                self._release_retired()
                readable.discard(self._control.read_fd)

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
                        continue
                    pool = self._pools.get(conn._conn_num)
                    if pool is None:
                        # No private pool means this connection runs inline.
                        # A pool that was just removed belongs to a connection
                        # that is stopping; leave that callback alone.
                        if _pool_size(conn) == 1 and conn in self.connections:
                            _execute_task(
                                uuid,
                                data,
                                serde,
                                transmitter,
                                func_name,
                                return_result,
                                conn,
                            )
                        continue
                    task_item = (
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
                    with pool.lock:
                        if not pool.closed:
                            pool.queue.put(task_item)

    def _sync_selector(self) -> bool:
        """Make the long-lived selector match ``_rfd_to_conn_num``.

        Returns whether at least one fd is registered.
        """
        current = set(self._rfd_to_conn_num)
        current.add(self._control.read_fd)
        if self._selector is None:
            note_descriptors(1)
            try:
                self._selector = selectors.DefaultSelector()
            except BaseException:
                note_descriptors(-1)
                raise
        for fd in self._selector_fds - current:
            try:
                self._selector.unregister(fd)
            except (KeyError, ValueError, OSError):
                pass
        watched = set(current)
        for fd in current - self._selector_fds:
            try:
                self._selector.register(fd, selectors.EVENT_READ)
            except (ValueError, OSError):
                watched.discard(fd)
        self._selector_fds = watched
        return bool(watched)

    def _close_selector(self) -> None:
        selector = self._selector
        self._selector = None
        self._selector_fds = set()
        if selector is not None:
            selector.close()
            note_descriptors(-1)

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

    def _worker_loop(self, queue: Queue) -> None:
        """Thread-pool worker body for one connection.

        Blocks on *queue* until a task arrives or a ``None`` sentinel is
        received.  The sentinel is placed by :meth:`_stop_connection_workers`
        (one per worker), so no polling or ``stop_event`` check is needed —
        the worker exits when told to, without waiting for a timeout.
        """
        for task in iter(queue.get, None):
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
