"""
User-facing application classes: Router, Service, and Client.
"""

import socket
import threading

from abc import ABC
from enum import Enum, IntEnum
from threading import Event
from collections.abc import Iterable
from typing import Optional, List, Callable, Any

from . import dfcore
from daffi._serialization import SerdeFormat

from daffi.utils import colors
from daffi.utils.logger import get_daffi_logger, sync_native_log_level
from daffi.exceptions import Evicted, InitializationError
from daffi.utils.misc import string_uuid
from daffi._rpc_proxy import (
    RpcProxy,
    ClientConnection,
    system_exception_handler,
)
from daffi._signals import SIGNAL_POLL_S, set_signal_handler
from daffi._task_dispatcher import TaskDispatcher, shared_dispatcher
from daffi.registry._executor_registry import EXECUTOR_REGISTRY
from daffi.transports import (
    TCPTransport,
    Transport,
    TransportArg,
    UnixTransport,
    normalize_transports,
)


class Runtime(str, Enum):
    """Process-wide native runtime.

    ``threads`` serves every connection on its own OS thread. ``evented``
    multiplexes connections over a few event-loop threads. A
    :class:`Client` uses the same runtime as a :class:`Router` or
    :class:`Service`: the native core locks it once per process.
    """

    THREADS = "threads"
    EVENTED = "evented"


def _coerce_runtime(value: "Runtime | str") -> Runtime:
    if isinstance(value, Runtime):
        return value
    try:
        return Runtime(value)
    except ValueError:
        raise InitializationError(
            "runtime must be 'threads' or 'evented', "
            f"got {value!r}"
        ) from None


def _coerce_serdes(value: "Iterable[int] | None") -> frozenset:
    if value is None:
        return SerdeFormat.ALL
    if isinstance(value, (str, bytes)) or not isinstance(value, Iterable):
        raise InitializationError(
            f"serdes must be a collection of SerdeFormat values, got {value!r}"
        )
    serdes = frozenset(value)
    unknown = sorted(serdes - SerdeFormat.ALL, key=repr)
    if unknown:
        raise InitializationError(
            f"serdes has unknown formats {unknown!r}; use SerdeFormat values"
        )
    if not serdes:
        raise InitializationError("serdes must name at least one format")
    return serdes


def _callback_names(value) -> "frozenset[str] | None":
    """The names ``callbacks=`` allows: strings as given, ``@callback``
    objects by the names they registered, functions by alias or name."""
    from daffi.registry._callback import callback as _callback

    if value is None:
        return None
    if isinstance(value, (str, bytes)) or not isinstance(value, Iterable):
        raise InitializationError(
            f"callbacks must be a collection of names or callbacks, got {value!r}"
        )
    names: set[str] = set()
    for item in value:
        if isinstance(item, str) and item:
            names.add(item)
        elif isinstance(item, _callback):
            names.update(item.names)
        elif callable(item) and hasattr(item, "__name__"):
            names.add(getattr(item, "alias", item.__name__))
        else:
            raise InitializationError(f"invalid entry in callbacks: {item!r}")
    return frozenset(names)


def _coerce_auth_token(value: "str | None") -> "str | None":
    if value is None:
        return None
    if not isinstance(value, str):
        raise InitializationError(f"auth_token must be a str, got {type(value).__name__}")
    if not value or "\0" in value:
        raise InitializationError("auth_token must be a non-empty string without NUL characters")
    return value


class ServerMode(IntEnum):
    """Numeric codes passed to the native ``dfcore.addListeners`` C extension."""

    ROUTER = 0
    SERVICE = 1


class EventsMixin:
    """Typed event-handler registration for :class:`Service` and :class:`Client`.

    Provides two decorator / callable registration methods:

    * :meth:`on_member_added`   — fires when a peer joins (``"connected"``).
    * :meth:`on_member_removed` — fires when a peer leaves (``"disconnected"``).

    Both can be used as plain method calls **or** as decorators::

        client = Client(app_name="watcher", transport=TCPTransport("127.0.0.1", 6000))

        @client.on_member_added
        def handle_join(member: str) -> None:
            print(f"{member} joined")

        @client.on_member_removed
        def handle_leave(member: str) -> None:
            print(f"{member} left")

        conn = client.connect()
    """

    def __init_events__(self) -> None:
        self._on_member_added_handlers: List[Callable[[str], Any]] = []
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


