"""
Async integration tests for concurrent client access.

Mirrors tests/integration/test_concurrency.py using daffi.aio.
Uses asyncio.gather instead of threading.Thread — all callers share one event loop.

Scenarios
---------
1. Many async tasks share ONE AsyncClient connection, fire rpc() simultaneously.
2. Many independent AsyncClient connections fire rpc() simultaneously.
3. Same two scenarios via AsyncRouter (two-hop path).
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp

import pytest

from .conftest import (
    HOST, TIMEOUT,
    wait_for_port, wait_for_members,
    silence_subprocess, quiet_kill,
)

N_TASKS          = 50
CALLS_PER_TASK   = 20


# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_service(port: int) -> None:
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

        svc = AsyncService(app_name="conc-aio-service", host=HOST, port=port, workers=16)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_router(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter

        r = AsyncRouter(app_name="conc-aio-router", host=HOST, port=port)
        await r.start()
        await r.join()

    asyncio.run(_main())


def _proc_worker(port: int) -> None:
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

        client = AsyncClient(app_name="conc-aio-worker", host=HOST, port=port, workers=16)
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def direct_svc(free_port):
    proc = mp.Process(target=_proc_service, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"conc-aio-service"})
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def router_worker(free_port):
    rproc = mp.Process(target=_proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(target=_proc_worker, args=(free_port,), daemon=True)
    wproc.start()
    wait_for_members(free_port, {"conc-aio-worker"})
    yield free_port
    quiet_kill(wproc)
    quiet_kill(rproc)


# ── tests ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestSharedConnectionDirectAsync:
    """Many async tasks sharing ONE AsyncClient connection → AsyncService."""

    async def test_concurrent_echo_shared_conn(self, direct_svc):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="conc-shared-direct", host=HOST, port=direct_svc)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)

        async def _task(idx: int):
            for i in range(CALLS_PER_TASK):
                result = await proxy.echo(f"{idx}-{i}")
                assert result == f"{idx}-{i}"

        try:
            await asyncio.gather(*[_task(i) for i in range(N_TASKS)])
        finally:
            await client.stop()

    async def test_concurrent_add_shared_conn(self, direct_svc):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="conc-add-direct", host=HOST, port=direct_svc)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)

        async def _task(a: int, b: int):
            return await proxy.add(a, b)

        try:
            pairs = [(i, i * 2) for i in range(N_TASKS)]
            results = await asyncio.gather(*[_task(a, b) for a, b in pairs])
            for result, (a, b) in zip(results, pairs):
                assert result == a + b
        finally:
            await client.stop()


@pytest.mark.asyncio
class TestIndependentConnectionsDirectAsync:
    """Many independent AsyncClient connections → AsyncService."""

    async def test_concurrent_independent_echo(self, direct_svc):
        from daffi.aio import AsyncClient

        clients = [
            AsyncClient(app_name=f"conc-ind-{i}", host=HOST, port=direct_svc)
            for i in range(N_TASKS)
        ]
        conns = await asyncio.gather(*[c.connect() for c in clients])

        async def _task(conn, idx):
            proxy = conn.rpc(timeout=TIMEOUT)
            for i in range(CALLS_PER_TASK):
                result = await proxy.echo(f"{idx}-{i}")
                assert result == f"{idx}-{i}"

        try:
            await asyncio.gather(*[_task(conn, i) for i, conn in enumerate(conns)])
        finally:
            await asyncio.gather(*[c.stop() for c in clients], return_exceptions=True)


@pytest.mark.asyncio
class TestSharedConnectionRouterAsync:
    """Many async tasks sharing ONE AsyncClient connection → AsyncRouter → Worker."""

    async def test_concurrent_echo_shared_conn(self, router_worker):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="conc-shared-router", host=HOST, port=router_worker)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)

        async def _task(idx: int):
            for i in range(CALLS_PER_TASK):
                result = await proxy.echo(f"r-{idx}-{i}")
                assert result == f"r-{idx}-{i}"

        try:
            await asyncio.gather(*[_task(i) for i in range(N_TASKS)])
        finally:
            await client.stop()

    async def test_concurrent_add_shared_conn(self, router_worker):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="conc-add-router", host=HOST, port=router_worker)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)

        async def _task(a, b):
            return await proxy.add(a, b)

        try:
            pairs = [(i, i + 1) for i in range(N_TASKS)]
            results = await asyncio.gather(*[_task(a, b) for a, b in pairs])
            for result, (a, b) in zip(results, pairs):
                assert result == a + b
        finally:
            await client.stop()


@pytest.mark.asyncio
class TestIndependentConnectionsRouterAsync:
    """Many independent AsyncClient connections → AsyncRouter → Worker."""

    async def test_concurrent_independent_echo(self, router_worker):
        from daffi.aio import AsyncClient

        clients = [
            AsyncClient(app_name=f"conc-rind-{i}", host=HOST, port=router_worker)
            for i in range(N_TASKS)
        ]
        conns = await asyncio.gather(*[c.connect() for c in clients])

        async def _task(conn, idx):
            proxy = conn.rpc(timeout=TIMEOUT)
            for i in range(CALLS_PER_TASK):
                result = await proxy.echo(f"r-{idx}-{i}")
                assert result == f"r-{idx}-{i}"

        try:
            await asyncio.gather(*[_task(conn, i) for i, conn in enumerate(conns)])
        finally:
            await asyncio.gather(*[c.stop() for c in clients], return_exceptions=True)
