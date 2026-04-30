"""
Async application classes: Router, Service, and Client.

Usage::

    from daffi.aio import Client, Service, Router

    async def main():
        client = Client(app_name="caller", host="127.0.0.1", port=6000)
        conn = await client.connect()

        result = await conn.rpc(timeout=5).multiply(6, 7)

        await client.stop()

These classes inherit all constructor arguments, the logger, app_name
generation, transport selection, and event-handler registration from the
sync :class:`~daffi.app.Application` base.  Only the threading primitives
and the async lifecycle methods (``connect``, ``join``,
``stop``) are overridden.
"""

from __future__ import annotations

import asyncio

from .. import dfcore

from daffi.app import Application, ServerMode
from daffi.exceptions import InitializationError
from daffi._bindings import set_lifecycle_fd, set_response_fd
from daffi._rpc_proxy import RpcProxy, system_exception_handler
from daffi._signals import set_signal_handler

from daffi.aio._rpc_proxy import (
    AsyncRpcProxy,
    AsyncClientConnection,
    AsyncResponseNotifier,
)
from daffi.aio._task_dispatcher import AsyncTaskDispatcher


# ---------------------------------------------------------------------------
# AsyncApplication — base with asyncio primitives
# ---------------------------------------------------------------------------

class AsyncApplication(Application):
    """Base for async Router, Service, and Client.

    Inherits all non-threading logic from :class:`~daffi.app.Application`
    (name, logger, transport config, event-handler registration) and replaces
    the threading primitives with their ``asyncio`` counterparts.
    """

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        # Replace threading.Event / threading.Lock with asyncio equivalents.
        self._stop_event: asyncio.Event = asyncio.Event()
        self._stop_lock: asyncio.Lock = asyncio.Lock()
        # Application.__init__ registered `self.stop` (the sync method) via
        # atexit/signal.  Remove it and replace with a sync wrapper that
        # safely schedules stop() on the event loop.
        import atexit as _atexit
        _atexit.unregister(self.stop)
        set_signal_handler(self._sync_signal_stop)

    def _sync_signal_stop(self, *_args, **_kwargs) -> None:
        """Sync signal handler — schedules ``stop()`` on the event loop."""
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(self.stop())
        except RuntimeError:
            pass

    async def join(self) -> None:
        """Block until :meth:`stop` is called or a signal fires."""
        self._joining = True
        try:
            await self._stop_event.wait()
        finally:
            self._joining = False
        if self._connection_error is not None:
            raise self._connection_error

    async def stop(self, *args, **kwargs) -> None:
        """Abstract async teardown — subclasses implement the actual logic."""
        self._unregister_executor_subscriber()


# ---------------------------------------------------------------------------
# AsyncServerMixin — async start / stop for Router and Service
# ---------------------------------------------------------------------------

class AsyncServerMixin:
    """Async counterpart of :class:`~daffi.app.ServerMixin`."""

    async def start(self) -> None:
        """Bind the server, register executors, launch the dispatcher."""
        if self._conn_num is not None:
            raise RuntimeError(f"{self.__class__.__name__} is already started")
        if self.server_mode == ServerMode.SERVICE:
            if not self._task_dispatcher:
                self._task_dispatcher = AsyncTaskDispatcher(workers=self.workers)
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

    async def stop(self, *_, **__) -> None:
        """Stop the server and release resources."""
        self._unregister_executor_subscriber()
        if not self._stop_event.is_set():
            if self._conn_num is not None:
                dfcore.stopServer(self._conn_num)
                self._conn_num = None
        self._stop_event.set()
        if self._task_dispatcher:
            await self._task_dispatcher.stop_for_connection(self)


# ---------------------------------------------------------------------------
# AsyncRouter
# ---------------------------------------------------------------------------

class AsyncRouter(AsyncApplication, AsyncServerMixin):
    """Async routing server.

    Example::

        async def main():
            router = Router(host="127.0.0.1", port=6000)
            await router.start()
            await router.join()
    """

    server_mode = ServerMode.ROUTER


# ---------------------------------------------------------------------------
# AsyncService
# ---------------------------------------------------------------------------

class AsyncService(AsyncApplication, AsyncServerMixin):
    """Async service that exposes ``@callback`` functions.

    Example::

        from daffi import callback
        from daffi.aio import Service

        @callback
        async def add(a: int, b: int) -> int:
            return a + b

        async def main():
            svc = Service(host="127.0.0.1", port=5000)
            await svc.start()
            await svc.join()
    """

    server_mode = ServerMode.SERVICE


