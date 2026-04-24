"""
User-facing application classes: Router, Service, and Client.
"""

import os
import sys
import select
import socket
import threading
import time
from abc import ABC
from enum import IntEnum
from threading import Event
from typing import Optional, List, Callable, Dict, Any, Union

from . import dfcore

from daffi.utils import colors
from daffi.utils.logger import get_daffi_logger
from daffi.exceptions import InitializationError
from daffi.utils.misc import string_uuid
from daffi._bindings import set_client_disconnect_fd
from daffi._rpc_proxy import (
    RpcProxy,
    SerdeFormat,
    ClientConnection,
    AutoReconnect,
    ResponseNotifier,
)
from daffi._signals import set_signal_handler
from daffi._task_dispatcher import TaskDispatcher
from daffi.registry._executor_registry import EXECUTOR_REGISTRY


class ServerMode(IntEnum):
    """Numeric codes passed to the native ``dfcore.startServer`` C extension."""

    ROUTER = 0
    SERVICE = 1


class Application(ABC):
    """Abstract base shared by :class:`Router`, :class:`Service`, and
    :class:`Client`.

    Handles common initialisation: name generation, logger setup, signal
    handler registration, and transport selection (TCP vs Unix socket).
    """

    server_mode: ServerMode = None
    _task_dispatcher: TaskDispatcher = None

    def __init__(
        self,
        app_name: Optional[str] = None,
        host: Optional[str] = None,
        port: Optional[int] = None,
        unix_sock_path: Optional[os.PathLike] = None,
        workers: int = TaskDispatcher.DEFAULT_WORKERS,
        tls: bool = False,
        cert_file: str = "",
        key_file: str = "",
        ca_file: str = "",
    ):
        """
        Args:
            app_name:      Human-readable identifier for this node. A random
                           hex UUID is used when omitted.
            host:          TCP hostname or IP address.
            port:          TCP port number.
            unix_sock_path: Path to a Unix-domain socket (mutually exclusive
                           with *host*/*port*).
            workers:       Number of concurrent worker **threads** for executing
                           incoming ``@callback`` calls.  ``1`` (default) runs
                           callbacks inline with zero overhead.  ``N >= 2``
                           spawns a pool of N-1 threads.  Ignored by
                           :class:`Router` which never executes callbacks
                           itself.
            tls:           Enable TLS encryption for the TCP connection.
                           Servers require ``cert_file`` and ``key_file``.
                           Clients may optionally supply ``ca_file``.
            cert_file:     Path to a PEM server certificate
                           (used by :class:`Router` and :class:`Service`).
            key_file:      Path to a PEM server private key
                           (used by :class:`Router` and :class:`Service`).
            ca_file:       Path to a PEM CA bundle used by a :class:`Client`
                           to verify the server certificate.  An empty string
                           disables peer verification (connect without
                           authenticating the server certificate).
        """
        self.app_name = app_name
        self.host = host
        self.port = port
        self.unix_sock_path = str(unix_sock_path or "")
        self.workers = workers
        self.tls = tls
        self.cert_file = cert_file
        self.key_file = key_file
        self.ca_file = ca_file
        self._conn_num = None
        self._conn_type = None
        self._stop_event = Event()
        self._connection_error: Optional[Exception] = None
        self.event_handlers: List[Callable[[Dict], Any]] = []
        self._executors_subscribed: bool = False

        if self.app_name is None:
            self.app_name = f"{socket.gethostname()}-{string_uuid()}"
        self.app_name = str(self.app_name)

        process_ident = f"{self.__class__.__name__.lower()}[{self.app_name}]"
        if self.server_mode == ServerMode.ROUTER:
            color = colors.blue
        elif self.server_mode == ServerMode.SERVICE:
            color = colors.yellow
        else:
            color = colors.magenta
        self.logger = get_daffi_logger(process_ident, color)

        if self.unix_sock_path and self.host:
            raise InitializationError(
                "Provide either 'unix_sock_path' argument or combination "
                "of 'host' and 'port' to connect via unix socket or via tcp respectively"
            )

        if not self.host and sys.platform == "win32":
            raise InitializationError(
                "Windows platform doesn't support unix sockets. Provide host and port to use TCP"
            )

        set_signal_handler(self.stop)

    @property
    def info(self) -> str:
        """Human-readable connection string shown in log messages."""
        if self.unix_sock_path:
            sock = "unix:///" + self.unix_sock_path.strip("unix:///")
            return f"unix socket: [ {sock!r} ]"
        else:
            return f"tcp: [ host {self.host!r}, port: {self.port!r} ]"

    def _register_executors(self):
        """Log all currently registered callbacks and subscribe for future ones.

        The subscriber is added only once — reconnects reuse the same closure,
        which always references the current ``self._conn_num``.
        """
        for _, executor in EXECUTOR_REGISTRY:
            self.logger.debug(f"{executor} registered.")

        if not self._executors_subscribed:
            self._executors_subscribed = True

            def registry_subscriber(executor):
                # Guard: if the connection was stopped, _conn_num is None.
                # This can happen when fork()-based subprocesses inherit a stale
                # subscriber list, or when @callback is applied after stop().
                if self._conn_num is None:
                    return
                try:
                    if self.server_mode is None:
                        RpcProxy._process_client_handshake(self._conn_num)
                    elif self.server_mode == ServerMode.SERVICE:
                        RpcProxy._process_service_handshake(self._conn_num)
                    else:
                        return
                except (ValueError, OSError):
                    # Native connection no longer valid — remove this stale
                    # subscriber so it does not fire again.
                    try:
                        EXECUTOR_REGISTRY.subscribers.remove(registry_subscriber)
                    except ValueError:
                        pass
                    return
                self.logger.debug(f"{executor} registered.")

            self._registry_subscriber = registry_subscriber
            EXECUTOR_REGISTRY.subscribers.append(registry_subscriber)

    def _unregister_executor_subscriber(self) -> None:
        """Remove the registry subscriber added by :meth:`_register_executors`.

        Called from ``stop()`` on both server-side and client-side subclasses so
        that future ``@callback`` applications do not trigger a handshake on a
        connection that is already closed.
        """
        sub = getattr(self, "_registry_subscriber", None)
        if sub is not None:
            try:
                EXECUTOR_REGISTRY.subscribers.remove(sub)
            except ValueError:
                pass
            self._registry_subscriber = None
        self._executors_subscribed = False

    def join(self):
        """Block the calling thread until :meth:`stop` is called (or until a
        registered signal handler triggers it).

        Works on every node type — :class:`Router`, :class:`Service`, and
        :class:`Client` alike.  This is the idiomatic way to keep a process
        alive without importing ``signal``::

            client = Client(app_name="worker", host="127.0.0.1", port=6001)
            client.connect()
            client.join()   # blocks until Ctrl+C (SIGINT/SIGTERM → stop())

        For :class:`Client` nodes the method also re-raises any connection
        error that was not handled by the application (e.g. the server
        disconnecting unexpectedly).  If you want to suppress the error wrap
        the call in a ``try/except``::

            try:
                client.join()
            except ConnectionError:
                pass   # silent disconnect
        """
        self._stop_event.wait()
        if self._connection_error is not None:
            raise self._connection_error

    def stop(self, *args, **kwargs):
        """Stop the application. Subclasses provide the actual teardown logic."""
        self._unregister_executor_subscriber()
        return super().stop(*args, **kwargs)


