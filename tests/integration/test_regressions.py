"""
End-to-end regression tests for the review fixes.

Each test drives real processes over real sockets and fails on the behaviour
that used to happen:

* one failing callback (or serialisation, send, event handler) stopped the
  dispatcher for every connection in the process;
* Ctrl+C / SIGTERM ended the process with ``_exit(0)``, skipping ``finally``
  and hiding the signal from supervisors; a forked child ignored SIGTERM;
* a late response could reach a later call that reused the request id;
* waiting broke once descriptor numbers passed 1024;
* ``stop()`` raced sends, deadlocked against a server-initiated stop, and
  could not be called from inside a callback;
* a WebSocket ping disconnected the client;
* a peer that stops reading froze the server;
* concurrent callers lost wakeups;
* a peer could make a JSON caller unpickle data;
* an evicted client took its name back on the next call;
* a disconnect during a call surfaced as the wrong error;
* every automatic reconnect leaked descriptors.
"""

from __future__ import annotations
from tests.conftest import active_runtime

import base64
import multiprocessing as mp
import os
import signal
import socket
import struct
import subprocess
import sys
import threading
import time
from contextlib import contextmanager
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

ROOT = Path(__file__).resolve().parents[2]
FRAGILE = "fragile"


# ── subprocess targets ────────────────────────────────────────────────────────


def _proc_fragile_service(runtime: str, port: int, workers: int, explode_on_join: bool) -> None:
    """A Service whose callbacks (and, with *explode_on_join*, event handler)
    fail in every way the dispatcher used to die on."""
    silence_subprocess(runtime)
    import time as _time

    from daffi import Service, callback, TCPTransport

    class _Local:
        """Defined in a function, so pickle cannot find it by name."""

    @callback
    def unserializable_set():
        return {1, 2}

    @callback
    def unpicklable():
        return _Local()

    @callback
    def boom():
        raise ValueError("boom")

    @callback
    def reject(data):
        raise ValueError(f"rejected {len(data)} bytes")

    @callback
    async def coroutine_callback():
        return 1

    @callback
    def slow_echo(value, delay: float):
        _time.sleep(delay)
        return value

    @callback
    def slow_big(size: int, delay: float):
        _time.sleep(delay)
        return b"x" * size

    @callback
    def echo(value):
        return value

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    svc = Service(
        app_name=FRAGILE, workers=workers, transport=TCPTransport(HOST, port),
        runtime=runtime,
    )

    if explode_on_join:

        @svc.on_member_added
        def _explode(name):
            raise RuntimeError(f"event handler failure for {name}")

    svc.start()
    svc.join()


class _Booby:
    """Unpickling this creates *path*: proof that a payload was unpickled."""

    def __init__(self, path: str) -> None:
        self.path = path

    def __reduce__(self):
        return (open, (self.path, "w"))


