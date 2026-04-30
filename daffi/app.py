"""
User-facing application classes: Router, Service, and Client.
"""

import os
import sys
import socket
import threading

from abc import ABC
from enum import IntEnum
from threading import Event
from typing import Optional, List, Callable, Dict, Any

from . import dfcore

from daffi.utils import colors
from daffi.utils.logger import get_daffi_logger, sync_native_log_level
from daffi.exceptions import InitializationError
from daffi.utils.misc import string_uuid
from daffi._bindings import set_lifecycle_fd, set_response_fd
from daffi._rpc_proxy import (
    RpcProxy,
    SerdeFormat,
    ClientConnection,
    ResponseNotifier,
    system_exception_handler,
)
from daffi._signals import set_signal_handler
from daffi._task_dispatcher import TaskDispatcher, EventType
from daffi.registry._executor_registry import EXECUTOR_REGISTRY


class ServerMode(IntEnum):
    """Numeric codes passed to the native ``dfcore.startServer`` C extension."""

    ROUTER = 0
    SERVICE = 1


class EventsMixin:
    """Typed event-handler registration for :class:`Service` and :class:`Client`.

    Provides two decorator / callable registration methods:

    * :meth:`on_member_added`   — fires when a peer joins (``"connected"``).
    * :meth:`on_member_removed` — fires when a peer leaves (``"disconnected"``).

    Both can be used as plain method calls **or** as decorators::

        client = Client(app_name="watcher", host="127.0.0.1", port=6000)

        @client.on_member_added
        def handle_join(member: str) -> None:
            print(f"{member} joined")

        @client.on_member_removed
        def handle_leave(member: str) -> None:
            print(f"{member} left")

        conn = client.connect()
    """

    def __init_events__(self) -> None:
        self._on_member_added_handlers:   List[Callable[[str], Any]] = []
        self._on_member_removed_handlers: List[Callable[[str], Any]] = []

    def on_member_added(self, handler: Callable[[str], Any]) -> Callable[[str], Any]:
        """Register *handler* to be called whenever a peer joins the network.

        The handler receives the peer's ``app_name`` as its sole argument.
        Can be used as a decorator or as a plain method call.

        Args:
            handler: ``Callable[[str], Any]`` — receives the joining peer's name.

        Returns:
            The *handler* unchanged (so the method can be used as a decorator).
        """
        self._on_member_added_handlers.append(handler)
        return handler

    def on_member_removed(self, handler: Callable[[str], Any]) -> Callable[[str], Any]:
        """Register *handler* to be called whenever a peer leaves the network.

        The handler receives the peer's ``app_name`` as its sole argument.
        Can be used as a decorator or as a plain method call.

        Args:
            handler: ``Callable[[str], Any]`` — receives the departing peer's name.

        Returns:
            The *handler* unchanged (so the method can be used as a decorator).
        """
        self._on_member_removed_handlers.append(handler)
        return handler



