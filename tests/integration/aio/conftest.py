"""
Shared helpers and fixtures for daffi.aio integration tests.

Mirrors ``tests/integration/conftest.py`` but uses the async interface:
  AsyncRouter / AsyncService / AsyncClient

Key differences from the sync conftest
---------------------------------------
* Subprocess targets call ``asyncio.run(_main())`` so each child has its own
  event loop.
* ``wait_for_members`` is both a sync helper (used during fixture setup, before
  asyncio.run is in play on the test-process side) and an async helper
  (``await_for_members``) for use inside ``async def`` test bodies.
* pytest-asyncio is used for async tests.  ``asyncio_mode = "auto"`` is
  configured in ``pytest.ini`` / ``pyproject.toml``; individual test files
  can also mark classes with ``@pytest.mark.asyncio``.
"""
from __future__ import annotations

import asyncio
import logging
import multiprocessing as mp
import os
import socket
import time

import pytest
import pytest_asyncio

mp.set_start_method("spawn", force=True)

HOST    = "127.0.0.1"
TIMEOUT = 30


# ── low-level helpers ─────────────────────────────────────────────────────────

def wait_for_port(port: int, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"Port {HOST}:{port} did not open within {timeout}s")


def wait_for_members(
    port: int,
    expected: set[str],
    *,
    timeout: float = 15.0,
    probe_name: str = "_aio-probe",
) -> None:
    """Sync helper: open a throw-away *sync* Client, wait until all *expected*
    members are registered, then disconnect.

    Used in fixture setup code that runs before any asyncio event loop is
    active on the test-process side.
    """
    from daffi import Client
    client = Client(app_name=probe_name, host=HOST, port=port)
    conn = client.connect()
    try:
        conn.wait_for_members(*expected, timeout=timeout)
    finally:
        client.stop()


async def async_wait_for_members(
    port: int,
    expected: set[str],
    *,
    timeout: float = 15.0,
    probe_name: str = "_aio-aprobe",
) -> None:
    """Async helper: open a throw-away AsyncClient inside an async test body."""
    from daffi.aio import AsyncClient
    client = AsyncClient(app_name=probe_name, host=HOST, port=port)
    conn = await client.connect()
    try:
        await conn.wait_for_members(*expected, timeout=timeout)
    finally:
        await client.stop()


def silence_subprocess() -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)

    from daffi.registry._executor_registry import EXECUTOR_REGISTRY
    EXECUTOR_REGISTRY.subscribers.clear()
    EXECUTOR_REGISTRY.registry.clear()


def quiet_kill(proc: mp.Process, timeout: float = 5.0) -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved = (os.dup(1), os.dup(2))
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    try:
        proc.terminate()
    finally:
        os.dup2(saved[0], 1)
        os.dup2(saved[1], 2)
        os.close(saved[0])
        os.close(saved[1])
    proc.join(timeout=timeout)


# ── common subprocess entry points ────────────────────────────────────────────

def proc_service(port: int, app_name: str = "integ-aio-service", workers: int = 4) -> None:
    """AsyncService subprocess: registers async echo + add callbacks, then joins."""
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        @callback
        async def echo(payload):
            return payload

        @callback
        async def add(a: int, b: int) -> int:
            return a + b

        svc = AsyncService(app_name=app_name, host=HOST, port=port, workers=workers)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def proc_router(port: int, app_name: str = "integ-aio-router") -> None:
    """AsyncRouter subprocess: pure message broker."""
    silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter

        r = AsyncRouter(app_name=app_name, host=HOST, port=port)
        await r.start()
        await r.join()

    asyncio.run(_main())


def proc_worker(port: int, app_name: str, workers: int = 4) -> None:
    """AsyncClient+callback worker subprocess: registers echo + add, keeps running."""
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def echo(payload):
            return payload

        @callback
        async def add(a: int, b: int) -> int:
            return a + b

        client = AsyncClient(app_name=app_name, host=HOST, port=port, workers=workers)
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── pytest fixtures ───────────────────────────────────────────────────────────

@pytest.fixture
def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, 0))
        return s.getsockname()[1]


@pytest.fixture
def direct_service(free_port):
    """Start an AsyncService subprocess; yield its port; terminate on teardown."""
    proc = mp.Process(target=proc_service, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"integ-aio-service"})
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def router_with_worker(free_port):
    """Start AsyncRouter + one AsyncWorker subprocess; yield the router port."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(
        target=proc_worker, args=(free_port, "integ-aio-worker"), daemon=True
    )
    wproc.start()
    wait_for_members(free_port, {"integ-aio-worker"})
    yield free_port
    quiet_kill(wproc)
    quiet_kill(rproc)
