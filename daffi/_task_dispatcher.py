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
    A callback that makes a blocking call of its own first hands polling to
    a new thread, so nodes in one process can call each other from
    callbacks.

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
from daffi.exceptions import Evicted, SerdeNotAllowed
from daffi._rpc_proxy import RpcProxy, connection_lost_error

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
    """Worker threads that execute callbacks for one connection.

    At most ``capacity`` tasks wait in ``queue``.  When it is full the poller
    leaves the rest in the native queue, whose bound answers further
    requests with ``ServiceOverloaded``, and sets ``stalled``.  The next
    worker to take a task signals ``wakeup`` so the poller drains again: the
    native layer does not signal a queue that was not seen empty.
    """

    def __init__(self, capacity: int) -> None:
        self.queue: Queue = Queue()
        self.capacity = capacity
        self.threads: list[Thread] = []
        self.closed = False
        self.stalled = False
        self.wakeup: WakeupFd | None = None
        self.lock = threading.Lock()

    def full(self) -> bool:
        """Poller: whether to stop taking tasks; if so the pool is stalled."""
        with self.lock:
            if self.queue.qsize() < self.capacity:
                return False
            self.stalled = True
            return True

    def took_task(self) -> None:
        """Worker: wake a poller that stopped because the queue was full."""
        with self.lock:
            if not self.stalled or self.closed or self.wakeup is None:
                return
            self.stalled = False
            # Under the lock: the connection's fds are only closed after
            # ``closed`` is set, so this never writes to a closed fd.
            self.wakeup.signal()


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


def _accepted(connection) -> frozenset:
    """The request formats *connection* accepts (``serdes=``)."""
    return getattr(connection, "serdes", SerdeFormat.ALL)


def _handle_lifecycle_signal(conn, conn_num: int, reason: bytes) -> None:
    """React to a lifecycle byte written by the native layer into a Client's
    lifecycle fd.  Executed inline on the poller thread.

    ``LifecycleSignal.INIT`` re-runs the handshake and returns normally.

    A disconnect or eviction stores the error on *conn*; in-flight calls
    already learnt it from the native wait.  When a thread is parked in
    ``join()`` the connection is stopped so ``join()`` returns.  ``stop()``
    runs on its own thread, so the poller keeps serving other connections.
    """
    if reason == LifecycleSignal.INIT:
        RpcProxy._process_client_handshake(conn_num, conn._exposed_names())
        conn._register_executors()
        return

    if reason == LifecycleSignal.NORMAL:
        _stop_in_background(conn)
        return

    evicted = reason == LifecycleSignal.EVICTED
    if not evicted and isinstance(conn._connection_error, Evicted):
        # The server closes an evicted connection; that close is not news.
        return
    err = connection_lost_error(evicted, conn.app_name)
    conn._connection_error = err
    conn._disconnected = True

    if conn._joining:
        _stop_in_background(conn)
    else:
        conn.logger.error(f"Error in connection {conn_num}: {err}")


def _stop_in_background(conn) -> None:
    Thread(target=conn.stop, name="daffi-stop", daemon=True).start()


def _error_result(serde: "SerdeFormat") -> "tuple[tuple, int, SerdeFormat]":
    """Describe the exception being handled as an ERROR reply.

    OPAQUE has no structure to carry it, so OPAQUE errors go out as JSON.
    """
    if serde == SerdeFormat.OPAQUE:
        serde = SerdeFormat.JSON
    err_type, err_obj, tb = sys.exc_info()
    # Without tblib a traceback cannot be pickled.
    include_tb = _tblib_installed and serde == SerdeFormat.PICKLE
    result = (
        err_type.__name__,
        err_type.__module__,
        str(err_obj),
        tb if include_tb else None,
    )
    return result, MessageFlag.ERROR, serde


def _exposed(connection) -> "frozenset | None":
    """The callbacks *connection* offers (``callbacks=``); None for all."""
    return getattr(connection, "callbacks", None)


def _lookup(func_name: str, exposed: "frozenset | None"):
    """The executor for *func_name*, if this node offers it."""
    cb = EXECUTOR_REGISTRY.get(func_name) if exposed is None or func_name in exposed else None
    if cb is None:
        raise LookupError(f"Callback {func_name!r} is not registered.")
    return cb


def _check_serde(serde: int, accepted: frozenset) -> None:
    """Refuse a request before its payload is decoded: unpickling is enough
    to run the sender's code."""
    if serde not in accepted:
        raise SerdeNotAllowed(
            f"This node does not accept {SerdeFormat.name_of(serde)} requests."
        )


