"""
End-to-end regression tests for the review fixes, through ``daffi.aio``.

Each test fails on the behaviour that used to happen:

* a failing callback, serialisation or event handler stopped the dispatcher;
* a synchronous callback ran on the event loop and froze every other call;
* each response woke every waiter of the client;
* a cancelled call's late response could reach a later call;
* an evicted client took its name back on the next call;
* a callback could not stop its own application;
* ``stop()`` on a service or router left the server running, and waited
  for running callbacks;
* signals ended the process with ``_exit(0)``;
* a peer could make a JSON caller unpickle data.
"""

from __future__ import annotations
from tests.conftest import active_runtime

import asyncio
import multiprocessing as mp
import os
import signal
import socket
import subprocess
import sys
import time
from contextlib import asynccontextmanager
from pathlib import Path

import pytest

from .conftest import (
    HOST,
    quiet_kill,
    silence_subprocess,
    wait_for_members,
    wait_for_port,
    proc_router,
    proc_worker,
)

ROOT = Path(__file__).resolve().parents[3]
FRAGILE = "aio-fragile"


# ── subprocess targets ────────────────────────────────────────────────────────


def _proc_fragile_service(runtime: str, port: int, workers: int, explode_on_join: bool) -> None:
    silence_subprocess(runtime)

    async def _main():
        import time as _time

        from daffi import callback, TCPTransport
        from daffi.aio import AsyncService

        @callback
        def unserializable_set():
            return {1, 2}

        @callback
        async def boom():
            raise ValueError("boom")

        @callback
        def blocking_sleep(seconds: float):
            _time.sleep(seconds)
            return seconds

        @callback
        async def slow_echo(value, delay: float):
            await asyncio.sleep(delay)
            return value

        @callback
        async def echo(value):
            return value

        @callback
        async def add(a: int, b: int) -> int:
            return a + b

        svc = AsyncService(
            app_name=FRAGILE, workers=workers, transport=TCPTransport(HOST, port),
            runtime=runtime,
        )

        if explode_on_join:

            @svc.on_member_added
            async def _explode(name):
                raise RuntimeError(f"event handler failure for {name}")

        await svc.start()
        await svc.join()

    asyncio.run(_main())


class _Booby:
    """Unpickling this creates *path*: proof that a payload was unpickled."""

    def __init__(self, path: str) -> None:
        self.path = path

    def __reduce__(self):
        return (open, (self.path, "w"))


def _proc_pickle_injector(runtime: str, port: int, marker: str, flag_name: str) -> None:
    silence_subprocess(runtime)
    import daffi._task_dispatcher as dispatcher
    from daffi import SerdeFormat
    from daffi._bindings import MessageFlag
    from daffi._serialization import Serializer

    def _inject(result, flag, serde):
        data, is_bytes = Serializer.serialize(SerdeFormat.PICKLE, _Booby(marker))
        return data, is_bytes, getattr(MessageFlag, flag_name), SerdeFormat.PICKLE

    dispatcher._encode_reply = _inject

    async def _main():
        from daffi import callback, TCPTransport
        from daffi.aio import AsyncService

        @callback
        async def lookup(key):
            return key

        svc = AsyncService(app_name="aio-injector", transport=TCPTransport(HOST, port), runtime=runtime)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_self_stopping_worker(runtime: str, port: int, workers: int, q) -> None:
    silence_subprocess(runtime)

    async def _main():
        from daffi import callback, TCPTransport
        from daffi.aio import AsyncClient

        holder = {}

        @callback
        async def shutdown():
            await holder["client"].stop()

        client = AsyncClient(
            app_name="aio-self-stopper", workers=workers, transport=TCPTransport(HOST, port),
            runtime=runtime,
        )
        holder["client"] = client
        await client.connect()
        await client.join()

    try:
        asyncio.run(asyncio.wait_for(_main(), 60))
        q.put("joined")
    except BaseException as exc:  # noqa: BLE001
        q.put(f"{type(exc).__name__}: {exc}")


# ── helpers ───────────────────────────────────────────────────────────────────


def _start_fragile(port: int, workers: int, explode_on_join: bool = False) -> mp.Process:
    proc = mp.Process(
        target=_proc_fragile_service,
        args=(active_runtime(), port, workers, explode_on_join),
        daemon=True,
    )
    proc.start()
    wait_for_port(port, proc=proc)
    wait_for_members(port, {FRAGILE})
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
        yield conn
    finally:
        await client.stop()


