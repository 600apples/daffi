"""
User-facing application classes: Router, Service, and Client.
"""

import os
import sys
import socket
import time
from abc import ABC
from enum import IntEnum
from threading import Event
from typing import Optional, List, Callable, Dict, Any

from . import dfcore

from daffi.utils import colors
from daffi.utils.logger import get_daffi_logger
from daffi.exceptions import InitializationError
from daffi.utils.misc import string_uuid
from daffi.rpc_proxy import RpcProxy, SerdeFormat, ClientConnection
from daffi.signals import set_signal_handler
from daffi.task_dispatcher import TaskDispatcher
from daffi.registry.executor_registry import EXECUTOR_REGISTRY


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
            workers:       Number of worker threads that execute incoming
                           ``@callback`` calls concurrently.  Defaults to
                           ``max(1, os.cpu_count() // 2)``.  Increase for
                           I/O-heavy callbacks; ignored by :class:`Router`
                           which never executes callbacks itself.
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
        self.event_handlers: List[Callable[[Dict], Any]] = []

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
        """Log all currently registered callbacks and subscribe for future ones."""
        for _, executor in EXECUTOR_REGISTRY:
            self.logger.info(f"{executor} registered.")

        def registry_subscriber(executor):
            if self.server_mode is None:
                RpcProxy._process_client_handshake(self._conn_num)
            elif self.server_mode == ServerMode.SERVICE:
                RpcProxy._process_service_handshake(self._conn_num)
            else:
                return
            self.logger.info(f"{executor} registered.")

        EXECUTOR_REGISTRY.subscribers.append(registry_subscriber)

    def stop(self, *args, **kwargs):
        """Stop the application. Subclasses provide the actual teardown logic."""
        return super().stop(*args, **kwargs)


class ServerMixin:
    """Mixin that adds ``start()`` / ``stop()`` / ``join()`` to server-side
    components (:class:`Router` and :class:`Service`)."""

    def join(self):
        """Block the calling thread until :meth:`stop` is called."""
        self._stop_event.wait()

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
        self._conn_num = dfcore.startServer(
            self.host, self.port, self.server_mode, password, self.app_name,
            self.tls, self.cert_file, self.key_file,
        )
        if self._conn_num is None:
            raise InitializationError(
                f"Failed to start the server. connection info: {self.info}"
            )
        self.logger.info(f"has been started successfully. connection info: {self.info}")
        self._register_executors()
        if self.server_mode == ServerMode.SERVICE:
            if not self._task_dispatcher:
                self._task_dispatcher = TaskDispatcher(workers=self.workers)
            self._task_dispatcher.start_for_connection(self)
            RpcProxy._process_service_handshake(self._conn_num)

    def stop(self, *_, **__):
        """Stop the server and release the native connection."""
        if not self._stop_event.is_set():
            if self._conn_num is not None:
                dfcore.stopServer(self._conn_num)
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

    Example::

        client = Client(app_name="my-client", host="127.0.0.1", port=5000)
        conn = client.connect()
        result = conn.rpc(timeout=5).add(1, 2)
        client.stop()
    """

    @property
    def info(self) -> str:
        """Human-readable connection string (includes the connection type once
        the handshake has completed)."""
        if self.unix_sock_path:
            sock = "unix:///" + self.unix_sock_path.strip("unix:///")
            return f"unix socket: [ {sock!r} ]"
        else:
            return f"tcp: [ host {self.host!r}, port: {self.port!r}, type: {self._conn_type!r} ]"

    def connect(self, password: str = "") -> "ClientConnection":
        """Connect to the server, perform the handshake, and return a
        :class:`ClientConnection` ready for RPC calls.

        Args:
            password: Must match the password the server was started with.
                      Pass an empty string (the default) when the server was
                      started without a password.  A mismatch causes the
                      handshake to be rejected and the connection to be dropped.

        Returns:
            A :class:`ClientConnection` bound to this client.

        Raises:
            RuntimeError: If the client is already connected.
            InitializationError: If the native layer cannot connect.
        """
        if self._conn_num is not None:
            raise RuntimeError("Client is already connected")
        self._conn_num = dfcore.startClient(
            self.host, self.port, password, self.app_name,
            self.tls, self.ca_file,
        )
        if self._conn_num is None:
            raise InitializationError(
                f"Failed to connect to the server. connection info: {self.info}"
            )
        handshake = RpcProxy._process_client_handshake(self._conn_num)
        self._conn_type = handshake["meta"]["type"]
        self.logger.info(
            f"has been connected successfully." f" connection info: {self.info}"
        )
        if self._conn_type == "router":
            if not self._task_dispatcher:
                self._task_dispatcher = TaskDispatcher(workers=self.workers)
            self._task_dispatcher.start_for_connection(self)
            self._register_executors()
        time.sleep(0.005)  # flush the log
        return ClientConnection(self)

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

    def stop(self, *_, **__):
        """Stop the client: join task-dispatcher threads first, then destroy
        the native connection to avoid use-after-free races."""
        if not self._stop_event.is_set():
            self._stop_event.set()
            if self._task_dispatcher:
                self._task_dispatcher.stop_for_connection(self)
            if self._conn_num is not None:
                dfcore.stopClient(self._conn_num)