def _proc_pickle_injector(runtime: str, port: int, marker: str, flag_name: str) -> None:
    """A Service that answers every call with a PICKLE payload, whatever the
    request format was."""
    silence_subprocess(runtime)
    import daffi._task_dispatcher as dispatcher
    from daffi import Service, callback, SerdeFormat, TCPTransport
    from daffi._bindings import MessageFlag
    from daffi._serialization import Serializer

    def _inject(result, flag, serde):
        data, is_bytes = Serializer.serialize(SerdeFormat.PICKLE, _Booby(marker))
        return data, is_bytes, getattr(MessageFlag, flag_name), SerdeFormat.PICKLE

    dispatcher._encode_reply = _inject

    @callback
    def lookup(key):
        return key

    svc = Service(app_name="injector", transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def _proc_self_stopping_worker(runtime: str, port: int, workers: int, q) -> None:
    """A Client whose callback stops the client it runs in."""
    silence_subprocess(runtime)
    from daffi import Client, callback, TCPTransport

    holder = {}

    @callback
    def shutdown():
        holder["client"].stop()

    client = Client(
        app_name="self-stopper", workers=workers, transport=TCPTransport(HOST, port),
        runtime=runtime,
    )
    holder["client"] = client
    client.connect()
    try:
        client.join()
        q.put("joined")
    except BaseException as exc:  # noqa: BLE001
        q.put(f"{type(exc).__name__}: {exc}")


def _proc_stalled_reader(runtime: str, port: int, calls: int, size: int, ready) -> None:
    """Ask for large replies, then freeze before any of them is ready."""
    silence_subprocess(runtime)
    from daffi import Client, TCPTransport

    client = Client(app_name="stalled-reader", transport=TCPTransport(HOST, port), runtime=runtime)
    conn = client.connect()
    conn.wait_for_members(FRAGILE, timeout=10)

    def _ask():
        try:
            conn.rpc(timeout=120).slow_big(size, 0.5)
        except BaseException:  # noqa: BLE001
            pass

    for _ in range(calls):
        threading.Thread(target=_ask, daemon=True).start()
    time.sleep(0.2)  # requests are on the wire; the replies are 0.3 s away
    ready.set()
    os.kill(os.getpid(), signal.SIGSTOP)
    time.sleep(120)


def _proc_high_descriptors(runtime: str, port: int, q) -> None:
    """Serve and call (sync and aio) with every daffi descriptor above 1024."""
    silence_subprocess(runtime)
    import asyncio
    import resource

    try:
        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
        want = 4096 if hard == resource.RLIM_INFINITY else min(4096, hard)
        if soft < want:
            resource.setrlimit(resource.RLIMIT_NOFILE, (want, hard))
        filler = [os.open(os.devnull, os.O_RDONLY) for _ in range(1100)]
        probe = os.open(os.devnull, os.O_RDONLY)
        os.close(probe)
        if probe < 1024:
            q.put(f"could not push descriptors past 1024 (got {probe})")
            return

        from daffi import Client, Service, callback, TCPTransport
        from daffi.aio import AsyncClient

        @callback
        def add(a: int, b: int) -> int:
            return a + b

        svc = Service(app_name="high-fd-service", transport=TCPTransport(HOST, port), runtime=runtime)
        svc.start()
        try:
            client = Client(app_name="high-fd-client", transport=TCPTransport(HOST, port), runtime=runtime)
            conn = client.connect()
            try:
                conn.wait_for_members("high-fd-service", timeout=10)
                for i in range(200):
                    assert conn.rpc(timeout=10).add(i, 1) == i + 1
            finally:
                client.stop()

            async def _aio():
                aclient = AsyncClient(
                    app_name="high-fd-aio", transport=TCPTransport(HOST, port), runtime=runtime
                )
                aconn = await aclient.connect()
                try:
                    await aconn.wait_for_members("high-fd-service", timeout=10)
                    for i in range(200):
                        assert await aconn.rpc(timeout=10).add(i, 2) == i + 2
                    results = await asyncio.gather(
                        *(aconn.rpc(timeout=10).add(i, 3) for i in range(200))
                    )
                    assert results == [i + 3 for i in range(200)]
                finally:
                    await aclient.stop()

            asyncio.run(asyncio.wait_for(_aio(), 60))
        finally:
            svc.stop()
        del filler
        q.put("ok")
    except BaseException as exc:  # noqa: BLE001
        q.put(f"{type(exc).__name__}: {exc}")


def _proc_stop_while_sending(runtime: str, port: int, q) -> None:
    """Stop a client while eight threads are sending on it."""
    silence_subprocess(runtime)
    from daffi import Client, TCPTransport
    from daffi.exceptions import BaseException as DaffiError

    try:
        for round_ in range(5):
            client = Client(
                app_name=f"stop-race-{round_}", transport=TCPTransport(HOST, port), runtime=runtime
            )
            conn = client.connect()
            conn.wait_for_members(FRAGILE, timeout=10)
            done = threading.Event()
            unexpected: list[str] = []

            def _hammer():
                while not done.is_set():
                    try:
                        conn.rpc(timeout=5).add(1, 2)
                    except DaffiError:
                        pass
                    except Exception as exc:  # noqa: BLE001
                        unexpected.append(f"{type(exc).__name__}: {exc}")
                        return

            threads = [threading.Thread(target=_hammer, daemon=True) for _ in range(8)]
            for t in threads:
                t.start()
            time.sleep(0.3)
            started = time.monotonic()
            client.stop()
            stop_took = time.monotonic() - started
            done.set()
            for t in threads:
                t.join(10)
            if any(t.is_alive() for t in threads):
                q.put(f"round {round_}: a sender is still blocked after stop()")
                return
            if unexpected:
                q.put(f"round {round_}: {unexpected[0]}")
                return
            if stop_took > 10:
                q.put(f"round {round_}: stop() took {stop_took:.1f}s")
                return
        q.put("ok")
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
    wait_for_port(port)
    wait_for_members(port, {FRAGILE})
    return proc


@contextmanager
def _client(port: int, name: str, *members: str):
    from daffi import Client, TCPTransport

    client = Client(app_name=name, transport=TCPTransport(HOST, port), runtime=active_runtime())
    conn = client.connect()
    try:
        if members:
            conn.wait_for_members(*members, timeout=10)
        yield conn
    finally:
        client.stop()


def _run_script(source: str) -> subprocess.Popen:
    env = dict(os.environ, PYTHONPATH=str(ROOT))
    return subprocess.Popen(
        [sys.executable, "-c", source],
        cwd=str(ROOT),
        env=env,
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


def _wait_until(predicate, timeout: float, what: str) -> None:
    deadline = time.monotonic() + timeout
    while not predicate():
        if time.monotonic() > deadline:
            pytest.fail(f"timed out waiting for {what}")
        time.sleep(0.05)


def _resume_and_kill(proc: mp.Process) -> None:
    if proc.pid is not None and proc.is_alive():
        os.kill(proc.pid, signal.SIGCONT)
        os.kill(proc.pid, signal.SIGKILL)
    proc.join(5)


# ── fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture(params=[1, 4], ids=["inline", "pool"])
def fragile_service(request, free_port):
    proc = _start_fragile(free_port, request.param)
    yield free_port, proc
    quiet_kill(proc)


@pytest.fixture
def inline_service(free_port):
    proc = _start_fragile(free_port, 1)
    yield free_port, proc
    quiet_kill(proc)


@pytest.fixture
def router_port(free_port):
    proc = mp.Process(target=proc_router, args=(active_runtime(), free_port), daemon=True)
    proc.start()
    wait_for_port(free_port)
    yield free_port
    quiet_kill(proc)


# ── 1. the dispatcher survives every kind of callback failure ─────────────────


class TestDispatcherSurvivesFailures:
    """Each failure must reach the caller as an error, quickly, and the
    service must keep serving afterwards."""

    def _assert_still_serves(self, conn) -> None:
        assert conn.rpc(timeout=10).add(20, 22) == 42

    def test_unserializable_result(self, fragile_service):
        from daffi import SerdeFormat
        from daffi.exceptions import RemoteCallError

        port, _ = fragile_service
        with _client(port, "disp-json", FRAGILE) as conn:
            started = time.monotonic()
            with pytest.raises(RemoteCallError):
                conn.rpc(timeout=10, serde=SerdeFormat.JSON).unserializable_set()
            assert time.monotonic() - started < 5
            self._assert_still_serves(conn)

    def test_unpicklable_result(self, fragile_service):
        from daffi.exceptions import RemoteCallError

        port, _ = fragile_service
        with _client(port, "disp-pickle", FRAGILE) as conn:
            started = time.monotonic()
            with pytest.raises(RemoteCallError):
                conn.rpc(timeout=10).unpicklable()
            assert time.monotonic() - started < 5
            self._assert_still_serves(conn)

    def test_raising_callback(self, fragile_service):
        from daffi.exceptions import RemoteCallError

        port, _ = fragile_service
        with _client(port, "disp-boom", FRAGILE) as conn:
            for _ in range(3):
                with pytest.raises(RemoteCallError, match="boom") as info:
                    conn.rpc(timeout=10).boom()
                assert type(info.value).__name__ == "ValueError"
            self._assert_still_serves(conn)

    def test_opaque_callback_error_is_reported(self, fragile_service):
        from daffi import SerdeFormat
        from daffi.exceptions import RemoteCallError

        port, _ = fragile_service
        with _client(port, "disp-opaque", FRAGILE) as conn:
            started = time.monotonic()
            with pytest.raises(RemoteCallError, match="rejected 5 bytes"):
                conn.rpc(timeout=10, serde=SerdeFormat.OPAQUE).reject(b"12345")
            assert time.monotonic() - started < 5
            self._assert_still_serves(conn)

    def test_async_def_callback_in_sync_service(self, fragile_service):
        from daffi.exceptions import RemoteCallError

        port, _ = fragile_service
        with _client(port, "disp-coro", FRAGILE) as conn:
            started = time.monotonic()
            with pytest.raises(RemoteCallError, match="daffi.aio"):
                conn.rpc(timeout=10).coroutine_callback()
            assert time.monotonic() - started < 5
            self._assert_still_serves(conn)

    def test_caller_gone_before_reply(self, fragile_service):
        from daffi import Client, TCPTransport

        port, _ = fragile_service
        gone = Client(app_name="disp-gone", transport=TCPTransport(HOST, port), runtime=active_runtime())
        gone_conn = gone.connect()
        gone_conn.wait_for_members(FRAGILE, timeout=10)

        def _abandon():
            try:
                gone_conn.rpc(timeout=10).slow_echo("late", 1.0)
            except BaseException:  # noqa: BLE001
                pass

        caller = threading.Thread(target=_abandon, daemon=True)
        caller.start()
        time.sleep(0.3)
        gone.stop()
        caller.join(10)
        time.sleep(1.2)  # the reply to the departed caller has been attempted

        with _client(port, "disp-after-gone", FRAGILE) as conn:
            self._assert_still_serves(conn)

    @pytest.mark.parametrize("workers", [1, 4], ids=["inline", "pool"])
    def test_failing_event_handler(self, free_port, workers):
        proc = _start_fragile(free_port, workers, explode_on_join=True)
        try:
            # Every connection fires the service's raising on_member_added handler.
            for i in range(3):
                with _client(free_port, f"disp-event-{i}", FRAGILE) as conn:
                    self._assert_still_serves(conn)
        finally:
            quiet_kill(proc)


# ── 2. errors during a call ───────────────────────────────────────────────────


def test_disconnect_during_call_raises_disconnected(fragile_service):
    from daffi.exceptions import Disconnected

    port, proc = fragile_service
    with _client(port, "mid-call-victim", FRAGILE) as conn:
        killer = threading.Timer(0.5, os.kill, args=(proc.pid, signal.SIGKILL))
        killer.start()
        started = time.monotonic()
        try:
            with pytest.raises(Disconnected):
                conn.rpc(timeout=30).slow_echo("never", 20)
        finally:
            killer.cancel()
        assert time.monotonic() - started < 10


def test_reply_in_wrong_format_is_never_unpickled(free_port, tmp_path):
    """A JSON caller must refuse a PICKLE reply, error or not, without
    loading it."""
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
            wait_for_port(free_port)
            with _client(free_port, f"victim-{flag_name}", "injector") as conn:
                with pytest.raises(RemoteCallError, match="does not match"):
                    conn.rpc(timeout=10, serde=SerdeFormat.JSON).lookup("k")
            assert not marker.exists(), f"{flag_name} reply was unpickled"
        finally:
            quiet_kill(proc)


def test_abandoned_call_reply_never_reaches_a_later_call(inline_service):
    """Interrupt a call, let its reply arrive, then reuse every request id."""
    port, _ = inline_service

    class _Interrupted(Exception):
        pass

    def _interrupt(signum, frame):
        raise _Interrupted()

    previous = signal.signal(signal.SIGALRM, _interrupt)
    try:
        with _client(port, "uuid-reuse", FRAGILE) as conn:
            proxy = conn.rpc(timeout=30)
            signal.setitimer(signal.ITIMER_REAL, 0.2)
            with pytest.raises(_Interrupted):
                proxy.slow_echo("stale", 0.5)
            time.sleep(1.0)  # the stale reply has arrived by now

            # Request ids are 16 bit: this walks every one of them.
            for i in range(65_600):
                result = proxy.echo(i)
                if result != i:
                    pytest.fail(f"call {i} got {result!r}")
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


def test_concurrent_callers_are_woken_promptly(inline_service):
    """Many threads waiting on one client: each response wakes its caller."""
    port, _ = inline_service
    latencies: list[float] = []
    lock = threading.Lock()
    errors: list[BaseException] = []

    with _client(port, "many-waiters", FRAGILE) as conn:
        barrier = threading.Barrier(32)

        def _caller(tid: int):
            mine = []
            try:
                barrier.wait(10)
                for k in range(40):
                    started = time.monotonic()
                    assert conn.rpc(timeout=10).add(tid, k) == tid + k
                    mine.append(time.monotonic() - started)
            except BaseException as exc:  # noqa: BLE001
                errors.append(exc)
            with lock:
                latencies.extend(mine)

        threads = [threading.Thread(target=_caller, args=(i,)) for i in range(32)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(60)

    assert not errors, errors[:3]
    latencies.sort()
    p99 = latencies[int(len(latencies) * 0.99)]
    # A lost wakeup used to cost a full 1 s polling slice.
    assert p99 < 0.5, f"p99 {p99:.3f}s"
    assert latencies[-1] < 0.95, f"slowest call {latencies[-1]:.3f}s"


# ── 3. descriptors ────────────────────────────────────────────────────────────


@pytest.mark.skipif(sys.platform == "win32", reason="POSIX descriptors")
def test_descriptors_above_1024(free_port):
    q = mp.Queue()
    proc = mp.Process(target=_proc_high_descriptors, args=(active_runtime(), free_port, q), daemon=True)
    proc.start()
    try:
        result = q.get(timeout=120)
    finally:
        quiet_kill(proc)
    assert result == "ok", result


def test_reconnects_do_not_leak_descriptors(free_port):
    proc = _start_fragile(free_port, 1)
    from daffi import Client, TCPTransport

    client = Client(app_name="reconnector", transport=TCPTransport(HOST, free_port), runtime=active_runtime())
    conn = client.connect()
    try:
        conn.wait_for_members(FRAGILE, timeout=10)
        baseline = None
        for round_ in range(6):
            quiet_kill(proc)
            proc.close()
            _wait_until(lambda: client._disconnected, 10, "the client to notice the disconnect")
            proc = _start_fragile(free_port, 1)
            assert conn.rpc(timeout=10).add(round_, 1) == round_ + 1
            if baseline is None:
                baseline = len(os.listdir("/dev/fd"))
        assert len(os.listdir("/dev/fd")) <= baseline + 2
    finally:
        client.stop()
        quiet_kill(proc)


def test_callback_registration_with_a_dead_client(inline_service):
    """Registering a callback re-announces it on every live client; a client
    whose server died must not turn that into an error."""
    from daffi import Client, TCPTransport, callback
    from daffi.registry._executor_registry import EXECUTOR_REGISTRY

    port, proc = inline_service
    client = Client(app_name="orphan", transport=TCPTransport(HOST, port), runtime=active_runtime())
    client.connect().wait_for_members(FRAGILE, timeout=10)
    try:
        quiet_kill(proc)
        _wait_until(lambda: client._disconnected, 10, "the client to notice the disconnect")

        @callback
        def registered_after_server_died():
            return None

    finally:
        EXECUTOR_REGISTRY.unregister("registered_after_server_died")
        client.stop()


# ── 4. stop() ─────────────────────────────────────────────────────────────────


def test_client_stop_while_threads_are_sending(inline_service):
    port, _ = inline_service
    q = mp.Queue()
    proc = mp.Process(target=_proc_stop_while_sending, args=(active_runtime(), port, q), daemon=True)
    proc.start()
    try:
        result = q.get(timeout=120)
    finally:
        quiet_kill(proc)
    assert result == "ok", result
    assert proc.exitcode is not None and proc.exitcode != -signal.SIGSEGV


def test_client_stop_racing_server_shutdown(free_port):
    """The server goes away while the user stops the client and another
    thread is parked in join(): nothing may deadlock."""
    from daffi import Client, TCPTransport

    for round_ in range(3):
        router = mp.Process(target=proc_router, args=(active_runtime(), free_port), daemon=True)
        router.start()
        wait_for_port(free_port)
        client = Client(app_name=f"race-{round_}", transport=TCPTransport(HOST, free_port), runtime=active_runtime())
        client.connect()

        joiner = threading.Thread(target=lambda: _swallow(client.join), daemon=True)
        joiner.start()
        time.sleep(0.1)
        router.terminate()
        stopper = threading.Thread(target=client.stop, daemon=True)
        stopper.start()
        stopper.join(15)
        joiner.join(15)
        router.join(10)
        assert not stopper.is_alive(), f"round {round_}: stop() deadlocked"
        assert not joiner.is_alive(), f"round {round_}: join() never returned"


def _swallow(fn) -> None:
    try:
        fn()
    except BaseException:  # noqa: BLE001
        pass


@pytest.mark.parametrize("workers", [1, 2], ids=["inline", "pool"])
def test_callback_can_stop_its_own_client(router_port, workers):
    from daffi.exceptions import BaseException as DaffiError

    q = mp.Queue()
    proc = mp.Process(
        target=_proc_self_stopping_worker,
        args=(active_runtime(), router_port, workers, q),
        daemon=True,
    )
    proc.start()
    try:
        wait_for_members(router_port, {"self-stopper"})
        with _client(router_port, "stop-requester", "self-stopper") as conn:
            try:
                conn.rpc(timeout=5).shutdown()
            except DaffiError:
                pass  # the reply may be lost with the connection
        assert q.get(timeout=15) == "joined"
        proc.join(10)
        assert proc.exitcode == 0
    finally:
        quiet_kill(proc)


# ── 5. signals ────────────────────────────────────────────────────────────────

_SERVICE_SCRIPT = """
import os, signal, sys
from daffi import Service, callback, TCPTransport, dfcore
dfcore.setRuntime({runtime!r})
{setup}

@callback
def ping():
    return "pong"

svc = Service(app_name="signal-target", transport=TCPTransport("127.0.0.1", {port}), runtime={runtime!r})
svc.start()
try:
    svc.join()
    print("joined", flush=True)
finally:
    print("finally", flush=True)
"""


def _service_script(port: int, setup: str = "") -> subprocess.Popen:
    proc = _run_script(_SERVICE_SCRIPT.format(runtime=active_runtime(), port=port, setup=setup))
    try:
        wait_for_port(port)
    except TimeoutError:
        proc.kill()
        raise
    return proc


@pytest.mark.skipif(sys.platform == "win32", reason="POSIX signals")
class TestSignals:
    def test_sigint_returns_from_join_and_runs_finally(self, free_port):
        proc = _service_script(free_port)
        proc.send_signal(signal.SIGINT)
        code, output = _finish(proc)
        assert code == 0, output
        assert "joined" in output and "finally" in output, output

    def test_sigterm_terminates_with_the_signal(self, free_port):
        proc = _service_script(free_port)
        proc.send_signal(signal.SIGTERM)
        code, output = _finish(proc)
        # It used to be _exit(0): a supervisor saw a clean exit.
        assert code == -signal.SIGTERM, output

    def test_user_handler_still_runs(self, free_port):
        setup = (
            "def _mine(signum, frame):\n"
            "    print('user handler', flush=True)\n"
            "    sys.exit(3)\n"
            "signal.signal(signal.SIGTERM, _mine)"
        )
        proc = _service_script(free_port, setup)
        proc.send_signal(signal.SIGTERM)
        code, output = _finish(proc)
        assert code == 3, output
        assert "user handler" in output and "finally" in output, output

    def test_sigint_interrupts_a_call_on_the_main_thread(self, inline_service):
        port, _ = inline_service
        script = f"""
from daffi import Client, TCPTransport, dfcore
dfcore.setRuntime({active_runtime()!r})
client = Client(app_name="sigint-caller", transport=TCPTransport("127.0.0.1", {port}), runtime={active_runtime()!r})
conn = client.connect()
conn.wait_for_members({FRAGILE!r}, timeout=10)
print("calling", flush=True)
try:
    conn.rpc(timeout=60).slow_echo(1, 30)
    print("returned", flush=True)
except BaseException as exc:
    print("raised", type(exc).__name__, flush=True)
"""
        proc = _run_script(script)
        assert proc.stdout.readline().strip() == "calling"
        time.sleep(0.5)
        started = time.monotonic()
        proc.send_signal(signal.SIGINT)
        code, output = _finish(proc)
        assert time.monotonic() - started < 5, output
        assert code == 0 and "raised" in output, output

    @pytest.mark.skipif(not hasattr(os, "fork"), reason="fork is POSIX-only")
    def test_forked_child_terminates_on_sigterm(self, free_port):
        child_port = free_port + 1 if free_port < 65000 else free_port - 1
        script = f"""
import multiprocessing as mp, socket, time
from daffi import Service, TCPTransport, dfcore
dfcore.setRuntime({active_runtime()!r})

def child(port):
    svc = Service(app_name="forked", transport=TCPTransport("127.0.0.1", port), runtime={active_runtime()!r})
    svc.start()
    svc.join()

parent = Service(app_name="parent", transport=TCPTransport("127.0.0.1", {free_port}), runtime={active_runtime()!r})
parent.start()
proc = mp.get_context("fork").Process(target=child, args=({child_port},), daemon=True)
proc.start()
deadline = time.monotonic() + 15
while True:
    try:
        socket.create_connection(("127.0.0.1", {child_port}), timeout=0.2).close()
        break
    except OSError:
        if time.monotonic() > deadline:
            raise
        time.sleep(0.05)
started = time.monotonic()
proc.terminate()
proc.join(10)
print("child exit", proc.exitcode, round(time.monotonic() - started, 1), flush=True)
if proc.exitcode is None:
    proc.kill()
parent.stop()
"""
        code, output = _finish(_run_script(script), timeout=40)
        assert code == 0, output
        assert f"child exit {-signal.SIGTERM}" in output, output


# ── 6. network ────────────────────────────────────────────────────────────────


def _recv_exact(sock: socket.socket, n: int) -> bytes:
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("closed")
        buf += chunk
    return buf


def _masked_frame(opcode: int, payload: bytes) -> bytes:
    mask = os.urandom(4)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    return bytes([0x80 | opcode, 0x80 | len(payload)]) + mask + masked


def _read_frame(sock: socket.socket) -> tuple[int, bytes]:
    first, second = _recv_exact(sock, 2)
    length = second & 0x7F
    if length == 126:
        (length,) = struct.unpack(">H", _recv_exact(sock, 2))
    elif length == 127:
        (length,) = struct.unpack(">Q", _recv_exact(sock, 8))
    return first & 0x0F, _recv_exact(sock, length)


def test_websocket_ping_is_answered_and_session_survives(inline_service):
    port, _ = inline_service
    key = base64.b64encode(os.urandom(16)).decode()
    upgrade = (
        "GET / HTTP/1.1\r\n"
        f"Host: {HOST}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    ).encode()
    with socket.create_connection((HOST, port), timeout=10) as sock:
        sock.sendall(upgrade)
        response = b""
        while b"\r\n\r\n" not in response:
            chunk = sock.recv(1024)
            assert chunk, "server closed during the upgrade"
            response += chunk
        assert b" 101 " in response.split(b"\r\n", 1)[0], response

        for payload in (b"first ping", b"second ping", b"third ping"):
            sock.sendall(_masked_frame(0x9, payload))
            for _ in range(5):
                opcode, data = _read_frame(sock)
                if opcode == 0xA:
                    break
            assert (opcode, data) == (0xA, payload)


def test_peer_that_stops_reading_does_not_freeze_the_service(fragile_service):
    """Replies to a frozen peer fill its socket; once the send stalls past
    its limit that peer is dropped and everyone else is served again."""
    port, _ = fragile_service
    ready = mp.Event()
    stalled = mp.Process(
        target=_proc_stalled_reader,
        args=(active_runtime(), port, 4, 16 * 1024 * 1024, ready),
        daemon=True,
    )
    stalled.start()
    try:
        assert ready.wait(20), "stalled reader never got going"
        time.sleep(1.0)  # its replies are being written by now
        with _client(port, "behind-stalled", FRAGILE) as conn:
            started = time.monotonic()
            assert conn.rpc(timeout=30).add(1, 1) == 2
            assert time.monotonic() - started < 20
    finally:
        _resume_and_kill(stalled)


# ── 7. eviction ───────────────────────────────────────────────────────────────


def test_evicted_client_does_not_take_its_name_back(free_port):
    """Two clients with one name: the older one learns it was evicted and
    stays out, so the two do not keep evicting each other."""
    from daffi import Client, TCPTransport
    from daffi.exceptions import Evicted

    router = mp.Process(target=proc_router, args=(active_runtime(), free_port), daemon=True)
    router.start()
    worker = None
    try:
        wait_for_port(free_port)
        worker = mp.Process(
            target=proc_worker, args=(active_runtime(), free_port, "evict-worker"), daemon=True
        )
        worker.start()
        wait_for_members(free_port, {"evict-worker"})

        def _connect():
            client = Client(app_name="contested", transport=TCPTransport(HOST, free_port), runtime=active_runtime())
            conn = client.connect()
            conn.wait_for_members("evict-worker", timeout=10)
            return client, conn

        old, old_conn = _connect()
        new, new_conn = _connect()
        try:
            def _old_was_told() -> bool:
                try:
                    old_conn.rpc(timeout=5).add(1, 1)
                except Evicted:
                    return True
                return False

            _wait_until(_old_was_told, 10, "the evicted client to raise Evicted")
            with pytest.raises(Evicted):
                old_conn.rpc(timeout=5).add(1, 1)

            for i in range(5):
                assert new_conn.rpc(timeout=5).add(i, 1) == i + 1
                time.sleep(0.2)
            assert not new._disconnected
        finally:
            old.stop()
            new.stop()
    finally:
        if worker is not None:
            quiet_kill(worker)
        quiet_kill(router)