async def _wait_until(predicate, timeout: float, what: str) -> None:
    deadline = time.monotonic() + timeout
    while not await predicate():
        if time.monotonic() > deadline:
            pytest.fail(f"timed out waiting for {what}")
        await asyncio.sleep(0.05)


def _run_script(source: str) -> subprocess.Popen:
    return subprocess.Popen(
        [sys.executable, "-c", source],
        cwd=str(ROOT),
        env=dict(os.environ, PYTHONPATH=str(ROOT)),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def _finish(proc: subprocess.Popen, timeout: float = 20) -> tuple[int, str]:
    try:
        out, err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
        pytest.fail(f"process did not exit within {timeout}s\n{out}\n{err}")
    return proc.returncode, out + err


# ── fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture(params=[1, 4], ids=["inline", "pool"])
def fragile_service(request, free_port):
    proc = _start_fragile(free_port, request.param)
    yield free_port, proc
    quiet_kill(proc)


@pytest.fixture
def pool_service(free_port):
    proc = _start_fragile(free_port, 4)
    yield free_port, proc
    quiet_kill(proc)


@pytest.fixture
def router_port(free_port):
    proc = mp.Process(target=proc_router, args=(active_runtime(), free_port), daemon=True)
    proc.start()
    wait_for_port(free_port, proc=proc)
    yield free_port
    quiet_kill(proc)


# ── 1. dispatcher ─────────────────────────────────────────────────────────────


class TestDispatcherSurvivesFailures:
    async def _assert_still_serves(self, conn) -> None:
        assert await conn.rpc(timeout=10).add(20, 22) == 42

    async def test_unserializable_result(self, fragile_service):
        from daffi import SerdeFormat
        from daffi.exceptions import RemoteCallError

        port, _ = fragile_service
        async with _client(port, "aio-disp-json", FRAGILE) as conn:
            started = time.monotonic()
            with pytest.raises(RemoteCallError):
                await conn.rpc(timeout=10, serde=SerdeFormat.JSON).unserializable_set()
            assert time.monotonic() - started < 5
            await self._assert_still_serves(conn)

    async def test_raising_callback(self, fragile_service):
        from daffi.exceptions import RemoteCallError

        port, _ = fragile_service
        async with _client(port, "aio-disp-boom", FRAGILE) as conn:
            for _ in range(3):
                with pytest.raises(RemoteCallError, match="boom"):
                    await conn.rpc(timeout=10).boom()
            await self._assert_still_serves(conn)

    @pytest.mark.parametrize("workers", [1, 4], ids=["inline", "pool"])
    async def test_failing_event_handler(self, free_port, workers):
        proc = _start_fragile(free_port, workers, explode_on_join=True)
        try:
            # Every connection fires the service's raising on_member_added handler.
            for i in range(3):
                async with _client(free_port, f"aio-disp-event-{i}", FRAGILE) as conn:
                    await self._assert_still_serves(conn)
        finally:
            quiet_kill(proc)


async def test_sync_callback_does_not_freeze_the_service_loop(pool_service):
    """A blocking sync callback runs off the event loop, so other calls to the
    same service are answered while it sleeps."""
    port, _ = pool_service
    async with _client(port, "aio-loop-free", FRAGILE) as conn:
        blocking = asyncio.ensure_future(conn.rpc(timeout=10).blocking_sleep(1.5))
        await asyncio.sleep(0.3)  # the blocking callback is running now
        started = time.monotonic()
        for i in range(5):
            assert await conn.rpc(timeout=10).add(i, i) == 2 * i
        assert time.monotonic() - started < 0.8
        assert not blocking.done()
        assert await blocking == 1.5


async def test_disconnect_during_call_raises_disconnected(fragile_service):
    from daffi.exceptions import Disconnected

    port, proc = fragile_service
    async with _client(port, "aio-mid-call-victim", FRAGILE) as conn:
        asyncio.get_running_loop().call_later(0.5, os.kill, proc.pid, signal.SIGKILL)
        started = time.monotonic()
        with pytest.raises(Disconnected):
            await conn.rpc(timeout=30).slow_echo("never", 20)
        assert time.monotonic() - started < 10


# ── 2. waiting for responses ──────────────────────────────────────────────────


async def test_concurrent_calls_are_woken_promptly(pool_service):
    port, _ = pool_service
    async with _client(port, "aio-many-waiters", FRAGILE) as conn:

        async def _timed(i: int) -> float:
            started = time.monotonic()
            assert await conn.rpc(timeout=10).add(i, 1) == i + 1
            return time.monotonic() - started

        for _ in range(3):
            latencies = sorted(await asyncio.gather(*(_timed(i) for i in range(300))))
            assert latencies[-1] < 0.95, f"slowest call {latencies[-1]:.3f}s"


async def test_cancelled_call_reply_never_reaches_a_later_call(pool_service):
    """Cancel a call, let its reply arrive, then reuse every request id."""
    port, _ = pool_service
    async with _client(port, "aio-uuid-reuse", FRAGILE) as conn:
        proxy = conn.rpc(timeout=30)
        stale = asyncio.ensure_future(proxy.slow_echo("stale", 0.5))
        await asyncio.sleep(0.1)
        stale.cancel()
        with pytest.raises(asyncio.CancelledError):
            await stale
        await asyncio.sleep(1.0)  # the stale reply has arrived by now

        # Request ids are 16 bit: this walks every one of them.
        batch = 400
        for start in range(0, 65_600, batch):
            results = await asyncio.gather(*(proxy.echo(i) for i in range(start, start + batch)))
            for i, result in zip(range(start, start + batch), results):
                if result != i:
                    pytest.fail(f"call {i} got {result!r}")


async def test_reply_in_wrong_format_is_never_unpickled(free_port, tmp_path):
    from daffi import SerdeFormat
    from daffi.exceptions import RemoteCallError

    for flag_name in ("ERROR", "RESPONSE"):
        marker = tmp_path / f"unpickled-{flag_name}"
        proc = mp.Process(
            target=_proc_pickle_injector,
            args=(active_runtime(), free_port, str(marker), flag_name),
            daemon=True,
        )
        proc.start()
        try:
            wait_for_port(free_port, proc=proc)
            async with _client(free_port, f"aio-victim-{flag_name}", "aio-injector") as conn:
                with pytest.raises(RemoteCallError, match="does not match"):
                    await conn.rpc(timeout=10, serde=SerdeFormat.JSON).lookup("k")
            assert not marker.exists(), f"{flag_name} reply was unpickled"
        finally:
            quiet_kill(proc)


# ── 3. lifecycle ──────────────────────────────────────────────────────────────


async def test_evicted_client_does_not_take_its_name_back(router_port):
    from daffi.exceptions import Evicted

    worker = mp.Process(
        target=proc_worker, args=(active_runtime(), router_port, "aio-evict-worker"), daemon=True
    )
    worker.start()
    try:
        wait_for_members(router_port, {"aio-evict-worker"})
        async with _client(router_port, "aio-contested", "aio-evict-worker") as old_conn:
            async with _client(router_port, "aio-contested", "aio-evict-worker") as new_conn:

                async def _old_was_told() -> bool:
                    try:
                        await old_conn.rpc(timeout=5).add(1, 1)
                    except Evicted:
                        return True
                    return False

                await _wait_until(_old_was_told, 10, "the evicted client to raise Evicted")
                with pytest.raises(Evicted):
                    await old_conn.rpc(timeout=5).add(1, 1)

                for i in range(5):
                    assert await new_conn.rpc(timeout=5).add(i, 1) == i + 1
                    await asyncio.sleep(0.2)
    finally:
        quiet_kill(worker)


@pytest.mark.parametrize("workers", [1, 2], ids=["inline", "pool"])
async def test_callback_can_stop_its_own_client(router_port, workers):
    from daffi.exceptions import BaseException as DaffiError

    q = mp.Queue()
    proc = mp.Process(
        target=_proc_self_stopping_worker,
        args=(active_runtime(), router_port, workers, q),
        daemon=True,
    )
    proc.start()
    try:
        wait_for_members(router_port, {"aio-self-stopper"})
        async with _client(router_port, "aio-stop-requester", "aio-self-stopper") as conn:
            try:
                await conn.rpc(timeout=5).shutdown()
            except DaffiError:
                pass  # the reply may be lost with the connection
        result = await asyncio.get_running_loop().run_in_executor(None, q.get, True, 15)
        assert result == "joined"
        proc.join(10)
        assert proc.exitcode == 0
    finally:
        quiet_kill(proc)


@pytest.mark.parametrize("kind", ["service", "router"])
async def test_stop_closes_the_server_and_releases_join(free_port, kind):
    from daffi import TCPTransport
    from daffi.aio import AsyncRouter, AsyncService

    cls = AsyncService if kind == "service" else AsyncRouter
    app = cls(
        app_name=f"aio-stop-{kind}",
        transport=TCPTransport(HOST, free_port),
        runtime=active_runtime(),
    )
    await app.start()
    joiner = asyncio.ensure_future(app.join())
    await app.stop()
    await asyncio.wait_for(joiner, 5)
    with pytest.raises(OSError):
        socket.create_connection((HOST, free_port), timeout=1).close()


@pytest.mark.parametrize("workers", [1, 4], ids=["inline", "pool"])
@pytest.mark.parametrize("flavour", ["sync", "async"])
def test_stop_does_not_wait_for_a_running_callback(free_port, workers, flavour):
    """stop() used to await the running callback, and a sync one held the
    default executor, which ``asyncio.run`` waits for at exit."""
    rt = active_runtime()
    body = "time.sleep(60)" if flavour == "sync" else "await asyncio.sleep(60)"
    script = f"""
import asyncio, time
from daffi import TCPTransport, callback, dfcore
from daffi.aio import AsyncClient, AsyncService
dfcore.setRuntime({rt!r})

@callback
{"def" if flavour == "sync" else "async def"} stuck():
    {body}

async def _call(conn):
    try:
        await conn.rpc(timeout=120).stuck()
    except BaseException:
        pass

async def main():
    svc = AsyncService(app_name="aio-stuck-svc", transport=TCPTransport("127.0.0.1", {free_port}), workers={workers}, runtime={rt!r})
    await svc.start()
    client = AsyncClient(app_name="aio-stuck-caller", transport=TCPTransport("127.0.0.1", {free_port}), runtime={rt!r})
    conn = await client.connect()
    await conn.wait_for_members("aio-stuck-svc", timeout=10)
    call = asyncio.ensure_future(_call(conn))
    await asyncio.sleep(0.5)
    started = time.monotonic()
    await svc.stop()
    print(f"stopped in {{time.monotonic() - started:.3f}}", flush=True)
    await client.stop()
    await call

asyncio.run(main())
"""
    started = time.monotonic()
    code, output = _finish(_run_script(script))
    assert code == 0, output
    assert float(output.split("stopped in ")[1].split()[0]) < 1, output
    assert time.monotonic() - started < 15, output


# ── 4. signals ────────────────────────────────────────────────────────────────

_SERVICE_SCRIPT = """
import asyncio
from daffi import callback, TCPTransport, dfcore
from daffi.aio import AsyncService
dfcore.setRuntime({runtime!r})

@callback
async def ping():
    return "pong"

async def main():
    svc = AsyncService(app_name="aio-signal-target", transport=TCPTransport("127.0.0.1", {port}), runtime={runtime!r})
    await svc.start()
    print("started", flush=True)
    try:
        await svc.join()
        print("joined", flush=True)
    finally:
        print("finally", flush=True)

asyncio.run(main())
"""


def _service_script(port: int) -> subprocess.Popen:
    """Start the script and return once ``start()`` has returned in it."""
    proc = _run_script(_SERVICE_SCRIPT.format(runtime=active_runtime(), port=port))
    line = proc.stdout.readline().strip()
    if line != "started":
        proc.kill()
        _, err = proc.communicate()
        pytest.fail(f"service script did not start: {line!r}\n{err}")
    return proc


@pytest.mark.skipif(sys.platform == "win32", reason="POSIX signals")
class TestSignals:
    def test_sigint_stops_the_service_and_runs_finally(self, free_port):
        """Since 3.11 ``asyncio.run`` installs its own SIGINT handler before
        the service exists; daffi stops the service and then defers to it,
        so the program ends with the usual ``KeyboardInterrupt``.  Before
        3.11 there is none, and ``join()`` returns."""
        proc = _service_script(free_port)
        proc.send_signal(signal.SIGINT)
        code, output = _finish(proc)
        assert "finally" in output, output
        if sys.version_info >= (3, 11):
            assert code != 0 and "KeyboardInterrupt" in output, output
        else:
            assert code == 0 and "joined" in output, output

    def test_sigterm_terminates_with_the_signal(self, free_port):
        proc = _service_script(free_port)
        proc.send_signal(signal.SIGTERM)
        code, output = _finish(proc)
        assert code == -signal.SIGTERM, output
