"""
End-to-end regression tests for the second review round, through
``daffi.aio``.

Each test fails on the behaviour that used to happen:

* ``workers=N`` on an AsyncService did not overlap incoming calls;
* a ``serdes=`` allow-list did not exist, so any peer could make a service
  unpickle its payload;
* one request whose text payload was not valid UTF-8 stopped the
  dispatcher;
* after ``start(); stop(); start()`` the second ``stop()`` did nothing;
* ``rpc_nowait`` split a list argument into one call per item and dropped
  keyword arguments.
"""

from __future__ import annotations
from tests.conftest import active_runtime

import asyncio
import multiprocessing as mp
import socket
import time
from contextlib import asynccontextmanager

import pytest

from .conftest import (
    HOST,
    proc_service,
    quiet_kill,
    silence_subprocess,
    wait_for_members,
    wait_for_port,
)

TARGET = "aio-fix-target"


# ── subprocess targets ────────────────────────────────────────────────────────


def _proc_target_service(runtime: str, port: int, workers, serdes) -> None:
    silence_subprocess(runtime)

    async def _main():
        import time as _time

        from daffi import callback, TCPTransport
        from daffi.aio import AsyncService

        seen: list = []

        @callback
        async def nap(seconds: float):
            await asyncio.sleep(seconds)
            return seconds

        @callback
        def blocking_nap(seconds: float):
            _time.sleep(seconds)
            return seconds

        @callback
        async def lookup(key):
            return key

        @callback
        async def remember(*args, **kwargs):
            seen.append((args, kwargs))

        @callback
        async def recall():
            return list(seen)

        @callback
        async def add(a: int, b: int) -> int:
            return a + b

        kwargs = {} if workers is None else {"workers": workers}
        svc = AsyncService(
            app_name=TARGET,
            serdes=serdes,
            transport=TCPTransport(HOST, port),
            runtime=runtime,
            **kwargs,
        )
        await svc.start()
        await svc.join()

    asyncio.run(_main())


class _Booby:
    """Unpickling this creates *path*: proof that a payload was unpickled."""

    def __init__(self, path: str) -> None:
        self.path = path

    def __reduce__(self):
        return (open, (self.path, "w"))


# ── helpers ───────────────────────────────────────────────────────────────────


def _start_target(port: int, workers=None, serdes=None) -> mp.Process:
    proc = mp.Process(
        target=_proc_target_service,
        args=(active_runtime(), port, workers, serdes),
        daemon=True,
    )
    proc.start()
    wait_for_port(port, proc=proc)
    wait_for_members(port, {TARGET})
    return proc


@asynccontextmanager
async def _client(port: int, name: str, *members: str):
    from daffi import TCPTransport
    from daffi.aio import AsyncClient

    client = AsyncClient(app_name=name, transport=TCPTransport(HOST, port), runtime=active_runtime())
    conn = await client.connect()
    try:
        if members:
            await conn.wait_for_members(*members, timeout=10)
        yield client, conn
    finally:
        await client.stop()


def _accepts(port: int) -> bool:
    try:
        socket.create_connection((HOST, port), timeout=0.5).close()
        return True
    except OSError:
        return False


async def _wait_until(predicate, timeout: float, what: str) -> None:
    deadline = time.monotonic() + timeout
    while not await predicate():
        if time.monotonic() > deadline:
            pytest.fail(f"timed out waiting for {what}")
        await asyncio.sleep(0.05)


async def _port_closed(port: int) -> bool:
    return not _accepts(port)


@pytest.fixture
def default_target(free_port):
    proc = _start_target(free_port)
    yield free_port
    quiet_kill(proc)


# ── 1. concurrency ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
class TestConcurrencyByDefault:
    @pytest.mark.parametrize("func", ["nap", "blocking_nap"])
    async def test_default_runs_one_at_a_time(self, default_target, func):
        async with _client(default_target, f"serial-{func}", TARGET) as (_, conn):
            started = time.monotonic()
            results = await asyncio.gather(
                *(getattr(conn.rpc(timeout=10), func)(0.1) for _ in range(5))
            )
            took = time.monotonic() - started
        assert results == [0.1] * 5
        assert took >= 0.45, f"default workers ran calls in parallel ({took:.2f}s)"

    @pytest.mark.parametrize("func", ["nap", "blocking_nap"])
    async def test_workers_n_overlaps_calls(self, free_port, func):
        proc = _start_target(free_port, workers=10)
        try:
            async with _client(free_port, f"overlap-{func}", TARGET) as (_, conn):
                started = time.monotonic()
                results = await asyncio.gather(
                    *(getattr(conn.rpc(timeout=10), func)(0.2) for _ in range(10))
                )
                took = time.monotonic() - started
            assert results == [0.2] * 10
            assert took < 1.0, f"10 x 0.2 s calls took {took:.2f}s"
        finally:
            quiet_kill(proc)

    async def test_workers_1_runs_one_at_a_time(self, free_port):
        proc = _start_target(free_port, workers=1)
        try:
            async with _client(free_port, "serial", TARGET) as (_, conn):
                started = time.monotonic()
                await asyncio.gather(*(conn.rpc(timeout=10).nap(0.1) for _ in range(5)))
                took = time.monotonic() - started
            assert took >= 0.45, f"workers=1 ran calls in parallel ({took:.2f}s)"
        finally:
            quiet_kill(proc)

    async def test_service_answers_while_every_slot_is_busy(self, free_port):
        """Requests beyond ``workers`` wait their turn and are all answered."""
        proc = _start_target(free_port, workers=2)
        try:
            async with _client(free_port, "over-slots", TARGET) as (_, conn):
                started = time.monotonic()
                results = await asyncio.gather(
                    *(conn.rpc(timeout=10).nap(0.2) for _ in range(6))
                )
                took = time.monotonic() - started
            assert results == [0.2] * 6
            assert 0.55 <= took < 2.0, f"took {took:.2f}s"
        finally:
            quiet_kill(proc)


