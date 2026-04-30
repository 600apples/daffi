"""
Async integration test: cast() result grows as async workers join dynamically.

Mirrors tests/integration/test_dynamic_cast.py using daffi.aio.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import time

import pytest

from .conftest import (
    HOST, TIMEOUT,
    wait_for_port, wait_for_members,
    silence_subprocess, quiet_kill, proc_router,
)


def _process_worker(port: int, worker_id: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def process(data):
            return {"result": data, "worker": worker_id}

        client = AsyncClient(
            app_name=f"dyn-aio-worker-{worker_id}",
            host=HOST,
            port=port,
        )
        await client.connect()
        await client.join()

    asyncio.run(_main())


@pytest.fixture
def router_only(free_port):
    proc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.1)
    yield free_port
    quiet_kill(proc)


@pytest.mark.asyncio
class TestDynamicCastAsync:

    async def test_cast_grows_as_workers_join(self, router_only):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="dyn-aio-caller", host=HOST, port=router_only)
        conn = await client.connect()
        worker_procs = []

        try:
            for i in range(3):
                proc = mp.Process(target=_process_worker, args=(router_only, i), daemon=True)
                proc.start()
                worker_procs.append(proc)

                # Wait until this worker is registered.
                await conn.wait_for_members(f"dyn-aio-worker-{i}", timeout=15)

                results = await conn.cast(timeout=TIMEOUT).process(f"data-{i}")
                assert len(results) == i + 1, (
                    f"After worker {i} joined, expected {i + 1} results, "
                    f"got {len(results)}: {list(results)}"
                )
                for name, val in results.items():
                    assert isinstance(val, dict)
                    assert val["result"] == f"data-{i}"
        finally:
            await client.stop()
            for p in worker_procs:
                quiet_kill(p)

    async def test_result_keys_are_worker_names(self, router_only):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="dyn-aio-names", host=HOST, port=router_only)
        conn = await client.connect()
        worker_procs = []

        try:
            for i in range(2):
                proc = mp.Process(target=_process_worker, args=(router_only, i), daemon=True)
                proc.start()
                worker_procs.append(proc)
            await conn.wait_for_members("dyn-aio-worker-0", "dyn-aio-worker-1", timeout=15)

            results = await conn.cast(timeout=TIMEOUT).process("name-check")
            assert set(results.keys()) == {"dyn-aio-worker-0", "dyn-aio-worker-1"}
        finally:
            await client.stop()
            for p in worker_procs:
                quiet_kill(p)