def _reply_serde(serde: int, accepted: frozenset) -> int:
    """Format for the reply to a request in *serde*: a refused format is
    answered in JSON."""
    return serde if serde in accepted else SerdeFormat.JSON


def _invoke_callback(
    func_name: str,
    serde: "SerdeFormat",
    data: bytes,
    accepted: frozenset = SerdeFormat.ALL,
    exposed: "frozenset | None" = None,
) -> "tuple[Any, int, SerdeFormat]":
    """Deserialise *data*, call the registered callback, and return the outcome.

    Returns:
        ``(result, flag, serde)`` where *flag* is ``MessageFlag.RESPONSE`` on
        success or ``MessageFlag.ERROR`` on failure (see :func:`_error_result`).
    """
    try:
        _check_serde(serde, accepted)
        cb = _lookup(func_name, exposed)
        if cb.is_coroutine:
            raise TypeError(
                f"Callback {func_name!r} is an async def coroutine and cannot be "
                "used with the synchronous dispatcher. "
                "Use daffi.aio (AsyncClient / AsyncService) instead."
            )
        args, kwargs = Serializer.deserialize(serde, data)
        return cb(*args, **kwargs), MessageFlag.RESPONSE, serde
    except:  # noqa: E722
        return _error_result(_reply_serde(serde, accepted))


def _encode_reply(result: Any, flag: int, serde: "SerdeFormat") -> tuple:
    """``(data, is_bytes, flag, serde)`` for a reply.  A result that cannot
    be serialised becomes a JSON error describing why."""
    try:
        data, is_bytes = Serializer.serialize(serde, result)
        return data, is_bytes, flag, serde
    except Exception:
        error, flag, serde = _error_result(SerdeFormat.JSON)
        data, is_bytes = Serializer.serialize(serde, error)
        return data, is_bytes, flag, serde


