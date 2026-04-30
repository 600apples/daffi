"""
Async integration tests for multi-chunk (stream) data-integrity transfer.

Mirrors tests/integration/test_chunked.py using daffi.aio.
Uses ``await conn.stream()`` and ``conn.stream_nowait()`` with OPAQUE serde.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import pickle

import pytest

from .conftest import (
    HOST, TIMEOUT,
    quiet_kill, silence_subprocess,
    wait_for_port, wait_for_members,
)

CHUNK_SIZE = 64 * 1024
LARGE_N    = 200_000


# ── subprocess: service with chunked-assembly callbacks ───────────────────────

def _proc_service(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        _buf: list[bytes] = []

        @callback
        async def receive_chunk(chunk: bytes) -> None:
            _buf.append(chunk)

        @callback
        async def get_result() -> bytes:
            data = b"".join(_buf)
            _buf.clear()
            return data

        svc = AsyncService(app_name="chunk-aio-svc", host=HOST, port=port, workers=1)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_router(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter

        r = AsyncRouter(app_name="chunk-aio-router", host=HOST, port=port)
        await r.start()
        await r.join()

    asyncio.run(_main())


def _proc_worker(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        _buf: list[bytes] = []

        @callback
        async def receive_chunk(chunk: bytes) -> None:
            _buf.append(chunk)

        @callback
        async def get_result() -> bytes:
            data = b"".join(_buf)
            _buf.clear()
            return data

        client = AsyncClient(app_name="chunk-aio-worker", host=HOST, port=port, workers=1)
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def direct_svc(free_port):
    proc = mp.Process(target=_proc_service, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"chunk-aio-svc"})
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def router_worker(free_port):
    rproc = mp.Process(target=_proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(target=_proc_worker, args=(free_port,), daemon=True)
    wproc.start()
    wait_for_members(free_port, {"chunk-aio-worker"})
    yield free_port
    quiet_kill(wproc)
    quiet_kill(rproc)


# ── helpers ───────────────────────────────────────────────────────────────────

async def _transfer(conn, payload_obj: object, nowait: bool = False) -> object:
    """Pickle *payload_obj*, split into CHUNK_SIZE chunks, stream to service,
    retrieve assembled bytes and unpickle."""
    from daffi import SerdeFormat

    raw = pickle.dumps(payload_obj)
    chunks = [raw[i:i + CHUNK_SIZE] for i in range(0, len(raw), CHUNK_SIZE)]

    for chunk in chunks:
        if nowait:
            # stream_nowait().__call__ is async too — await sends the chunk
            # without waiting for a remote acknowledgement.
            await conn.stream_nowait(serde=SerdeFormat.OPAQUE).receive_chunk(chunk)
        else:
            await conn.stream(serde=SerdeFormat.OPAQUE).receive_chunk(chunk)

    assembled: bytes = await conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.PICKLE).get_result()
    return pickle.loads(assembled)


# ── tests ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestChunkedDirectAsync:

    async def test_small_list(self, direct_svc):
        from daffi.aio import AsyncClient
        client = AsyncClient(app_name="chk-sml", host=HOST, port=direct_svc)
        conn = await client.connect()
        payload = list(range(1_000))
        try:
            assert await _transfer(conn, payload) == payload
        finally:
            await client.stop()

    async def test_large_list(self, direct_svc):
        from daffi.aio import AsyncClient
        client = AsyncClient(app_name="chk-lrg", host=HOST, port=direct_svc)
        conn = await client.connect()
        payload = list(range(LARGE_N))
        try:
            assert await _transfer(conn, payload) == payload
        finally:
            await client.stop()

    async def test_string(self, direct_svc):
        from daffi.aio import AsyncClient
        client = AsyncClient(app_name="chk-str", host=HOST, port=direct_svc)
        conn = await client.connect()
        payload = "x" * (CHUNK_SIZE * 3)
        try:
            assert await _transfer(conn, payload) == payload
        finally:
            await client.stop()

    async def test_nowait_chunks(self, direct_svc):
        """stream_nowait() chunks followed by rpc() get_result() arrive in order."""
        from daffi.aio import AsyncClient
        client = AsyncClient(app_name="chk-nw", host=HOST, port=direct_svc)
        conn = await client.connect()
        payload = list(range(10_000))
        try:
            result = await _transfer(conn, payload, nowait=True)
            assert result == payload
        finally:
            await client.stop()


@pytest.mark.asyncio
class TestChunkedRouterAsync:

    async def test_large_list_via_router(self, router_worker):
        from daffi.aio import AsyncClient
        client = AsyncClient(app_name="chk-rtr", host=HOST, port=router_worker)
        conn = await client.connect()
        payload = list(range(LARGE_N))
        try:
            assert await _transfer(conn, payload) == payload
        finally:
            await client.stop()

    async def test_nowait_via_router(self, router_worker):
        from daffi.aio import AsyncClient
        client = AsyncClient(app_name="chk-rtr-nw", host=HOST, port=router_worker)
        conn = await client.connect()
        payload = {"key": list(range(5_000))}
        try:
            result = await _transfer(conn, payload, nowait=True)
            assert result == payload
        finally:
            await client.stop()
