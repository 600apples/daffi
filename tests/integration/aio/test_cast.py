"""
Async integration tests for cast() — async fan-out broadcast.

Mirrors tests/integration/test_cast.py using daffi.aio.

Layout: AsyncClient → AsyncRouter → N AsyncWorkers
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import time

import pytest

from .conftest import (
    HOST, TIMEOUT, wait_for_port, wait_for_members,
    silence_subprocess, quiet_kill, proc_router,
)

N_WORKERS = 5


# ── subprocess entry points ───────────────────────────────────────────────────

def _worker(port: int, worker_id: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def echo(payload):
            return payload

        @callback
        async def identity(value: int) -> int:
            return value

        client = AsyncClient(
            app_name=f"cast-worker-{worker_id:02d}",
            host=HOST,
            port=port,
        )
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def cast_setup(free_port):
    """Start AsyncRouter + N_WORKERS AsyncWorker subprocesses; yield the router port."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    worker_procs = []
    for i in range(N_WORKERS):
        p = mp.Process(target=_worker, args=(free_port, i), daemon=True)
        p.start()
        worker_procs.append(p)

    expected = {f"cast-worker-{i:02d}" for i in range(N_WORKERS)}
    wait_for_members(free_port, expected, timeout=15.0, probe_name="cast-setup-aio-probe")

    yield free_port

    for p in worker_procs:
        quiet_kill(p)
    quiet_kill(rproc)


# ── tests ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestCastBroadcastAsync:
    """await conn.cast() fan-out tests via AsyncRouter → N AsyncWorkers."""

    async def _connect(self, port: int, name: str):
        from daffi.aio import AsyncClient
        client = AsyncClient(app_name=name, host=HOST, port=port)
        conn = await client.connect()
        return client, conn

    async def test_cast_reaches_all_workers(self, cast_setup):
        client, conn = await self._connect(cast_setup, "cast-caller-reach")
        try:
            results = await conn.cast(timeout=TIMEOUT).echo("ping")
            assert isinstance(results, dict)
            assert len(results) == N_WORKERS
        finally:
            await client.stop()

    async def test_cast_all_values_correct(self, cast_setup):
        client, conn = await self._connect(cast_setup, "cast-caller-values")
        payload = {"test": "async-broadcast", "numbers": [1, 2, 3]}
        try:
            results = await conn.cast(timeout=TIMEOUT).echo(payload)
            assert all(v == payload for v in results.values())
        finally:
            await client.stop()

    async def test_cast_worker_names_in_result(self, cast_setup):
        client, conn = await self._connect(cast_setup, "cast-caller-names")
        try:
            results = await conn.cast(timeout=TIMEOUT).echo("name-check")
            expected_names = {f"cast-worker-{i:02d}" for i in range(N_WORKERS)}
            assert set(results.keys()) == expected_names
        finally:
            await client.stop()

    async def test_cast_identity_int(self, cast_setup):
        client, conn = await self._connect(cast_setup, "cast-caller-int")
        try:
            results = await conn.cast(timeout=TIMEOUT).identity(99)
            assert all(v == 99 for v in results.values())
        finally:
            await client.stop()

    async def test_cast_string_payload(self, cast_setup):
        client, conn = await self._connect(cast_setup, "cast-caller-str")
        try:
            results = await conn.cast(timeout=TIMEOUT).echo("hello async broadcast")
            assert len(results) == N_WORKERS
            assert all(v == "hello async broadcast" for v in results.values())
        finally:
            await client.stop()

    async def test_cast_large_payload(self, cast_setup):
        client, conn = await self._connect(cast_setup, "cast-caller-large")
        payload = list(range(5_000))
        try:
            results = await conn.cast(timeout=TIMEOUT).echo(payload)
            assert len(results) == N_WORKERS
            assert all(v == payload for v in results.values())
        finally:
            await client.stop()

    async def test_cast_multiple_sequential_calls(self, cast_setup):
        client, conn = await self._connect(cast_setup, "cast-caller-seq")
        try:
            for i in range(5):
                results = await conn.cast(timeout=TIMEOUT).echo(i)
                assert len(results) == N_WORKERS
                assert all(v == i for v in results.values())
        finally:
            await client.stop()

    async def test_cast_nowait_does_not_raise(self, cast_setup):
        """cast_nowait() sends fire-and-forget; no response is awaited server-side."""
        client, conn = await self._connect(cast_setup, "cast-caller-nowait")
        try:
            await conn.cast_nowait().echo("fire-and-forget")
            await asyncio.sleep(0.1)
        finally:
            await client.stop()

    async def test_cast_targeted_single_worker(self, cast_setup):
        """cast(receiver=name) targets only one specific worker."""
        target = "cast-worker-00"
        client, conn = await self._connect(cast_setup, "cast-caller-targeted")
        try:
            results = await conn.cast(timeout=TIMEOUT, receiver=target).echo("targeted")
            assert set(results.keys()) == {target}
            assert results[target] == "targeted"
        finally:
            await client.stop()

    async def test_concurrent_casts_via_gather(self, cast_setup):
        """Multiple casts fired simultaneously with asyncio.gather all succeed."""
        clients = []
        try:
            conns = []
            for i in range(5):
                client = __import__("daffi.aio", fromlist=["AsyncClient"]).AsyncClient(
                    app_name=f"cast-gather-{i}", host=HOST, port=cast_setup
                )
                conn = await client.connect()
                clients.append(client)
                conns.append(conn)

            results_list = await asyncio.gather(*[
                conn.cast(timeout=TIMEOUT).echo(i)
                for i, conn in enumerate(conns)
            ])
            for i, results in enumerate(results_list):
                assert len(results) == N_WORKERS
                assert all(v == i for v in results.values())
        finally:
            await asyncio.gather(*[c.stop() for c in clients], return_exceptions=True)