class ServerMixin:
    """Mixin that adds ``start()`` / ``stop()`` to server-side components
    (:class:`Router` and :class:`Service`).

    ``join()`` is inherited from :class:`Application` and available on all
    node types.
    """

    def start(self, password: str = ""):
        """Start the server, register executors, and — for a :class:`Service` —
        launch the task dispatcher and perform the initial handshake.

        Args:
            password: Optional shared secret used to restrict access.  When
                      set, every client must pass the identical value to
                      :meth:`~daffi.app.Client.connect`; the handshake is
                      rejected and the connection is dropped if the passwords
                      do not match.  Leaving it empty (the default) disables
                      authentication and accepts any client.

        Raises:
            RuntimeError: If the server is already started.
            InitializationError: If the native layer fails to bind.

        Example — password-protected router::

            # server side
            router = Router(host="127.0.0.1", port=6000)
            router.start(password="s3cr3t")

            # client side — must supply the same password
            client = Client(host="127.0.0.1", port=6000)
            conn = client.connect(password="s3cr3t")
        """
        if self._conn_num is not None:
            raise RuntimeError(f"{self.__class__.__name__} is already started")
        if self.server_mode == ServerMode.SERVICE:
            # Start the worker-thread pool before native I/O threads are
            # created.  Threads idle harmlessly until work arrives.
            if not self._task_dispatcher:
                self._task_dispatcher = TaskDispatcher(workers=self.workers)
            self._task_dispatcher._start_workers()
        self._conn_num = dfcore.startServer(
            self.host,
            self.port,
            self.server_mode,
            password,
            self.app_name,
            self.tls,
            self.cert_file,
            self.key_file,
        )
        if self._conn_num is None:
            raise InitializationError(
                f"Failed to start the server. connection info: {self.info}"
            )
        self.logger.debug(
            f"has been started successfully. connection info: {self.info}"
        )
        self._register_executors()
        if self.server_mode == ServerMode.SERVICE:
            self._task_dispatcher.start_for_connection(self)
            RpcProxy._process_service_handshake(self._conn_num)

    def stop(self, *_, **__):
        """Stop the server and release the native connection."""
        if not self._stop_event.is_set():
            if self._conn_num is not None:
                dfcore.stopServer(self._conn_num)
                self._conn_num = None
        self._stop_event.set()
        if self._task_dispatcher:
            self._task_dispatcher.stop_for_connection(self)