class Application(EventsMixin, ABC):
    """Abstract base shared by :class:`Router`, :class:`Service`, and
    :class:`Client`.

    Handles common initialisation: name generation, logger setup, signal
    handler registration, and transport selection (TCP vs Unix socket).
    Inherits typed event-handler registration from :class:`EventsMixin`.
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
        # Serialises calls to ``stop()`` so concurrent callers (e.g. the
        # user thread + the disconnect watcher) cannot race on native
        # teardown — without it both threads could read ``_conn_num`` as
        # non-None and both call ``dfcore.stopClient`` (double-free).
        self._stop_lock = threading.Lock()
        self._connection_error: Optional[Exception] = None
        # True only while a thread is parked in :meth:`join` waiting on
        # ``_stop_event``.  Used by the disconnect watcher to decide whether
        # an unexpected disconnect can be surfaced via ``join`` (which will
        # re-raise ``_connection_error``) or whether it must be raised
        # directly from the watcher thread to avoid being silently swallowed.
        self._joining: bool = False
        self.__init_events__()
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

        # Propagate Python's current log level to the native Zig layer so that
        # std.log.debug / .info / .warn calls in the extension respect whatever
        # level the caller configured (e.g. logging.basicConfig(level=DEBUG)).
        sync_native_log_level()

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
            except Disconnected:
                pass   # silent disconnect
        """
        self._joining = True
        try:
            self._stop_event.wait()
        finally:
            self._joining = False
        # ``_stop_event`` is flipped only at the *end* of ``stop()``, so by
        # the time ``wait()`` returns the client (or server) is guaranteed
        # to be fully torn down — we can safely re-raise without doing any
        # additional cleanup ourselves.
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

    def start(self):
        """Start the server, register executors, and — for a :class:`Service` —
        launch the task dispatcher and perform the initial handshake.

        Connection-level protection (encryption + peer authentication) is
        delegated to TLS — pass ``tls=True`` together with ``cert_file`` /
        ``key_file`` (server) and ``ca_file`` (client) on the constructor.

        Raises:
            RuntimeError: If the server is already started.
            InitializationError: If the native layer fails to bind.

        Example::

            router = Router(host="127.0.0.1", port=6000)
            router.start()

            client = Client(host="127.0.0.1", port=6000)
            conn = client.connect()
        """
        if self._conn_num is not None:
            raise RuntimeError(f"{self.__class__.__name__} is already started")
        if self.server_mode == ServerMode.SERVICE:
            # Start the worker-thread pool before native I/O threads are
            # created.  Threads idle harmlessly until work arrives.
            if not self._task_dispatcher:
                self._task_dispatcher = TaskDispatcher(workers=self.workers)
            self._task_dispatcher._start_workers()
        with system_exception_handler(
            "{}",
            InitializationError,
            conn_info=(self.host, self.port, self.unix_sock_path),
        ):
            self._conn_num = dfcore.startServer(
                self.host,
                self.port,
                self.server_mode,
                self.app_name,
                self.tls,
                self.cert_file,
                self.key_file,
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


class Client(Application):
    """A client that connects to a :class:`Router` or :class:`Service` and
    issues RPC calls.

    Example::

        client = Client(app_name="my-client", host="127.0.0.1", port=5000)
        conn = client.connect()
        result = conn.rpc(timeout=5).add(1, 2)
        client.stop()
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
    ):
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

    def connect(self) -> "ClientConnection":
        """Connect to the server, perform the handshake, and return a connection handle.

        Connection-level protection (encryption + peer authentication) is
        delegated to TLS — pass ``tls=True`` together with ``ca_file`` on the
        constructor to authenticate the server's certificate.

        Returns:
            A :class:`~daffi.rpc_proxy.ClientConnection`.

        Raises:
            RuntimeError: If the client is already connected.
            InitializationError: If the native layer cannot connect.
        """
        if self._conn_num is not None:
            raise RuntimeError("Client is already connected")
        self._do_connect()
        return ClientConnection(self)

    def _do_connect(self) -> None:
        """Low-level connect: allocate native slot, handshake, start dispatcher.

        The TaskDispatcher is always created here regardless of ``workers``.
        Its poller thread monitors both task-arrival fds and the lifecycle fd
        so no separate watcher thread is needed.
        """
        # Always create the dispatcher so the poller thread runs unconditionally,
        # even when no @callback functions are registered on this client.
        if self._task_dispatcher is None:
            self._task_dispatcher = TaskDispatcher(workers=self.workers)
        self._task_dispatcher._start_workers()

        self._conn_num = dfcore.startClient(
            self.host,
            self.port,
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
        try:
            handshake = RpcProxy._process_client_handshake(self._conn_num)
        except Exception:
            # Tear the native slot down so the caller can retry connect()
            # without hitting the "already connected" guard.
            ResponseNotifier.unregister(self._conn_num)
            try:
                dfcore.stopClient(self._conn_num)
            except Exception:
                pass
            self._conn_num = None
            raise
        self._conn_type = handshake["meta"]["type"]
        self.logger.debug(
            f"has been connected successfully. connection info: {self.info}"
        )
        self._task_dispatcher.start_for_connection(self)
        self._register_executors()

    def stop(self, *_, **__):
        """Stop the client: join task-dispatcher threads, then destroy the
        native connection.

        Idempotent and safe to call from multiple threads.  Two invariants:

        * The full teardown is serialised by ``_stop_lock`` so concurrent
          callers (e.g. user thread + disconnect watcher) cannot both call
          ``dfcore.stopClient`` on the same handle (double-free).

        * ``_stop_event`` is flipped **last**, after every resource has been
          released.  Anyone parked in ``_stop_event.wait()`` (notably
          :meth:`Application.join`) is therefore guaranteed to observe a
          fully-stopped client — no half-torn-down race window where
          ``_conn_num`` is still set.
        """
        with self._stop_lock:
            if self._conn_num is not None:
                try:
                    set_lifecycle_fd(self._conn_num, -1)
                except Exception:
                    pass
                try:
                    set_response_fd(self._conn_num, -1)
                except Exception:
                    pass
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
            self._stop_event.set()