def _send_reply(
    server_mode: bool,
    conn_num: int,
    uuid: int,
    transmitter: str,
    func_name: str,
    outcome: tuple,
    logger,
) -> None:
    data, is_bytes, flag, serde = _encode_reply(*outcome)
    try:
        _SENDERS[server_mode](
            data=data,
            flag=flag,
            serde=serde,
            receiver=transmitter,
            func_name=func_name,
            return_result=False,
            conn_num=conn_num,
            is_bytes=is_bytes,
            uuid=uuid,
        )
    except Exception as exc:
        logger.warning(f"Could not send the result of {func_name!r} to {transmitter!r}: {exc}")


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
        # fds (with their close) the poller must drop and close.  Only
        # accepted while ``_poller_running``; afterwards the closer closes.
        self._retired: list[tuple[int, Any]] = []
        self._poller_running = False

        # conn_num → _ConnEntry  (all fd-related state for a connection)
        self._conns: dict[int, _ConnEntry] = {}
        # read_fd → conn_num  (covers both wakeup and lifecycle fds; used to
        # route readable events back to the right _ConnEntry without scanning)
        self._rfd_to_conn_num: dict[int, int] = {}
        # One selector for the life of the poller. Rebuilt only when an fd
        # disappears out from under a wait (see handle_task_queue).
        self._selector: selectors.BaseSelector | None = None
        self._selector_fds: set[int] = set()
        # Connections whose wakeup the poller has drained and whose queue it
        # has not yet emptied.  Only the current poller thread touches it.
        self._owed: set = set()

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
        pool = _Pool(capacity=n)
        for i in range(n):
            # Daemon: neither stop() nor interpreter exit waits for a
            # callback that is still running.
            thread = Thread(
                target=self._worker_loop,
                args=(pool,),
                name=f"daffi-worker-{conn_num}-{i}",
                daemon=True,
            )
            thread.start()
            pool.threads.append(thread)
        self._pools[conn_num] = pool

    def _stop_connection_workers(self, conn_num) -> None:
        """Close the private pool for *conn_num*, if it has one.

        Nothing waits for the workers: queued tasks are dropped, and a
        callback that is still running is abandoned with its reply.
        """
        pool = self._pools.get(conn_num)
        if pool is None:
            return
        with pool.lock:
            pool.closed = True
            self._pools.pop(conn_num, None)
            for _ in pool.threads:
                pool.queue.put_nowait(None)

    def stop_for_connection(self, connection) -> None:
        """Deregister *connection*; the last one also stops the poller.

        Returns at once.  A callback still running is abandoned, and its
        reply is dropped.  Closing an fd a kqueue is still waiting on is
        undefined on macOS, so while the poller runs it closes the fds
        itself (see :meth:`_retire`).
        """
        conn_num = getattr(connection, "_conn_num", None)
        # This connection's callback threads stop with it. Other connections
        # keep theirs. The poller stays up while anyone is left.
        if conn_num is not None:
            self._stop_connection_workers(conn_num)
        # Deciding to stop and adding a connection share one lock, so a
        # connection added meanwhile either keeps this poller or starts a
        # new one; it is never left with a poller that is exiting.
        with self._poller_lock:
            self.connections.discard(connection)
            if not self.connections:
                self.stop_event.set()
        # Wakeup first, then lifecycle: the native layer gives each fd up
        # before it is closed.
        self._deregister_fds(conn_num)
        self._close_lifecycle(conn_num)
        self._control.signal()

    def _retire(self, fd: int, close) -> None:
        """Unregister *fd* from the poller's selector, then call *close*.

        While the poller runs, the close is handed to it and nobody waits.
        """
        if threading.current_thread() is self._poller:
            self._forget_fd(fd)
            close()
            return
        with self._retire_lock:
            handed_off = self._poller_running
            if handed_off:
                self._retired.append((fd, close))
        if handed_off:
            self._control.signal()
        else:
            close()

    def _release_retired(self) -> None:
        """Poller thread: unregister and close the fds handed to it."""
        with self._retire_lock:
            pending, self._retired = self._retired, []
        for fd, close in pending:
            self._forget_fd(fd)
            close()

    def _forget_fd(self, fd: int) -> None:
        if self._selector is not None:
            try:
                self._selector.unregister(fd)
            except (KeyError, ValueError, OSError):
                pass
        self._selector_fds.discard(fd)

    def _deregister_fds(self, conn_num) -> None:
        """Close the wakeup fd for *conn_num* and remove it from the reverse map.

        The native layer gives the fd up first, so it never writes to a
        closed (or reused) descriptor.  The lifecycle fd is left open here —
        it is closed by :meth:`_close_lifecycle` only after the poller has
        exited.
        """
        if conn_num is None:
            return
        entry = self._conns.get(conn_num)
        if entry is not None:
            set_request_fd(conn_num, -1, server_mode=bool(entry.conn.server_mode))
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
            if entry.conn.server_mode is None:
                set_lifecycle_fd(conn_num, -1)
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

        conn_num: int = connection._conn_num

        wakeup = WakeupFd()
        # Lifecycle fd is always a pipe so reason bytes survive the round-trip.
        # Only Client connections hand the write end to the native layer.
        lc = WakeupFd(pipe=True)

        self._conns[conn_num] = _ConnEntry(conn=connection, wakeup=wakeup, lifecycle=lc)
        pool = self._pools.get(conn_num)
        if pool is not None:
            with pool.lock:
                pool.wakeup = wakeup
        self._rfd_to_conn_num[wakeup.read_fd] = conn_num
        self._rfd_to_conn_num[lc.read_fd] = conn_num

        # The connection is registered before the native layer gets the fd:
        # a wakeup for a connection the poller does not know yet would be
        # drained and lost, and the queue signals only once.
        self._admit(connection)

        set_request_fd(
            conn_num, wakeup.write_fd, server_mode=bool(connection.server_mode)
        )
        if connection.server_mode is None:
            set_lifecycle_fd(conn_num, lc.write_fd)
        # The poller may already be blocked in select. This wakes it so the
        # new fds are registered before the next wait.
        self._control.signal()

    def _admit(self, connection) -> None:
        """Add *connection* and make sure a poller is running for it."""
        with self._poller_lock:
            self.connections.add(connection)
            poller = self._poller
            if poller is not None and poller.is_alive() and self.stop_event.is_set():
                # The last connection is stopping this poller; let it finish.
                if poller is not threading.current_thread():
                    self._control.signal()
                    poller.join()
            if self._poller is None or not self._poller.is_alive():
                self.stop_event.clear()
                with self._retire_lock:
                    self._poller_running = True
                self._poller = self._new_poller()
                self._poller.start()

    def _new_poller(self) -> Thread:
        poller = Thread(target=self.handle_task_queue, name="daffi-poller", daemon=True)
        # RpcResult calls this before it blocks: see _hand_off.
        poller._daffi_hand_off = self._hand_off
        return poller

    def _hand_off(self) -> None:
        """Let a new thread poll while this one waits in a call of its own.

        A callback that runs inline and makes a blocking call would otherwise
        hold up every connection in the process, including the one that has
        to answer that call.  The connections this thread still owed tasks
        to are signalled again, so the new poller serves them at once; this
        thread finishes its callback and then exits.
        """
        me = threading.current_thread()
        with self._poller_lock:
            if self._poller is not me or self.stop_event.is_set():
                return
            # Still the poller here, so none of these descriptors can have
            # been closed yet: closing them is the poller's job.
            for conn in self._owed:
                entry = self._conns.get(getattr(conn, "_conn_num", None))
                if entry is not None:
                    entry.wakeup.signal()
            self._owed = set()
            self._poller = self._new_poller()
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

        Shutdown sets ``stop_event`` and signals the control pipe, which makes
        the selector return; the loop then sees ``stop_event``.
        """
        try:
            self._poll_loop()
        finally:
            # A thread that handed off leaves the selector to its successor.
            if self._poller is threading.current_thread():
                self._close_selector()
                # The selector is shut, so closing is no longer racing a wait.
                with self._retire_lock:
                    self._poller_running = False
                    pending, self._retired = self._retired, []
                for _, close in pending:
                    close()

    def _poll_loop(self) -> None:
        me = threading.current_thread()
        while not self.stop_event.is_set() and self._poller is me:
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
            notified: list = []
            self._owed = set()
            for rfd in readable:
                if self._poller is not me:
                    # Handed off: what is left unread stays readable for
                    # the new poller.
                    return
                conn_num = self._rfd_to_conn_num.get(rfd)
                if conn_num is None:
                    continue
                entry = self._conns.get(conn_num)
                if entry is None:
                    continue
                if rfd == entry.lifecycle.read_fd:
                    reason = entry.lifecycle.read(1)
                    if not reason:
                        continue
                    try:
                        _handle_lifecycle_signal(entry.conn, conn_num, reason)
                    except Exception:
                        entry.conn.logger.exception("Lifecycle handling failed")
                elif rfd == entry.wakeup.read_fd:
                    entry.wakeup.drain()
                    if entry.conn not in notified:
                        self._owed.add(entry.conn)
                        notified.append(entry.conn)

            for conn in notified:
                if self._poller is not me:
                    return
                if conn in self.connections:
                    self._drain_tasks(conn, me)
                if self._poller is me:
                    self._owed.discard(conn)

    def _drain_tasks(self, conn, me: Thread) -> None:
        """Take every queued task of *conn*.

        The native layer signals the fd once and not again until the queue
        has been seen empty, so this must keep going until it is: one failing
        task is logged and the rest still run.  A thread that handed off
        stops here; its successor was signalled to carry on.
        """
        poller = self.pollers[bool(conn.server_mode)]
        conn_num = conn._conn_num
        pool = self._pools.get(conn_num)
        while conn in self.connections and not self.stop_event.is_set() and self._poller is me:
            if pool is not None and pool.full():
                return
            try:
                task = poller(conn_num)
            except Exception:
                # The native layer has already dropped that message.
                conn.logger.exception("Could not read a queued task")
                continue
            if task is None:
                return
            try:
                self._dispatch_task(conn, conn_num, task)
            except Exception:
                conn.logger.exception("Task dispatch failed")

    def _dispatch_task(self, conn, conn_num: int, task: tuple) -> None:
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
            return
        pool = self._pools.get(conn_num)
        if pool is None:
            # No private pool means this connection runs inline.
            # A pool that was just removed belongs to a connection
            # that is stopping; leave that callback alone.
            if _pool_size(conn) == 1 and conn in self.connections:
                outcome = _invoke_callback(func_name, serde, data, _accepted(conn), _exposed(conn))
                # A connection stopped during the callback gets no reply.
                if return_result and conn in self.connections:
                    _send_reply(
                        bool(conn.server_mode),
                        conn_num,
                        uuid,
                        transmitter,
                        func_name,
                        outcome,
                        conn.logger,
                    )
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
            _accepted(conn),
            _exposed(conn),
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
            handlers = conn._on_member_added_handlers
        elif event_type == EventType.DISCONNECTED:
            handlers = conn._on_member_removed_handlers
        else:
            return
        for handler in handlers:
            try:
                handler(member)
            except Exception:
                conn.logger.exception(f"{event_type} handler {handler!r} failed")

    def _worker_loop(self, pool: _Pool) -> None:
        """Thread-pool worker body for one connection.

        Blocks on the pool's queue until a task arrives or a ``None``
        sentinel is received.  The sentinel is placed by
        :meth:`_stop_connection_workers` (one per worker).  Once the pool is
        closed, the tasks still queued and the reply of the running one are
        dropped.
        """
        for task in iter(pool.queue.get, None):
            if pool.closed:
                continue
            pool.took_task()
            (
                uuid,
                data,
                serde,
                transmitter,
                func_name,
                return_result,
                conn_num,
                server_mode,
                logger,
                accepted,
                exposed,
            ) = task
            outcome = _invoke_callback(func_name, serde, data, accepted, exposed)
            if return_result and not pool.closed:
                _send_reply(server_mode, conn_num, uuid, transmitter, func_name, outcome, logger)
