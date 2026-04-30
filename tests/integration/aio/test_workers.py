"""
Async integration tests for the asyncio-worker execution mode.

Mirrors tests/integration/test_workers.py using daffi.aio.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp

import pytest

from .conftest import (
    HOST, TIMEOUT,
    wait_for_port, wait_for_members,
    silence_subprocess, quiet_kill, proc_router,
)

N_CONCURRENT     = 30
CALLS_PER_TASK   = 10


# ── subprocess entry points ───────────────────────────────────────────────────

def _svc_task_workers(port: int, n_workers: int) -> None:
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

        @callback
        async def cpu_work(n: int) -> int:
            # Pure Python computation — no await needed
            return sum(i * i for i in range(n))

        @callback
        async def raises_value_error(msg: str):
            raise ValueError(msg)

        svc = AsyncService(
            app_name="workers-aio-svc", host=HOST, port=port, workers=n_workers
        )
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _client_task_workers(port: int, n_workers: int) -> None:
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

        @callback
        async def cpu_work(n: int) -> int:
            return sum(i * i for i in range(n))

        @callback
        async def raises_value_error(msg: str):
            raise ValueError(msg)

        client = AsyncClient(
            app_name="workers-aio-worker", host=HOST, port=port, workers=n_workers
        )
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(params=[1, 4, 16])
def direct_svc_workers(request, free_port):
    n = request.param
    proc = mp.Process(target=_svc_task_workers, args=(free_port, n), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"workers-aio-svc"})
    yield free_port, n
    quiet_kill(proc)


@pytest.fixture(params=[1, 4, 16])
def router_client_workers(request, free_port):
    n = request.param
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(target=_client_task_workers, args=(free_port, n), daemon=True)
    wproc.start()
    wait_for_members(free_port, {"workers-aio-worker"})
    yield free_port, n
    quiet_kill(wproc)
    quiet_kill(rproc)


# ── Direct layout tests ────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestDirectWorkersAsync:

    async def test_echo_correct(self, direct_svc_workers):
        from daffi.aio import AsyncClient
        port, _ = direct_svc_workers
        client = AsyncClient(app_name="w-echo", host=HOST, port=port)
        conn = await client.connect()
        try:
            assert await conn.rpc(timeout=TIMEOUT).echo("hello workers") == "hello workers"
        finally:
            await client.stop()

    async def test_add_correct(self, direct_svc_workers):
        from daffi.aio import AsyncClient
        port, _ = direct_svc_workers
        client = AsyncClient(app_name="w-add", host=HOST, port=port)
        conn = await client.connect()
        try:
            assert await conn.rpc(timeout=TIMEOUT).add(21, 21) == 42
        finally:
            await client.stop()

    async def test_cpu_work_correct(self, direct_svc_workers):
        from daffi.aio import AsyncClient
        port, _ = direct_svc_workers
        client = AsyncClient(app_name="w-cpu", host=HOST, port=port)
        conn = await client.connect()
        expected = sum(i * i for i in range(100))
        try:
            assert await conn.rpc(timeout=TIMEOUT).cpu_work(100) == expected
        finally:
            await client.stop()

    async def test_concurrent_echo(self, direct_svc_workers):
        from daffi.aio import AsyncClient
        port, n_workers = direct_svc_workers

        clients = [
            AsyncClient(app_name=f"w-conc-{i}", host=HOST, port=port)
            for i in range(N_CONCURRENT)
        ]
        conns = await asyncio.gather(*[c.connect() for c in clients])

        async def _task(conn, idx):
            proxy = conn.rpc(timeout=TIMEOUT)
            for i in range(CALLS_PER_TASK):
                res = await proxy.echo(f"{idx}-{i}")
                assert res == f"{idx}-{i}"

        try:
            await asyncio.gather(*[_task(conn, i) for i, conn in enumerate(conns)])
        finally:
            await asyncio.gather(*[c.stop() for c in clients], return_exceptions=True)

    async def test_exception_propagates(self, direct_svc_workers):
        from daffi.aio import AsyncClient
        from daffi.exceptions import RemoteCallError
        port, _ = direct_svc_workers
        client = AsyncClient(app_name="w-exc", host=HOST, port=port)
        conn = await client.connect()
        try:
            with pytest.raises((RemoteCallError, ValueError)):
                await conn.rpc(timeout=TIMEOUT).raises_value_error("boom")
        finally:
            await client.stop()


# ── Router layout tests ────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestRouterWorkersAsync:

    async def test_echo_correct(self, router_client_workers):
        from daffi.aio import AsyncClient
        port, _ = router_client_workers
        client = AsyncClient(app_name="rw-echo", host=HOST, port=port)
        conn = await client.connect()
        try:
            assert await conn.rpc(timeout=TIMEOUT).echo("routed hello") == "routed hello"
        finally:
            await client.stop()

    async def test_add_correct(self, router_client_workers):
        from daffi.aio import AsyncClient
        port, _ = router_client_workers
        client = AsyncClient(app_name="rw-add", host=HOST, port=port)
        conn = await client.connect()
        try:
            assert await conn.rpc(timeout=TIMEOUT).add(6, 7) == 13
        finally:
            await client.stop()

    async def test_concurrent_echo(self, router_client_workers):
        from daffi.aio import AsyncClient
        port, _ = router_client_workers

        clients = [
            AsyncClient(app_name=f"rw-conc-{i}", host=HOST, port=port)
            for i in range(N_CONCURRENT)
        ]
        conns = await asyncio.gather(*[c.connect() for c in clients])

        async def _task(conn, idx):
            proxy = conn.rpc(timeout=TIMEOUT)
            for i in range(CALLS_PER_TASK):
                res = await proxy.echo(f"r-{idx}-{i}")
                assert res == f"r-{idx}-{i}"

        try:
            await asyncio.gather(*[_task(conn, i) for i, conn in enumerate(conns)])
        finally:
            await asyncio.gather(*[c.stop() for c in clients], return_exceptions=True)

    async def test_exception_propagates(self, router_client_workers):
        from daffi.aio import AsyncClient
        from daffi.exceptions import RemoteCallError
        port, _ = router_client_workers
        client = AsyncClient(app_name="rw-exc", host=HOST, port=port)
        conn = await client.connect()
        try:
            with pytest.raises((RemoteCallError, ValueError)):
                await conn.rpc(timeout=TIMEOUT).raises_value_error("router boom")
        finally:
            await client.stop()