class Router(Application, ServerMixin):
    """A routing server that forwards RPC calls between connected clients and
    services.

    The Router does not execute callbacks itself; it only routes messages based
    on the receiver name embedded in each request.

    Example::

        router = Router(host="127.0.0.1", port=6000)
        router.start()
        router.join()
    """

    server_mode = ServerMode.ROUTER


class Service(Application, ServerMixin):
    """A server that exposes ``@callback``-decorated functions to remote callers.

    Example::

        from daffi import Service, callback

        @callback
        def add(a: int, b: int) -> int:
            return a + b

        svc = Service(host="127.0.0.1", port=5000)
        svc.start()
        svc.join()
    """

    server_mode = ServerMode.SERVICE

    def add_event_handler(self, handler: Callable[[Dict], Any]):
        """Register a callable invoked whenever a node connects or disconnects.

        The framework emits an EVENTS message each time a client or service
        joins or leaves the network.  The handler is called on the task-worker
        thread with a single ``dict`` argument whose keys are always:

        * ``"type"`` — ``"connected"`` or ``"disconnected"``
        * ``"member"`` — the ``app_name`` of the node that changed state

        Multiple handlers can be registered; they are called in registration
        order.

        Args:
            handler: Callable that accepts one ``dict`` argument.

        Example::

            def on_event(event: dict):
                if event["type"] == "connected":
                    print(f"{event['member']} joined")
                elif event["type"] == "disconnected":
                    print(f"{event['member']} left")

            svc = Service(host="127.0.0.1", port=5000)
            svc.add_event_handler(on_event)
            svc.start()
        """
        self.event_handlers.append(handler)


