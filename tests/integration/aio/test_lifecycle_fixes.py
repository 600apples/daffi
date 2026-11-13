"""
Regression tests for async lifecycle fixes.

Each test fails on the behaviour that used to happen:

* a call still waiting for its response when the client stopped (or
  reconnected) never resolved: a stream or rpc without timeout hung;
* a joining client that lost its server called ``stop()`` itself, so the
  reconnect that ``join()`` documents never ran;
* sync member-event handlers ran on the event loop thread.
"""

from __future__ import annotations
from tests.conftest import active_runtime

import asyncio
import multiprocessing as mp
import threading

import pytest

from .conftest import (
    HOST,
    proc_router,
    quiet_kill,
    silence_subprocess,
    wait_for_members,
    wait_for_port,
)

TARGET = "aio-lifecycle-target"


def _proc_hanging_service(runtime: str, port: int) -> None:
    silence_subprocess(runtime)

    async def _main():
        from daffi import callback, TCPTransport
        from daffi.aio import AsyncService

        @callback
        async def hang(*_):
            await asyncio.sleep(60)

        @callback
        async def add(a: int, b: int) -> int:
            return a + b

        svc = AsyncService(
            app_name=TARGET,
            workers=4,
            transport=TCPTransport(HOST, port),
            runtime=runtime,
        )
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _start_target(port: int) -> mp.Process:
    proc = mp.Process(
        target=_proc_hanging_service, args=(active_runtime(), port), daemon=True
    )
    proc.start()
    wait_for_port(port, proc=proc)
    wait_for_members(port, {TARGET})
    return proc


async def _connect(port: int, name: str):
    from daffi import TCPTransport
    from daffi.aio import AsyncClient

    client = AsyncClient(
        app_name=name, transport=TCPTransport(HOST, port), runtime=active_runtime()
    )
    conn = await client.connect()
    await conn.wait_for_members(TARGET, timeout=10)
    return client, conn


@pytest.fixture
def target(free_port):
    proc = _start_target(free_port)
    yield free_port
    quiet_kill(proc)


@pytest.mark.asyncio
@pytest.mark.parametrize("style", ["stream", "rpc"])
async def test_pending_call_fails_when_the_client_stops(target, style):
    from daffi.exceptions import Disconnected

    client, conn = await _connect(target, f"aio-pending-{style}")
    try:
        if style == "stream":
            call = asyncio.ensure_future(conn.stream().hang([b"chunk"]))
        else:
            call = asyncio.ensure_future(conn.rpc().hang())
        await asyncio.sleep(0.5)
        assert not call.done()
    finally:
        await client.stop()
    with pytest.raises(Disconnected):
        await asyncio.wait_for(call, 5)


@pytest.mark.asyncio
async def test_pending_call_fails_when_its_notifier_is_replaced(target):
    from daffi.aio._rpc_proxy import AsyncResponseNotifier
    from daffi.exceptions import Disconnected

    client, conn = await _connect(target, "aio-pending-replaced")
    try:
        call = asyncio.ensure_future(conn.stream().hang([b"chunk"]))
        await asyncio.sleep(0.5)
        AsyncResponseNotifier.register(client._conn_num)
        with pytest.raises(Disconnected):
            await asyncio.wait_for(call, 5)
    finally:
        await client.stop()


@pytest.mark.asyncio
async def test_join_reconnects_after_the_server_restarts(free_port):
    proc = _start_target(free_port)
    client, conn = await _connect(free_port, "aio-join-reconnect")
    try:
        restarted = asyncio.get_running_loop().create_future()
        original = client._try_reconnect

        async def _reconnect_once_restarted():
            # The reconnect is a single attempt: give it a server to reach.
            await restarted
            return await original()

        client._try_reconnect = _reconnect_once_restarted
        joiner = asyncio.ensure_future(client.join())
        await asyncio.sleep(0.3)
        assert not joiner.done()

        quiet_kill(proc)
        loop = asyncio.get_running_loop()
        proc = await loop.run_in_executor(None, _start_target, free_port)
        restarted.set_result(None)

        await asyncio.wait_for(joiner, 30)
        assert not client._intentionally_stopped
        await conn.wait_for_members(TARGET, timeout=10)
        assert await conn.rpc(timeout=10).add(2, 3) == 5
    finally:
        await client.stop()
        quiet_kill(proc)


@pytest.fixture
def router_port(free_port):
    proc = mp.Process(
        target=proc_router, args=(active_runtime(), free_port), daemon=True
    )
    proc.start()
    wait_for_port(free_port, proc=proc)
    yield free_port
    quiet_kill(proc)


@pytest.mark.asyncio
async def test_sync_event_handlers_run_off_the_loop_in_order(router_port):
    from daffi import TCPTransport
    from daffi.aio import AsyncClient

    client = AsyncClient(
        app_name="aio-event-watcher",
        transport=TCPTransport(HOST, router_port),
        runtime=active_runtime(),
    )
    conn = await client.connect()
    seen: list = []
    threads: set = set()
    added = asyncio.Event()
    done = asyncio.Event()
    loop = asyncio.get_running_loop()

    @conn.on_member_added
    def _added(name):
        threads.add(threading.get_ident())
        seen.append(("added", name))
        loop.call_soon_threadsafe(added.set)

    @conn.on_member_removed
    def _removed(name):
        threads.add(threading.get_ident())
        seen.append(("removed", name))
        loop.call_soon_threadsafe(done.set)

    try:
        peer = AsyncClient(
            app_name="aio-event-peer",
            transport=TCPTransport(HOST, router_port),
            runtime=active_runtime(),
        )
        await peer.connect()
        await asyncio.wait_for(added.wait(), 10)
        await peer.stop()
        await asyncio.wait_for(done.wait(), 10)
        assert seen == [("added", "aio-event-peer"), ("removed", "aio-event-peer")]
        assert threading.get_ident() not in threads
    finally:
        await client.stop()