# ---------------------------------------------------------------------------
# AsyncClient
# ---------------------------------------------------------------------------

class AsyncClient(AsyncApplication):
    """Async client that connects to a Router or Service.

    Example::

        async def main():
            client = Client(app_name="caller", host="127.0.0.1", port=6000)
            conn = await client.connect()

            result = await conn.rpc(timeout=5).multiply(6, 7)
            await conn.wait_for_members("worker")

            await client.stop()
    """

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._reconnect_lock: asyncio.Lock = asyncio.Lock()

    # ------------------------------------------------------------------
    # Public lifecycle
    # ------------------------------------------------------------------

    async def connect(self) -> AsyncClientConnection:
        """Connect to the server and return an :class:`AsyncClientConnection`.

        Raises:
            RuntimeError: If already connected.
            InitializationError: If the native layer cannot connect.
        """
        if self._conn_num is not None:
            raise RuntimeError("Client is already connected")
        await self._do_connect()
        return AsyncClientConnection(self)

    async def join(self) -> None:
        """Block until stopped; attempt one reconnect on a background disconnect.

        On success returns normally — call :meth:`join` again to keep
        blocking.  On failure re-raises the original disconnect error.
        """
        self._joining = True
        try:
            await self._stop_event.wait()
        finally:
            self._joining = False

        if self._disconnected:
            err = self._connection_error
            self.logger.info(
                "Connection lost while joining; attempting one reconnect..."
            )
            if await self._try_reconnect():
                return
            if err is not None:
                raise err
            return

        if self._connection_error is not None:
            raise self._connection_error

    async def stop(self, *_, **__) -> None:
        """Stop the client: cancel the dispatcher tasks, then destroy the
        native connection.

        Idempotent and safe to call from multiple coroutines concurrently.
        """
        self._unregister_executor_subscriber()
        async with self._stop_lock:
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
                await self._task_dispatcher.stop_for_connection(self)
            if self._conn_num is not None:
                AsyncResponseNotifier.unregister(self._conn_num)
                dfcore.stopClient(self._conn_num)
                self._conn_num = None
            self._stop_event.set()

    # ------------------------------------------------------------------
    # Internal connect / reconnect
    # ------------------------------------------------------------------

    async def _do_connect(self) -> None:
        """Low-level async connect: native slot → notifier → handshake →
        dispatcher → executors."""
        if self._task_dispatcher is None:
            self._task_dispatcher = AsyncTaskDispatcher(workers=self.workers)
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

        # Register the async notifier BEFORE the handshake so the handshake's
        # own RpcResult benefits from event-driven wakeups.
        AsyncResponseNotifier.register(self._conn_num)

        try:
            # The handshake uses the sync RpcResult internally but runs in a
            # thread-pool executor so it does not block the event loop.
            # AsyncResponseNotifier's add_reader fires when Zig sends the
            # handshake response — the executor thread sees it via its own
            # select.select on the same fd.
            loop = asyncio.get_running_loop()
            handshake = await loop.run_in_executor(
                None, AsyncRpcProxy._process_client_handshake, self._conn_num
            )
        except Exception:
            AsyncResponseNotifier.unregister(self._conn_num)
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
        # The sync handshake (run in executor) creates its own ResponseNotifier
        # which calls set_response_fd(), overwriting ours.  Re-point the native
        # layer at our async notifier's fd so RPC responses wake the event loop.
        notifier = AsyncResponseNotifier.for_conn(self._conn_num)
        if notifier is not None:
            set_response_fd(self._conn_num, notifier._wakeup.write_fd)
        self._task_dispatcher.start_for_connection(self)
        self._register_executors()

    async def _try_reconnect(self) -> bool:
        """Attempt one reconnection after a background disconnect.

        Thread-safe — a lock prevents concurrent reconnect races.
        Returns ``True`` on success, ``False`` otherwise.
        """
        async with self._reconnect_lock:
            if not self._disconnected:
                return self._conn_num is not None
            try:
                self._stop_event.clear()
                self._connection_error = None
                self._disconnected = False
                self._task_dispatcher = None  # force a fresh dispatcher + poller
                await self._do_connect()
                return True
            except Exception as exc:
                self.logger.warning(f"Reconnect attempt failed: {exc!r}")
                return False