class SingleTransportMixin:
    """Public single-address API used by Client and AsyncClient."""

    _transports: list[Transport]

    def __init__(self, *, transport: Transport, **kwargs) -> None:
        if not isinstance(transport, (TCPTransport, UnixTransport)):
            raise InitializationError(
                "transport must be a TCPTransport or UnixTransport"
            )
        self._transports = [transport]
        super().__init__(**kwargs)

    @property
    def transport(self) -> Transport:
        """The one address this client connects to."""
        return self._transports[0]

    @property
    def info(self) -> str:
        """Human-readable connect address."""
        return f"transport: {self.transport.describe()}"


class MultipleTransportMixin:
    """Public multi-address API used by Router and Service.

    ``transport=`` accepts one :class:`TCPTransport` / :class:`UnixTransport`,
    or a sequence of them.  Listeners live in :attr:`_transports`;
    :attr:`transports` is a read-only view of that list.
    """

    _transports: list[Transport]

    def __init__(self, *, transport: TransportArg, **kwargs) -> None:
        self._transports = normalize_transports(transport)
        super().__init__(**kwargs)

    @property
    def transports(self) -> list[Transport]:
        """Normalized listen addresses (always a list)."""
        return self._transports

    @property
    def info(self) -> str:
        """Human-readable listen addresses."""
        listed = ", ".join(item.describe() for item in self._transports)
        return f"transports: [ {listed} ]"