# ── 2. serdes ─────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_serdes_allow_list_refuses_before_decoding(free_port, tmp_path):
    from daffi import SerdeFormat
    from daffi.exceptions import RemoteCallError

    proc = _start_target(free_port, serdes=[SerdeFormat.JSON])
    try:
        marker = tmp_path / "unpickled"
        async with _client(free_port, "aio-allow-list", TARGET) as (_, conn):
            with pytest.raises(RemoteCallError, match="PICKLE") as info:
                await conn.rpc(timeout=10).lookup(_Booby(str(marker)))
            assert type(info.value).__name__ == "SerdeNotAllowed"
            assert await conn.rpc(timeout=10, serde=SerdeFormat.JSON).add(2, 3) == 5
        assert not marker.exists(), "a refused PICKLE payload was unpickled"
    finally:
        quiet_kill(proc)


# ── 3. invalid UTF-8 ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_invalid_utf8_text_does_not_stop_the_service(default_target):
    from daffi import SerdeFormat
    from daffi._bindings import MessageFlag, send_message_from_client

    async with _client(default_target, "aio-bad-utf8", TARGET) as (client, conn):
        for _ in range(3):
            send_message_from_client(
                data=b"\xff\xfe",
                flag=MessageFlag.REQUEST,
                serde=SerdeFormat.OPAQUE,
                receiver="",
                func_name="remember",
                return_result=False,
                conn_num=client._conn_num,
                is_bytes=False,
            )
        assert await conn.rpc(timeout=10).add(20, 22) == 42

        async def _all_seen():
            return len(await conn.rpc(timeout=10).recall()) == 3

        await _wait_until(_all_seen, 10, "the three requests")
        assert await conn.rpc(timeout=10).recall() == [((b"\xff\xfe",), {})] * 3


# ── 4. restart ────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["AsyncService", "AsyncRouter"])
async def test_server_restarted_after_stop_stops_again(free_port, kind):
    import daffi.aio
    from daffi import TCPTransport

    server = getattr(daffi.aio, kind)(
        app_name=f"aio-restart-{kind.lower()}",
        transport=TCPTransport(HOST, free_port),
        runtime=active_runtime(),
    )
    await server.start()
    await server.stop()
    await _wait_until(lambda: _port_closed(free_port), 5, "the first stop to close the port")
    await server.start()
    try:
        assert _accepts(free_port)
        joiner = asyncio.ensure_future(server.join())
        await asyncio.sleep(0.3)
        assert not joiner.done(), "join() returned while the server was running"
    finally:
        await server.stop()
    await _wait_until(lambda: _port_closed(free_port), 5, "the second stop to close the port")
    await asyncio.wait_for(joiner, 5)


@pytest.mark.asyncio
async def test_client_reconnected_after_stop_works(free_port):
    from daffi import TCPTransport
    from daffi.aio import AsyncClient

    proc = mp.Process(target=proc_service, args=(active_runtime(), free_port), daemon=True)
    proc.start()
    try:
        wait_for_port(free_port, proc=proc)
        wait_for_members(free_port, {"integ-aio-service"})
        client = AsyncClient(
            app_name="aio-reconnect-after-stop",
            transport=TCPTransport(HOST, free_port),
            runtime=active_runtime(),
        )
        for round_ in range(2):
            conn = await client.connect()
            try:
                await conn.wait_for_members("integ-aio-service", timeout=10)
                assert await conn.rpc(timeout=10).add(round_, 1) == round_ + 1
                joiner = asyncio.ensure_future(client.join())
                await asyncio.sleep(0.3)
                assert not joiner.done(), f"round {round_}: join() returned while connected"
            finally:
                await client.stop()
            await asyncio.wait_for(joiner, 5)
    finally:
        quiet_kill(proc)


# ── 5. rpc_nowait ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_rpc_nowait_sends_one_call_with_all_arguments(default_target):
    async with _client(default_target, "aio-nowait", TARGET) as (_, conn):
        await conn.rpc_nowait().remember(["a", "b", "c"], tag="x")
        await conn.rpc_nowait().remember("plain")
        await conn.rpc_nowait().remember(key=[1, 2])

        async def _all_seen():
            return len(await conn.rpc(timeout=10).recall()) >= 3

        await _wait_until(_all_seen, 10, "the calls")
        await asyncio.sleep(0.2)
        # Requests run concurrently, so in any order.
        assert sorted(await conn.rpc(timeout=10).recall(), key=repr) == sorted(
            [
                ((["a", "b", "c"],), {"tag": "x"}),
                (("plain",), {}),
                ((), {"key": [1, 2]}),
            ],
            key=repr,
        )


def test_stream_nowait_keeps_the_requested_serde():
    from types import SimpleNamespace

    from daffi.aio._rpc_proxy import AsyncClientConnection
    from daffi._serialization import SerdeFormat

    conn = SimpleNamespace(client=SimpleNamespace(logger=None))
    for serde in (SerdeFormat.JSON, SerdeFormat.PICKLE, SerdeFormat.OPAQUE):
        assert AsyncClientConnection.stream_nowait(conn, serde=serde).serde == serde
        assert AsyncClientConnection.stream(conn, serde=serde).serde == serde
