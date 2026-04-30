"""
Async integration tests for duplicate app_name handling.

Mirrors tests/integration/test_duplicate_name.py using daffi.aio.
Last-connection-wins: a new peer with the same name evicts the existing one.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import time

import pytest

from .conftest import (
    HOST,
    quiet_kill,
    silence_subprocess,
    wait_for_members,
    wait_for_port,
)


def _router_only(port: int, name: str = "dup-aio-router") -> None:
    silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter
        r = AsyncRouter(app_name=name, host=HOST, port=port)
        await r.start()
        await r.join()

    asyncio.run(_main())


def _service_only(port: int, name: str = "dup-aio-service") -> None:
    silence_subprocess()

    async def _main():
        from daffi.aio import AsyncService
        s = AsyncService(app_name=name, host=HOST, port=port, workers=2)
        await s.start()
        await s.join()

    asyncio.run(_main())


def _client_only(port: int, name: str) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def ping():
            return "pong"

        client = AsyncClient(app_name=name, host=HOST, port=port)
        await client.connect()
        await client.join()

    asyncio.run(_main())


@pytest.fixture
def router_fixture(free_port):
    proc = mp.Process(target=_router_only, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def service_fixture(free_port):
    proc = mp.Process(target=_service_only, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.15)
    yield free_port
    quiet_kill(proc)


@pytest.mark.asyncio
class TestDuplicateNameRouterAsync:

    async def test_second_connect_same_name_succeeds(self, router_fixture):
        """Two AsyncClients with the same app_name both connect (eviction)."""
        from daffi.aio import AsyncClient

        client1 = AsyncClient(app_name="dup-aio-client", host=HOST, port=router_fixture)
        await client1.connect()

        client2 = AsyncClient(app_name="dup-aio-client", host=HOST, port=router_fixture)
        conn2 = await client2.connect()

        try:
            assert client2._conn_num is not None, "client2 should be connected"
        finally:
            await client2.stop()
            try:
                await client1.stop()
            except Exception:
                pass

    async def test_reconnect_after_stop_succeeds(self, router_fixture):
        """AsyncClient can reconnect after explicit stop()."""
        from daffi.aio import AsyncClient

        name = "dup-aio-reconnect"
        client1 = AsyncClient(app_name=name, host=HOST, port=router_fixture)
        await client1.connect()
        await client1.stop()
        await asyncio.sleep(0.1)

        client2 = AsyncClient(app_name=name, host=HOST, port=router_fixture)
        await client2.connect()
        try:
            assert client2._conn_num is not None
        finally:
            await client2.stop()


@pytest.mark.asyncio
class TestDuplicateNameServiceAsync:

    async def test_second_connect_same_name_succeeds(self, service_fixture):
        from daffi.aio import AsyncClient

        client1 = AsyncClient(app_name="dup-aio-svc-c", host=HOST, port=service_fixture)
        await client1.connect()

        client2 = AsyncClient(app_name="dup-aio-svc-c", host=HOST, port=service_fixture)
        await client2.connect()

        try:
            assert client2._conn_num is not None
        finally:
            await client2.stop()
            try:
                await client1.stop()
            except Exception:
                pass