class Application(EventsMixin, ABC):
    """Abstract base shared by :class:`Router`, :class:`Service`, and
    :class:`Client`.

    Owns common lifecycle state only. Subscribe it with a transport mixin,
    ``Application[SingleTransportMixin]`` or
    ``Application[MultipleTransportMixin]``. That subscription is a real base
    class: the mixin is placed ahead of ``Application`` and normalizes
    addresses before this initializer runs.
    """

    _transport_specializations: dict[tuple[type, type], type] = {}

    def __class_getitem__(cls, transport_api: type) -> type:
        if not isinstance(transport_api, type):
            raise TypeError("transport API must be a mixin class")
        key = (cls, transport_api)
        specialized = Application._transport_specializations.get(key)
        if specialized is None:
            specialized = type(
                f"{cls.__name__}[{transport_api.__name__}]",
                (transport_api, cls),
                {"__module__": cls.__module__},
            )
            Application._transport_specializations[key] = specialized
        return specialized

    server_mode: ServerMode = None
    _task_dispatcher: TaskDispatcher = None

    def __init__(
        self,
        app_name: Optional[str] = None,
        workers: int = TaskDispatcher.DEFAULT_WORKERS,
        runtime: Optional[Runtime | str] = None,
        transport: TransportArg | None = None,
        serdes: Optional[Iterable[int]] = None,
        auth_token: Optional[str] = None,
        callbacks: Optional[Iterable[Any]] = None,
    ):
        """
        Args:
            app_name:      Human-readable identifier for this node. A random
                           hex UUID is used when omitted.
            workers:       Number of concurrent worker **threads** for executing
                           incoming ``@callback`` calls.  ``1`` (default) runs
                           callbacks inline with zero overhead.  ``N >= 2``
                           spawns a pool of N-1 threads.  Ignored by
                           :class:`Router` which never executes callbacks
                           itself.
            runtime:       Native runtime for this process,
                           :attr:`Runtime.THREADS` (default) or
                           :attr:`Runtime.EVENTED`.  Omitting it, or passing
                           ``None``, selects threads.  A Client, Router, and
                           Service in one process share this choice; a
                           conflicting value raises
                           :class:`InitializationError`.
            transport:     Listen/connect address(es).  Declared here so type
                           checkers see it on :class:`Router`, :class:`Service`,
                           and :class:`Client` (their ``Application[…]`` bases
                           are built at runtime).  At runtime the transport
                           mixin consumes this argument before this
                           ``__init__`` runs and stores the result on
                           ``_transports``.  TLS is configured on each
                           :class:`~daffi.transports.TCPTransport`, not here.
            serdes:        The :class:`SerdeFormat` values this node accepts
                           in incoming ``@callback`` requests; a request in
                           any other format is answered with a
                           ``SerdeNotAllowed`` error and never decoded.
                           ``None`` (default) accepts every format.  Leave
                           out ``SerdeFormat.PICKLE`` unless every peer is
                           trusted: unpickling runs code the sender chooses.
                           PICKLE from a WebSocket peer is always refused.
                           Ignored by :class:`Router`.
            auth_token:    Shared secret.  A :class:`Router` or
                           :class:`Service` given one refuses every peer
                           whose handshake does not carry the same token; a
                           :class:`Client` sends it.  It travels in the clear
                           unless the transport uses TLS.  ``None``
                           (default) accepts any peer.
            callbacks:     The ``@callback`` functions (or their names) this
                           node offers to peers.  The others are neither
                           announced nor run: a request for one fails as an
                           unknown callback.  ``None`` (default) offers
                           every registered callback.  Ignored by
                           :class:`Router`.
        """
        # Mixins set ``_transports`` before calling us; ``transport`` itself
        # never arrives here when constructed via Router/Service/Client.
        if not getattr(self, "_transports", None):
            raise InitializationError("transport is required")
        if runtime is None:
            runtime = Runtime.THREADS
        self.runtime = _coerce_runtime(runtime)
        try:
            dfcore.setRuntime(self.runtime.value)
        except ValueError as exc:
            raise InitializationError(str(exc)) from exc
        self.app_name = app_name
        self.workers = workers
        self.serdes = _coerce_serdes(serdes)
        self.auth_token = _coerce_auth_token(auth_token)
        self.callbacks = _callback_names(callbacks)
        self._conn_num = None
        self._conn_type = None
        self._stop_event = Event()
        # Serialises calls to ``stop()`` so concurrent callers (e.g. the
        # user thread + the disconnect watcher) cannot race on native
        # teardown — without it both threads could read ``_conn_num`` as
        # non-None and both call ``dfcore.stopClient`` (double-free).
        self._stop_lock = threading.RLock()
        # Serialises Client reconnect attempts (unused by Router / Service).
        self._reconnect_lock = threading.Lock()
        self._stopping = False
        self._connection_error: Optional[Exception] = None
        # Set to True by the background lifecycle watcher when an unexpected
        # disconnect or eviction is detected.  Cleared by a successful
        # reconnect.  Checked at the start of every RPC call so a clear,
        # actionable error (or a transparent reconnect) is surfaced instead of
        # a cryptic native-layer failure.
        self._disconnected: bool = False
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

        # Propagate Python's current log level to the native Zig layer so that
        # std.log.debug / .info / .warn calls in the extension respect whatever
        # level the caller configured (e.g. logging.basicConfig(level=DEBUG)).
        sync_native_log_level()

        set_signal_handler(self._signal_stop)

    def _signal_stop(self) -> None:
        """Stop on SIGINT / SIGTERM / interpreter exit."""
        self.stop()

    def _add_native_listeners(self) -> int:
        """Bind every transport at once and return the node's one conn_num.

        This only adds the listeners.  Accepting starts later, from
        ``dfcore.startServer``, after a Service has published its callbacks.
        All or nothing: if one cannot be bound, none stays bound, and the
        error names that transport.
        """
        listeners = [t.native_listener() for t in self._transports]
        try:
            return dfcore.addListeners(
                listeners,
                self.server_mode,
                self.app_name,
                self.auth_token,
            )
        except ValueError as exc:
            reason, *where = exc.args
            failed = self._transports[where[0]] if where else None
            with system_exception_handler(
                "{}",
                InitializationError,
                conn_info=failed.conn_info() if failed else (),
            ):
                raise ValueError(reason) from None

    def _exposed_names(self) -> "list[str]":
        """The registered callbacks this node offers (see ``callbacks=``)."""
        return [name for name, _ in EXECUTOR_REGISTRY if self.callbacks is None or name in self.callbacks]

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
                if self.callbacks is not None and executor.name not in self.callbacks:
                    return
                try:
                    if self.server_mode is None:
                        RpcProxy._process_client_handshake(self._conn_num, self._exposed_names())
                    elif self.server_mode == ServerMode.SERVICE:
                        RpcProxy._process_service_handshake(self._conn_num, self._exposed_names())
                    else:
                        return
                except Exception as exc:
                    # Raised at the user's @callback line otherwise.
                    if getattr(self, "_disconnected", False):
                        try:
                            EXECUTOR_REGISTRY.subscribers.remove(registry_subscriber)
                        except ValueError:
                            pass
                    else:
                        self.logger.warning(f"Could not announce {executor}: {exc}")
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

    def _wait_stopped(self) -> None:
        while not self._stop_event.wait(SIGNAL_POLL_S):
            pass

    def join(self):
        """Block the calling thread until :meth:`stop` is called (or until a
        registered signal handler triggers it).

        Works on every node type — :class:`Router`, :class:`Service`, and
        :class:`Client` alike.  This is the idiomatic way to keep a process
        alive without importing ``signal``::

            client = Client(app_name="worker", transport=TCPTransport("127.0.0.1", 6001))
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
            self._wait_stopped()
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
        delegated to TLS — set ``tls=True`` with ``cert`` / ``key`` on each
        listening :class:`~daffi.transports.TCPTransport`.

        All or nothing: if any step fails, every listener is closed, every
        peer that already connected is dropped, and the error is raised.

        Raises:
            RuntimeError: If the server is already started.
            InitializationError: If the native layer fails to bind.

        Example::

            router = Router(transport=TCPTransport("127.0.0.1", 6000))
            router.start()

            client = Client(transport=TCPTransport("127.0.0.1", 6000))
            conn = client.connect()
        """
        if self._conn_num is not None:
            raise RuntimeError(f"{self.__class__.__name__} is already started")
        # A server can start again after stop(); stop() must then work again.
        self._stop_event.clear()
        try:
            if self.server_mode == ServerMode.SERVICE:
                # Start the worker-thread pool before native I/O threads are
                # created.  Threads idle harmlessly until work arrives.
                if not self._task_dispatcher:
                    self._task_dispatcher = shared_dispatcher()
            self._conn_num = self._add_native_listeners()
            self.logger.debug(
                f"has been started successfully. connection info: {self.info}"
            )
            if self.server_mode == ServerMode.SERVICE:
                self._task_dispatcher.start_for_connection(self)
                # Before any socket accepts, so the first handshake already
                # carries the callback list.
                RpcProxy._advertise_service_methods(self._conn_num, self._exposed_names())
            dfcore.startServer(self._conn_num)
            self._register_executors()
            if self.server_mode == ServerMode.SERVICE:
                RpcProxy._process_service_handshake(self._conn_num, self._exposed_names())
        except BaseException:
            self._abort_start()
            raise

    def _abort_start(self) -> None:
        """Undo a :meth:`start` that failed part-way, so it can be retried.

        The dispatcher goes first, while ``_conn_num`` still names the
        lifecycle fd that wakes its poller; then the native server, which
        closes every listener and drops every peer on all of them.
        """
        dispatcher, self._task_dispatcher = self._task_dispatcher, None
        try:
            if dispatcher is not None:
                dispatcher.stop_for_connection(self)
        finally:
            if self._conn_num is not None:
                dfcore.stopServer(self._conn_num)
                self._conn_num = None
            self._unregister_executor_subscriber()

    def stop(self, *_, **__):
        """Stop the server and release the native connection.

        The task dispatcher is stopped **before** the native server is torn
        down, and while ``_conn_num`` is still set: ``stop_for_connection``
        uses it to find the lifecycle fd it must signal to wake the poller
        thread.  Clearing it first (as an earlier version did) made the signal
        go nowhere and ``stop()`` block forever joining the poller.
        """
        with self._stop_lock:
            if self._stopping or self._stop_event.is_set():
                return
            self._stopping = True
            try:
                conn_num = self._conn_num
                if self._task_dispatcher:
                    self._task_dispatcher.stop_for_connection(self)
                if conn_num is not None:
                    dfcore.stopServer(conn_num)
                    self._conn_num = None
            finally:
                self._stopping = False
                self._stop_event.set()