class Client(Application):
    """A client that connects to a :class:`Router` or :class:`Service` and
    issues RPC calls.

    Example — simple call::

        client = Client(app_name="my-client", host="127.0.0.1", port=5000)
        conn = client.connect()
        result = conn.rpc(timeout=5).add(1, 2)
        client.stop()

    Example — caller with automatic reconnect::

        client = Client(
            app_name="my-caller",
            host="127.0.0.1", port=6000,
            autoreconnect=True,
            reconnect_delay=2.0,
        )
        conn = client.connect()   # returns AutoReconnect instance

        # If the router restarts, this call blocks until reconnected, then
        # sends the request transparently — no manual retry loop needed.
        result = conn.rpc(timeout=5).process("task")
    """

    def __init__(
        self,
        app_name: Optional[str] = None,
        host: Optional[str] = None,
        port: Optional[int] = None,
        unix_sock_path: Optional[os.PathLike] = None,
        workers: int = TaskDispatcher.DEFAULT_WORKERS,
        tls: bool = False,
        cert_file: str = "",
        key_file: str = "",
        ca_file: str = "",
        autoreconnect: bool = False,
        reconnect_delay: float = 2.0,
    ):
        """
        Args:
            autoreconnect:   When ``True``, :meth:`connect` returns an
                             :class:`~daffi.rpc_proxy.AutoReconnect` adapter
                             instead of a plain :class:`~daffi.rpc_proxy.ClientConnection`.
                             Every call on the adapter checks the connection liveness
                             first and blocks with exponential back-off until
                             reconnected if the server is unreachable.
                             Default: ``False``.
            reconnect_delay: Base delay in seconds before the first reconnect
                             attempt.  Doubles after each failure, capped at
                             60 s.  Default: ``2.0``.

            All other arguments are the same as :class:`Application`.
        """
        super().__init__(
            app_name=app_name,
            host=host,
            port=port,
            unix_sock_path=unix_sock_path,
            workers=workers,
            tls=tls,
            cert_file=cert_file,
            key_file=key_file,
            ca_file=ca_file,
        )
        self._autoreconnect = autoreconnect
        self._reconnect_delay = max(0.5, reconnect_delay)
        # Pipe used by the disconnect watcher thread (non-autoreconnect).
        # write-end is handed to the native layer; closing it also wakes the
        # watcher thread so stop() doesn't leave it blocking forever.
        self._disc_pipe_r: Optional[int] = None
        self._disc_pipe_w: Optional[int] = None

    @property
    def info(self) -> str:
        """Human-readable connection string (includes the connection type once
        the handshake has completed)."""
        if self.unix_sock_path:
            sock = "unix:///" + self.unix_sock_path.strip("unix:///")
            return f"unix socket: [ {sock!r} ]"
        else:
            type_part = (
                f", type: {self._conn_type!r}" if self._conn_type is not None else ""
            )
            return f"tcp: [ host {self.host!r}, port: {self.port!r}{type_part} ]"

    def connect(self, password: str = "") -> Union["ClientConnection", "AutoReconnect"]:
        """Connect to the server, perform the handshake, and return a connection handle.

        Returns a :class:`~daffi.rpc_proxy.ClientConnection` normally.
        When ``autoreconnect=True`` was passed to the constructor it returns an
        :class:`~daffi.rpc_proxy.AutoReconnect` adapter instead — the API is
        identical, but each call transparently reconnects on connection loss before
        executing.

        Args:
            password: Must match the password the server was started with.
                      Pass an empty string (the default) when the server was
                      started without a password.

        Returns:
            A :class:`~daffi.rpc_proxy.ClientConnection` (normal) or
            :class:`~daffi.rpc_proxy.AutoReconnect` (when ``autoreconnect=True``).

        Raises:
            RuntimeError: If the client is already connected.
            InitializationError: If the native layer cannot connect.
        """
        if self._conn_num is not None:
            raise RuntimeError("Client is already connected")
        self._do_connect(password)
        time.sleep(0.005)  # flush the log
        conn = ClientConnection(self, password)
        if self._autoreconnect:
            conn = AutoReconnect(conn)
        return conn

    def _do_connect(self, password: str) -> None:
        """Low-level connect: allocate native slot, handshake, start dispatcher."""
        # Start the worker-thread pool before native I/O threads are created.
        # Threads idle harmlessly until work arrives.
        if self.workers > 1:
            if self._task_dispatcher is None:
                self._task_dispatcher = TaskDispatcher(workers=self.workers)
            self._task_dispatcher._start_workers()

        self._conn_num = dfcore.startClient(
            self.host,
            self.port,
            password,
            self.app_name,
            self.tls,
            self.ca_file,
        )
        if self._conn_num is None:
            raise InitializationError(
                f"Failed to connect to the server. connection info: {self.info}"
            )
        # Register the response notifier *before* the handshake so the
        # handshake's own RpcResult also benefits from event-driven wakeups
        # rather than polling.  ``register`` clears any stale notifier left
        # over from a previous (e.g. failed) connect on the same handle.
        ResponseNotifier.register(self._conn_num)
        handshake = RpcProxy._process_client_handshake(self._conn_num)
        self._conn_type = handshake["meta"]["type"]
        self.logger.debug(
            f"has been connected successfully. connection info: {self.info}"
        )
        if self._conn_type == "router":
            if self._task_dispatcher is None:
                self._task_dispatcher = TaskDispatcher(workers=self.workers)
            self._task_dispatcher.start_for_connection(self)
            self._register_executors()
            if not self._autoreconnect:
                self._start_disconnect_watcher()

    def add_event_handler(self, handler: Callable[[Dict], Any]):
        """Register a callable invoked whenever a node connects or disconnects.

        The framework emits an EVENTS message each time a service or other
        client joins or leaves the network.  The handler is called on the
        task-worker thread with a single ``dict`` argument whose keys are
        always:

        * ``"type"`` — ``"connected"`` or ``"disconnected"``
        * ``"member"`` — the ``app_name`` of the node that changed state

        Multiple handlers can be registered; they are called in registration
        order.

        Args:
            handler: Callable that accepts one ``dict`` argument.

        Example::

            def on_event(event: dict):
                if event["type"] == "connected":
                    print(f"{event['member']} joined")
                elif event["type"] == "disconnected":
                    print(f"{event['member']} left")

            client = Client(app_name="watcher", host="127.0.0.1", port=6000)
            client.add_event_handler(on_event)
            conn = client.connect()
        """
        self.event_handlers.append(handler)

    def _start_disconnect_watcher(self) -> None:
        """Start a daemon thread that unblocks :meth:`join` when the server closes
        the connection unexpectedly (i.e. without a user-initiated :meth:`stop`).

        A pipe is created; the write-end is handed to the native layer via
        ``setClientDisconnectFd``.  When the connection is lost the native layer
        writes one byte to the write-end, the thread wakes, and — if :meth:`stop`
        has not already been called — stores a :class:`ConnectionError` and sets
        the stop event so :meth:`join` returns and re-raises the error.
        """
        r, w = os.pipe()
        self._disc_pipe_r = r
        self._disc_pipe_w = w
        set_client_disconnect_fd(self._conn_num, w)

        def _watch(stop_event: Event, client_ref) -> None:
            try:
                select.select([r], [], [])
            except Exception:
                pass
            finally:
                try:
                    os.close(r)
                except OSError:
                    pass
            # Only record an error if stop() was NOT the one that triggered this.
            if not stop_event.is_set():
                client_ref._connection_error = ConnectionError(
                    "Server disconnected unexpectedly.\n\n"
                    "  The router or service this client was connected to has stopped.\n"
                    "  If you want to reconnect automatically, use:\n"
                    "      Client(..., autoreconnect=True)"
                )
                stop_event.set()

        t = threading.Thread(
            target=_watch,
            args=(self._stop_event, self),
            name="daffi-disc-watcher",
            daemon=True,
        )
        t.start()

    def stop(self, *_, **__):
        """Stop the client: signal the reconnect loop, join task-dispatcher
        threads, then destroy the native connection."""
        if not self._stop_event.is_set():
            self._stop_event.set()
            # Wake the disconnect-watcher thread so it exits cleanly.
            if self._disc_pipe_w is not None:
                try:
                    os.close(self._disc_pipe_w)
                except OSError:
                    pass
                self._disc_pipe_w = None
            if self._task_dispatcher:
                self._task_dispatcher.stop_for_connection(self)
            if self._conn_num is not None:
                # Tear the notifier thread down before freeing the native
                # slot — its select on the wakeup fd does not hold a
                # reference to conn_num, but we want the thread to exit
                # cleanly so it doesn't observe a freed Zig-side fd.
                ResponseNotifier.unregister(self._conn_num)
                dfcore.stopClient(self._conn_num)
                self._conn_num = None
