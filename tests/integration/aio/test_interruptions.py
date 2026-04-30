"""
Async integration tests for connection interruption scenarios.

Mirrors tests/integration/test_interruptions.py using daffi.aio.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import os
import signal
import time

import pytest

from .conftest import HOST, TIMEOUT, wait_for_port, wait_for_members, silence_subprocess, quiet_kill
from daffi.exceptions import InitializationError, TransmissionFailure


# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_service(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        @callback
        async def echo(payload):
            return payload

        svc = AsyncService(app_name="intr-aio-svc", host=HOST, port=port)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_router(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter

        r = AsyncRouter(app_name="intr-aio-router", host=HOST, port=port)
        await r.start()
        await r.join()

    asyncio.run(_main())


def _proc_worker(port: int, name: str = "intr-aio-worker") -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def echo(payload):
            return payload

        client = AsyncClient(app_name=name, host=HOST, port=port)
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def live_service(free_port):
    proc = mp.Process(target=_proc_service, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.15)
    yield free_port, proc
    quiet_kill(proc)


@pytest.fixture
def router_with_one_worker(free_port):
    rproc = mp.Process(target=_proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(target=_proc_worker, args=(free_port,), daemon=True)
    wproc.start()
    wait_for_members(free_port, {"intr-aio-worker"})
    yield free_port, rproc, wproc
    quiet_kill(wproc)
    quiet_kill(rproc)


# ── tests ──────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestServiceKilledAsync:

    async def test_service_killed_raises_transmission_failure(self, live_service):
        """After the service is killed, the next rpc() call raises TransmissionFailure."""
        from daffi.aio import AsyncClient

        port, svc_proc = live_service
        client = AsyncClient(app_name="intr-killed", host=HOST, port=port)
        conn = await client.connect()

        # Give one good call to confirm the connection is live.
        assert await conn.rpc(timeout=TIMEOUT).echo("alive") == "alive"

        # Kill the service process abruptly.
        svc_proc.kill()
        svc_proc.join(timeout=5)
        await asyncio.sleep(0.3)

        try:
            with pytest.raises((TransmissionFailure, OSError, ConnectionError, Exception)):
                await conn.rpc(timeout=5).echo("dead")
        finally:
            await client.stop()

    async def test_connect_to_dead_service_raises(self, free_port):
        """connect() to a port with no listener raises InitializationError."""
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="intr-dead-connect", host=HOST, port=free_port)
        with pytest.raises(InitializationError):
            await client.connect()

    async def test_service_frozen_raises_timeout(self, live_service):
        """SIGSTOP-frozen service: rpc() with short timeout raises TimeoutError."""
        from daffi.aio import AsyncClient

        port, svc_proc = live_service
        client = AsyncClient(app_name="intr-frozen", host=HOST, port=port)
        conn = await client.connect()

        os.kill(svc_proc.pid, signal.SIGSTOP)
        try:
            with pytest.raises(TimeoutError):
                await conn.rpc(timeout=2).echo("frozen")
        finally:
            os.kill(svc_proc.pid, signal.SIGCONT)
            await client.stop()

    async def test_service_resumed_call_succeeds(self, live_service):
        """SIGSTOP then SIGCONT: rpc() eventually succeeds."""
        from daffi.aio import AsyncClient

        port, svc_proc = live_service
        client = AsyncClient(app_name="intr-resumed", host=HOST, port=port)
        conn = await client.connect()

        os.kill(svc_proc.pid, signal.SIGSTOP)
        await asyncio.sleep(0.1)
        os.kill(svc_proc.pid, signal.SIGCONT)

        try:
            result = await conn.rpc(timeout=TIMEOUT).echo("resumed")
            assert result == "resumed"
        finally:
            await client.stop()


@pytest.mark.asyncio
class TestWorkerKilledAsync:

    async def test_one_worker_killed_cast_to_remaining_succeeds(self, router_with_one_worker):
        """After killing one worker, a fresh cast() to surviving workers still works."""
        from daffi.aio import AsyncClient

        port, rproc, wproc = router_with_one_worker

        # Add a second worker so there's one surviving after we kill the first.
        proc2 = mp.Process(target=_proc_worker, args=(port, "intr-aio-worker2"), daemon=True)
        proc2.start()
        wait_for_members(port, {"intr-aio-worker2"})

        client = AsyncClient(app_name="intr-cast-caller", host=HOST, port=port)
        conn = await client.connect()

        # Verify both workers are reachable.
        results = await conn.cast(timeout=TIMEOUT).echo("before-kill")
        assert "intr-aio-worker" in results
        assert "intr-aio-worker2" in results

        # Kill the first worker.
        wproc.kill()
        wproc.join(timeout=5)
        await asyncio.sleep(0.5)

        try:
            # Cast to surviving worker must succeed.
            results = await conn.cast(timeout=TIMEOUT).echo("after-kill")
            assert "intr-aio-worker2" in results
            assert results["intr-aio-worker2"] == "after-kill"
        finally:
            await client.stop()
            quiet_kill(proc2)