class Router(Application[MultipleTransportMixin], ServerMixin):
    """A routing server that forwards RPC calls between connected clients and
    services.

    The Router does not execute callbacks itself; it only routes messages based
    on the receiver name embedded in each request.

    Example::

        router = Router(
            transport=[
                TCPTransport(host="0.0.0.0", port=6001),
                UnixTransport(path="/tmp/daffi.sock"),
            ]
        )
        router.start()
        router.join()

    A single transport may be passed without a list.  Every transport of one
    Router or Service shares that node's membership.
    """

    server_mode = ServerMode.ROUTER


class Service(Application[MultipleTransportMixin], ServerMixin):
    """A server that exposes ``@callback``-decorated functions to remote callers.

    Example::

        from daffi import Service, callback

        @callback
        def add(a: int, b: int) -> int:
            return a + b

        svc = Service(transport=TCPTransport("127.0.0.1", 5000))
        svc.start()
        svc.join()
    """

    server_mode = ServerMode.SERVICE


class Client(Application[SingleTransportMixin]):
    """A client that connects to a :class:`Router` or :class:`Service` and
    issues RPC calls.

    Example::

        client = Client(app_name="my-client", transport=TCPTransport("127.0.0.1", 5000))
        conn = client.connect()
        result = conn.rpc(timeout=5).add(1, 2)
        client.stop()
    """

    @property
    def info(self) -> str:
        """Human-readable connection string (includes the connection type once
        the handshake has completed)."""
        described = self.transport.describe()
        type_part = (
            f", type: {self._conn_type!r}" if self._conn_type is not None else ""
        )
        return f"transport: {described}{type_part}"

    def connect(self) -> "ClientConnection":
        """Connect to the server, perform the handshake, and return a connection handle.

        Connection-level protection (encryption + peer authentication) is
        delegated to TLS — set ``tls=True`` (and optionally ``ca``) on the
        :class:`~daffi.transports.TCPTransport` to authenticate the server.

        Returns:
            A :class:`~daffi.rpc_proxy.ClientConnection`.

        Raises:
            RuntimeError: If the client is already connected.
            InitializationError: If the native layer cannot connect.
        """
        if self._conn_num is not None:
            raise RuntimeError("Client is already connected")
        # A client can connect again after stop().
        self._stop_event.clear()
        self._connection_error = None
        self._disconnected = False
        self._do_connect()
        return ClientConnection(self)

    def _do_connect(self) -> None:
        """Low-level connect: allocate native slot, handshake, start dispatcher.

        The TaskDispatcher is always created here regardless of ``workers``.
        Its poller thread monitors both task-arrival fds and the lifecycle fd
        so no separate watcher thread is needed.
        """
        # One shared poller for every client in this process. Callback
        # threads, if this client asked for them, start with the connection
        # and serve only this client.
        if self._task_dispatcher is None:
            self._task_dispatcher = shared_dispatcher()

        t = self.transport
        try:
            self._conn_num = dfcore.startClient(
                t.native_host,
                t.native_port,
                self.app_name,
                t.tls,
                t.ca,
                t.cert,
                t.key,
                t.verify,
                self.auth_token,
            )
        except Exception as exc:
            raise InitializationError(
                f"Failed to connect to the server: {exc}. connection info: {self.info}"
            ) from exc
        if self._conn_num is None:
            raise InitializationError(
                f"Failed to connect to the server. connection info: {self.info}"
            )
        try:
            handshake = RpcProxy._process_client_handshake(self._conn_num, self._exposed_names())
        except Exception as exc:
            # Tear the native slot down so the caller can retry connect()
            # without hitting the "already connected" guard.  Remap to
            # InitializationError so mTLS / TLS rejects look like a failed
            # connect (TLS 1.3 can let startClient succeed before the server
            # alert is visible).
            try:
                dfcore.stopClient(self._conn_num)
            except Exception:
                pass
            self._conn_num = None
            raise InitializationError(
                f"Failed to connect to the server: {exc}. connection info: {self.info}"
            ) from exc
        self._conn_type = handshake["meta"]["type"]
        self.logger.debug(
            f"has been connected successfully. connection info: {self.info}"
        )
        self._task_dispatcher.start_for_connection(self)
        self._register_executors()

    def _try_reconnect(self) -> bool:
        """Attempt one reconnection after a background disconnect.

        Thread-safe — :attr:`_reconnect_lock` prevents two threads from racing
        to reconnect at the same time.  The second thread to acquire the lock
        finds ``_disconnected`` already cleared and returns immediately.

        The dead connection is released first, then all internal state is
        reset so :meth:`_do_connect` starts from a clean slate.

        Returns:
            ``True`` when the reconnect succeeded, ``False`` otherwise.
        """
        with self._reconnect_lock:
            if not self._disconnected:
                # Another thread already reconnected while we were waiting.
                return self._conn_num is not None
            if isinstance(self._connection_error, Evicted):
                # The name now belongs to a newer connection.
                return False
            try:
                with self._stop_lock:
                    self._release_connection()
                self._stop_event.clear()
                self._connection_error = None
                self._disconnected = False
                self._do_connect()
                return True
            except Exception as exc:
                self.logger.warning(f"Reconnect attempt failed: {exc!r}")
                return False

    def join(self):
        """Block until stopped; attempt one reconnect on a background disconnect.

        Overrides :meth:`Application.join` so that an unexpected disconnect
        while this call is blocking triggers a single reconnection attempt
        instead of immediately surfacing the error.  On success the method
        returns normally — the caller may call :meth:`join` again to keep
        blocking or issue new RPC calls.  On failure the original disconnect
        error is re-raised.
        """
        self._joining = True
        try:
            self._wait_stopped()
        finally:
            self._joining = False

        if self._disconnected:
            err = self._connection_error
            self.logger.info(
                "Connection lost while joining; attempting one reconnect..."
            )
            if self._try_reconnect():
                return  # reconnected — caller can re-join or proceed
            if err is not None:
                raise err
            return

        if self._connection_error is not None:
            raise self._connection_error

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
            self._release_connection()
            self._stop_event.set()

    def _release_connection(self) -> None:
        """Detach from the dispatcher and free the native connection.

        Callers hold ``_stop_lock``.
        """
        if self._task_dispatcher:
            self._task_dispatcher.stop_for_connection(self)
        if self._conn_num is not None:
            dfcore.stopClient(self._conn_num)
            self._conn_num = None
