"""
Async integration tests for services with many @callback functions.

Mirrors tests/integration/test_many_callbacks.py using daffi.aio.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp

import pytest

from .conftest import HOST, TIMEOUT, wait_for_port, wait_for_members, silence_subprocess, quiet_kill

N_CALLBACKS = 10


def _proc_service_many(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        def _make_cb(idx: int):
            async def fn():
                return idx
            fn.__name__     = f"cb_{idx}"
            fn.__qualname__ = f"cb_{idx}"
            return fn

        registered = [callback(_make_cb(i)) for i in range(N_CALLBACKS)]  # noqa: F841

        svc = AsyncService(app_name="many-cb-aio-svc", host=HOST, port=port)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_service_args(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        @callback
        async def echo(payload):
            return payload

        @callback
        async def multiply(a: int, b: int) -> int:
            return a * b

        svc = AsyncService(app_name="many-args-aio-svc", host=HOST, port=port)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


@pytest.fixture
def many_cb_svc(free_port):
    proc = mp.Process(target=_proc_service_many, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"many-cb-aio-svc"})
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def args_svc(free_port):
    proc = mp.Process(target=_proc_service_args, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"many-args-aio-svc"})
    yield free_port
    quiet_kill(proc)


@pytest.mark.asyncio
class TestManyCallbacksAsync:

    async def test_all_callbacks_callable(self, many_cb_svc):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="mcb-caller", host=HOST, port=many_cb_svc)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)
        try:
            for i in range(N_CALLBACKS):
                result = await getattr(proxy, f"cb_{i}")()
                assert result == i, f"cb_{i}() returned {result!r}, expected {i}"
        finally:
            await client.stop()

    async def test_concurrent_calls_to_all_callbacks(self, many_cb_svc):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="mcb-concurrent", host=HOST, port=many_cb_svc)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)
        try:
            # Sharing one proxy across concurrent coroutines is safe: __getattr__
            # returns an immutable _AsyncBoundRpc per call, never mutating proxy.
            results = await asyncio.gather(*[
                getattr(proxy, f"cb_{i}")() for i in range(N_CALLBACKS)
            ])
            assert list(results) == list(range(N_CALLBACKS))
        finally:
            await client.stop()

    async def test_echo_and_multiply(self, args_svc):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="mcb-args", host=HOST, port=args_svc)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)
        try:
            assert await proxy.echo("round-trip") == "round-trip"
            assert await proxy.multiply(6, 7) == 42
        finally:
            await client.stop()

    async def test_mixed_concurrent(self, args_svc):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="mcb-mixed", host=HOST, port=args_svc)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)
        try:
            # One shared proxy, two different function names, gathered concurrently.
            # Safe because __getattr__ returns a new _AsyncBoundRpc each time.
            echo_coros = [proxy.echo(f"msg-{i}") for i in range(10)]
            mul_coros  = [proxy.multiply(i, 2) for i in range(10)]
            results = await asyncio.gather(*echo_coros, *mul_coros)
            for i, r in enumerate(results[:10]):
                assert r == f"msg-{i}"
            for i, r in enumerate(results[10:]):
                assert r == i * 2
        finally:
            await client.stop()
