"""
Unix-domain-socket transport tests.

Regressions covered:
* ``unix_sock_path`` was never forwarded to the native layer (``host``/``port``
  were passed as ``None``), so every Unix-socket Service/Client failed to start.
* The native ``Address`` buffer was 28 bytes (a ``sockaddr_in6``), truncating
  any socket path longer than ~26 characters and reading past the buffer.
* A host that is really a path must not be sent through the DNS resolver.
"""

from __future__ import annotations

import asyncio
import multiprocessing as mp
import os
import sys
import time

import pytest

from .conftest import quiet_kill, silence_subprocess

pytestmark = pytest.mark.skipif(
    sys.platform == "win32", reason="no Unix sockets on Windows"
)


def _service(path: str) -> None:
    silence_subprocess()
    from daffi import Service, callback, UnixTransport, TCPTransport

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    svc = Service(app_name="ux-service", workers=2, transports=UnixTransport(path))
    svc.start()
    svc.join()


def _router(path: str) -> None:
    silence_subprocess()
    from daffi import Router, UnixTransport, TCPTransport

    r = Router(app_name="ux-router", transports=UnixTransport(path))
    r.start()
    r.join()


def _worker(path: str) -> None:
    silence_subprocess()
    from daffi import Client, callback, UnixTransport, TCPTransport

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    c = Client(app_name="ux-service", workers=2, transport=UnixTransport(path))
    c.connect()
    while True:
        time.sleep(1)


def _wait_for_socket(path: str, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if os.path.exists(path):
            return
        time.sleep(0.05)
    raise TimeoutError(f"{path} was not created")


def _sock_path(tmp_path, *, long: bool = False) -> str:
    # macOS limits sun_path to 104 bytes, Linux to 108; pytest's tmp_path can
    # already be long, so build the deep path under a short temp dir.
    base = os.path.join("/tmp", f"dfx{os.getpid()}-{time.monotonic_ns() % 10**8}")
    os.makedirs(base, exist_ok=True)
    name = ("a-rather-long-socket-file-name-" * 2 + ".sock") if long else "s.sock"
    path = os.path.join(base, name)
    assert len(path) < 100
    return path


@pytest.fixture
def unix_service(tmp_path, request):
    path = _sock_path(tmp_path, long=getattr(request, "param", False))
    proc = mp.Process(target=_service, args=(path,), daemon=True)
    proc.start()
    _wait_for_socket(path)
    yield path
    quiet_kill(proc)


@pytest.mark.parametrize(
    "unix_service", [False, True], indirect=True, ids=["short-path", "long-path"]
)
def test_rpc_over_unix_socket(unix_service):
    from daffi import Client, UnixTransport, TCPTransport

    assert unix_service.count("/") >= 2
    client = Client(app_name="ux-client", transport=UnixTransport(unix_service))
    conn = client.connect()
    try:
        conn.wait_for_members("ux-service", timeout=15)
        rpc = conn.rpc(timeout=15)
        assert rpc.add(20, 22) == 42
        blob = b"u" * (2 * 1024 * 1024)
        assert rpc.echo(blob) == blob
    finally:
        client.stop()


def test_router_over_unix_socket(tmp_path):
    from daffi import Client, UnixTransport, TCPTransport

    path = _sock_path(tmp_path, long=True)
    rproc = mp.Process(target=_router, args=(path,), daemon=True)
    rproc.start()
    _wait_for_socket(path)
    wproc = mp.Process(target=_worker, args=(path,), daemon=True)
    wproc.start()
    try:
        client = Client(app_name="ux-client", transport=UnixTransport(path))
        conn = client.connect()
        try:
            conn.wait_for_members("ux-service", timeout=20)
            assert conn.rpc(timeout=15).add(1, 2) == 3
        finally:
            client.stop()
    finally:
        quiet_kill(wproc)
        quiet_kill(rproc)


def test_async_client_over_unix_socket(unix_service):
    from daffi.aio import AsyncClient
    from daffi import UnixTransport

    async def main():
        client = AsyncClient(
            app_name="ux-aclient", transport=UnixTransport(unix_service)
        )
        conn = await client.connect()
        try:
            await conn.wait_for_members("ux-service", timeout=15)
            assert await conn.rpc(timeout=15).add(3, 4) == 7
        finally:
            await client.stop()

    asyncio.run(main())


def test_stale_socket_file_is_replaced(tmp_path):
    from daffi import Client, UnixTransport, TCPTransport

    path = _sock_path(tmp_path)
    open(path, "w").close()  # leftover from a crashed run
    proc = mp.Process(target=_service, args=(path,), daemon=True)
    proc.start()
    try:
        deadline = time.monotonic() + 15
        import stat

        while time.monotonic() < deadline and not stat.S_ISSOCK(os.stat(path).st_mode):
            time.sleep(0.05)
        assert stat.S_ISSOCK(
            os.stat(path).st_mode
        ), "stale file was not replaced by a socket"
        client = Client(app_name="ux-client", transport=UnixTransport(path))
        conn = client.connect()
        try:
            conn.wait_for_members("ux-service", timeout=15)
        finally:
            client.stop()
    finally:
        quiet_kill(proc)


def test_missing_transport_is_rejected():
    from daffi import Client

    with pytest.raises(TypeError):
        Client(app_name="bad")
