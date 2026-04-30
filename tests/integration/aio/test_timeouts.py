"""
Async integration tests for timeout behaviour.

Mirrors tests/integration/test_timeouts.py using daffi.aio.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import time

import pytest

from .conftest import (
    HOST, TIMEOUT,
    wait_for_port, wait_for_members, silence_subprocess, quiet_kill,
    proc_router,
)

SLOW_SECS = 3.0
SHORT_TO  = 1
N_WORKERS = 3


# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_slow_service(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        @callback
        async def slow(payload):
            await asyncio.sleep(SLOW_SECS)
            return payload

        @callback
        async def fast(payload):
            return payload

        svc = AsyncService(app_name="timeout-aio-svc", host=HOST, port=port, workers=4)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_router_only(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter

        r = AsyncRouter(app_name="timeout-aio-router-only", host=HOST, port=port)
        await r.start()
        await r.join()

    asyncio.run(_main())


def _proc_fast_worker(port: int, worker_id: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def work(payload):
            return payload

        client = AsyncClient(
            app_name=f"timeout-aio-fast-{worker_id:02d}", host=HOST, port=port
        )
        await client.connect()
        await client.join()

    asyncio.run(_main())


def _proc_slow_worker(port: int, worker_id: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def work(payload):
            await asyncio.sleep(SLOW_SECS)
            return payload

        client = AsyncClient(
            app_name=f"timeout-aio-slow-{worker_id:02d}", host=HOST, port=port
        )
        await client.connect()
        await client.join()

    asyncio.run(_main())


def _proc_all_slow_workers(port: int, n: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def work(payload):
            await asyncio.sleep(SLOW_SECS)
            return payload

        clients = []
        for i in range(n):
            c = AsyncClient(
                app_name=f"timeout-aio-allslow-{i:02d}", host=HOST, port=port
            )
            await c.connect()
            clients.append(c)

        # Wait until first client's join returns (on stop signal)
        await clients[0].join()
        for c in clients[1:]:
            await c.stop()

    asyncio.run(_main())


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def slow_service(free_port):
    proc = mp.Process(target=_proc_slow_service, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.2)
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def router_no_workers(free_port):
    proc = mp.Process(target=_proc_router_only, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.15)
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def cast_mixed(free_port):
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    worker_procs = []
    for i in range(N_WORKERS - 1):
        p = mp.Process(target=_proc_fast_worker, args=(free_port, i), daemon=True)
        p.start()
        worker_procs.append(p)

    slow_p = mp.Process(target=_proc_slow_worker, args=(free_port, N_WORKERS - 1), daemon=True)
    slow_p.start()
    worker_procs.append(slow_p)

    expected = {f"timeout-aio-fast-{i:02d}" for i in range(N_WORKERS - 1)}
    expected.add(f"timeout-aio-slow-{N_WORKERS - 1:02d}")
    wait_for_members(free_port, expected, timeout=15.0, probe_name="to-aio-mixed-probe")

    yield free_port, slow_p

    for p in worker_procs:
        quiet_kill(p)
    quiet_kill(rproc)


@pytest.fixture
def cast_all_slow(free_port):
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(target=_proc_all_slow_workers, args=(free_port, N_WORKERS), daemon=True)
    wproc.start()
    expected = {f"timeout-aio-allslow-{i:02d}" for i in range(N_WORKERS)}
    wait_for_members(free_port, expected, timeout=15.0, probe_name="to-aio-allslow-probe")
    yield free_port

    quiet_kill(wproc)
    quiet_kill(rproc)


# ── rpc() timeout tests ───────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestRpcTimeoutAsync:

    async def test_slow_callback_raises_timeout_error(self, slow_service):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="to-rpc-slow", host=HOST, port=slow_service)
        conn = await client.connect()
        try:
            with pytest.raises(TimeoutError):
                await conn.rpc(timeout=SHORT_TO).slow("hello")
        finally:
            await client.stop()

    async def test_timeout_measures_wall_clock(self, slow_service):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="to-rpc-wall", host=HOST, port=slow_service)
        conn = await client.connect()
        try:
            t0 = time.monotonic()
            with pytest.raises(TimeoutError):
                await conn.rpc(timeout=SHORT_TO).slow("x")
            elapsed = time.monotonic() - t0
            assert elapsed > 0.1, f"TimeoutError raised suspiciously fast ({elapsed:.3f}s)"
            assert elapsed < SHORT_TO + 2.0, f"TimeoutError raised far too late ({elapsed:.3f}s)"
        finally:
            await client.stop()

    async def test_connection_works_after_timeout(self, slow_service):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="to-rpc-recovery", host=HOST, port=slow_service)
        conn = await client.connect()
        try:
            with pytest.raises(TimeoutError):
                await conn.rpc(timeout=SHORT_TO).slow("discard")
            result = await conn.rpc(timeout=TIMEOUT).fast("ping")
            assert result == "ping"
        finally:
            await client.stop()

    async def test_multiple_timeouts_do_not_corrupt_store(self, slow_service):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="to-rpc-repeat", host=HOST, port=slow_service)
        conn = await client.connect()
        try:
            for _ in range(3):
                with pytest.raises(TimeoutError):
                    await conn.rpc(timeout=SHORT_TO).slow("x")
            result = await conn.rpc(timeout=TIMEOUT).fast("after-timeouts")
            assert result == "after-timeouts"
        finally:
            await client.stop()

    async def test_no_receiver_raises_on_call(self, router_no_workers):
        from daffi.aio import AsyncClient
        from daffi.exceptions import TransmissionFailure

        client = AsyncClient(app_name="to-rpc-norcv", host=HOST, port=router_no_workers)
        conn = await client.connect()
        try:
            t0 = time.monotonic()
            with pytest.raises((ValueError, TransmissionFailure)):
                await conn.rpc(timeout=TIMEOUT).echo("nobody home")
            elapsed = time.monotonic() - t0
            assert elapsed < 2.0, f"Call to empty router hung for {elapsed:.3f}s"
        finally:
            await client.stop()

    async def test_zero_timeout_waits_indefinitely(self, slow_service):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="to-rpc-inf", host=HOST, port=slow_service)
        conn = await client.connect()
        try:
            result = await conn.rpc(timeout=0).slow("infinite-wait")
            assert result == "infinite-wait"
        finally:
            await client.stop()


# ── cast() timeout tests ──────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestCastTimeoutAsync:

    async def test_all_workers_slow_result_dict_contains_timeout_errors(self, cast_all_slow):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="to-cast-allslow", host=HOST, port=cast_all_slow)
        conn = await client.connect()
        try:
            results = await conn.cast(timeout=SHORT_TO).work("broadcast")
            assert isinstance(results, dict)
            assert len(results) == N_WORKERS
            for name, val in results.items():
                assert isinstance(val, TimeoutError), f"{name}: expected TimeoutError, got {val!r}"
        finally:
            await client.stop()

    async def test_one_slow_worker_partial_result(self, cast_mixed):
        from daffi.aio import AsyncClient

        port, slow_proc = cast_mixed
        slow_name = f"timeout-aio-slow-{N_WORKERS - 1:02d}"

        client = AsyncClient(app_name="to-cast-mixed", host=HOST, port=port)
        conn = await client.connect()
        try:
            results = await conn.cast(timeout=SHORT_TO).work("payload")
            assert isinstance(results, dict)
            assert slow_name in results
            assert isinstance(results[slow_name], TimeoutError)
            fast_names = [k for k in results if k != slow_name]
            assert len(fast_names) == N_WORKERS - 1
            for name in fast_names:
                assert results[name] == "payload", f"{name}: {results[name]!r}"
        finally:
            await client.stop()

    async def test_cast_nowait_returns_immediately_with_slow_workers(self, cast_all_slow):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="to-castnw-slow", host=HOST, port=cast_all_slow)
        conn = await client.connect()
        try:
            t0 = time.monotonic()
            await conn.cast_nowait().work("fire-and-forget")
            elapsed = time.monotonic() - t0
            assert elapsed < 1.0, f"cast_nowait() blocked for {elapsed:.3f}s"
        finally:
            await client.stop()

    async def test_cast_partial_result_connection_still_works(self, cast_mixed):
        from daffi.aio import AsyncClient

        port, _ = cast_mixed
        client = AsyncClient(app_name="to-cast-recover", host=HOST, port=port)
        conn = await client.connect()
        try:
            results = await conn.cast(timeout=SHORT_TO).work("x")
            assert isinstance(results, dict)
            # Connection still usable: fast workers echo fast
            results2 = await conn.cast(timeout=TIMEOUT).work("still-alive")
            fast_names = [
                k for k, v in results.items()
                if not isinstance(v, TimeoutError)
            ]
            for name in fast_names:
                assert results2.get(name) == "still-alive"
        finally:
            await client.stop()

    async def test_rpc_nowait_returns_immediately(self, slow_service):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="to-rpcnw-slow", host=HOST, port=slow_service)
        conn = await client.connect()
        try:
            t0 = time.monotonic()
            await conn.rpc_nowait().slow("ignored")
            elapsed = time.monotonic() - t0
            assert elapsed < 1.0, f"rpc_nowait() blocked for {elapsed:.3f}s"
        finally:
            await client.stop()
