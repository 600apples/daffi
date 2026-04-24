"""
Integration tests for the thread-worker execution mode.

The ``workers`` parameter controls how the callback pool is created.  These
tests verify correctness across two topologies:

  Direct     — Client → Service   (workers live inside the Service process)
  Via Router — Client → Router → Worker   (workers live inside Client processes)

Tested aspects
--------------
  1. Basic round-trip correctness  (echo, arithmetic)
  2. Concurrent callers produce correct results
  3. CPU-bound callbacks return the right answer
  4. Exception propagation — server-side errors reach the caller
  5. Multiple serde formats work correctly
"""
from __future__ import annotations

import threading
import time
import multiprocessing as mp

import pytest

from conftest import (
    HOST,
    TIMEOUT,
    wait_for_port,
    wait_for_members,
    silence_subprocess,
    quiet_kill,
    proc_router,
)

N_CONCURRENT = 30       # threads firing calls simultaneously
CALLS_PER_THREAD = 10   # sequential calls per thread inside concurrent tests


# ── subprocess entry points ────────────────────────────────────────────────────
# Each target is a module-level function so the ``spawn`` start method can
# pickle it by (module, qualname) and re-import it in the fresh child.

def _svc_thread_workers(port: int) -> None:
    silence_subprocess()
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    @callback
    def cpu_work(n: int) -> int:
        return sum(i * i for i in range(n))

    @callback
    def fail_if_negative(x: int) -> int:
        if x < 0:
            raise ValueError(f"negative: {x}")
        return x

    svc = Service(
        app_name="svc-thread",
        host=HOST, port=port,
        workers=4,
    )
    svc.start()
    svc.join()


def _router_worker_thread(port: int, name: str) -> None:
    silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    @callback
    def cpu_work(n: int) -> int:
        return sum(i * i for i in range(n))

    @callback
    def fail_if_negative(x: int) -> int:
        if x < 0:
            raise ValueError(f"negative: {x}")
        return x

    client = Client(
        app_name=name,
        host=HOST, port=port,
        workers=4,
    )
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def _ping_worker(port: int, name: str) -> None:
    """Worker for test_multiple_workers_cast — defined at module level so it is
    picklable by the ``spawn`` start method."""
    silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def ping():
        return name

    c = Client(app_name=name, host=HOST, port=port, workers=4)
    c.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        c.stop()


# ── fixtures ───────────────────────────────────────────────────────────────────

@pytest.fixture
def svc_thread(free_port):
    """Service with 4 thread workers."""
    proc = mp.Process(target=_svc_thread_workers, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.2)
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def router_thread(free_port):
    """Router + one Client worker with 4 thread workers."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)
    wproc = mp.Process(
        target=_router_worker_thread,
        args=(free_port, "worker-thread"),
        daemon=True,
    )
    wproc.start()
    time.sleep(0.4)
    yield free_port
    quiet_kill(wproc)
    quiet_kill(rproc)


# ── shared helper ──────────────────────────────────────────────────────────────

def _connect(port: int, name: str):
    """Create a Client, connect, and return (client, conn)."""
    from daffi import Client
    client = Client(app_name=name, host=HOST, port=port)
    return client, client.connect()


def _concurrent_calls(proxy, fn_name: str, arg_factory, result_fn):
    """Fire N_CONCURRENT threads all calling *fn_name*; assert *result_fn* per result."""
    errors: list[Exception] = []
    lock = threading.Lock()
    barrier = threading.Barrier(N_CONCURRENT)

    def _task(tid: int) -> None:
        barrier.wait(timeout=30)
        try:
            for k in range(CALLS_PER_THREAD):
                args = arg_factory(tid, k)
                result = getattr(proxy, fn_name)(*args)
                expected = result_fn(tid, k)
                assert result == expected, (
                    f"tid={tid} k={k}: {fn_name}({args}) → {result!r}, expected {expected!r}"
                )
        except Exception as exc:
            with lock:
                errors.append(exc)

    threads = [threading.Thread(target=_task, args=(i,), daemon=True) for i in range(N_CONCURRENT)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=TIMEOUT + 30)
    return errors


# ── Direct: Client → Service, thread workers ──────────────────────────────────

class TestDirectThreadWorkers:
    """Client → Service with workers=4."""

    def test_echo(self, svc_thread):
        client, conn = _connect(svc_thread, "d-th-echo")
        assert conn.rpc(timeout=TIMEOUT).echo({"key": 42}) == {"key": 42}
        client.stop()

    def test_add(self, svc_thread):
        client, conn = _connect(svc_thread, "d-th-add")
        assert conn.rpc(timeout=TIMEOUT).add(7, 8) == 15
        client.stop()

    def test_cpu_work(self, svc_thread):
        client, conn = _connect(svc_thread, "d-th-cpu")
        n = 2_000
        assert conn.rpc(timeout=TIMEOUT).cpu_work(n) == sum(i * i for i in range(n))
        client.stop()

    def test_exception_propagation(self, svc_thread):
        client, conn = _connect(svc_thread, "d-th-exc")
        with pytest.raises(Exception, match="negative"):
            conn.rpc(timeout=TIMEOUT).fail_if_negative(-1)
        client.stop()

    def test_concurrent_echo(self, svc_thread):
        client, conn = _connect(svc_thread, "d-th-c-echo")
        proxy = conn.rpc(timeout=TIMEOUT)
        errors = _concurrent_calls(
            proxy,
            fn_name="echo",
            arg_factory=lambda tid, k: ([tid, k],),
            result_fn=lambda tid, k: [tid, k],
        )
        client.stop()
        assert not errors, f"{len(errors)} failures: {errors[:3]}"

    def test_concurrent_add(self, svc_thread):
        client, conn = _connect(svc_thread, "d-th-c-add")
        proxy = conn.rpc(timeout=TIMEOUT)
        errors = _concurrent_calls(
            proxy,
            fn_name="add",
            arg_factory=lambda tid, k: (tid, k),
            result_fn=lambda tid, k: tid + k,
        )
        client.stop()
        assert not errors, f"{len(errors)} failures: {errors[:3]}"

    @pytest.mark.parametrize("serde_name", ["PICKLE", "JSON", "OPAQUE"])
    def test_serde_formats(self, svc_thread, serde_name):
        import json
        from daffi._serialization import SerdeFormat
        serde = getattr(SerdeFormat, serde_name, None)
        if serde is None:
            pytest.skip(f"{serde_name} not available")
        payload = {"hello": "world", "n": 42}
        wire = json.dumps(payload) if serde_name == "OPAQUE" else payload
        client, conn = _connect(svc_thread, f"d-th-serde-{serde_name.lower()}")
        assert conn.rpc(timeout=TIMEOUT, serde=serde).echo(wire) == wire
        client.stop()

    def test_workers_count_inline_baseline(self, free_port):
        """workers=1 (inline) still processes requests correctly."""
        proc = mp.Process(
            target=_svc_thread_workers, args=(free_port,), daemon=True
        )
        proc.start()
        wait_for_port(free_port)
        time.sleep(0.15)
        try:
            client, conn = _connect(free_port, "d-th-inline")
            assert conn.rpc(timeout=TIMEOUT).add(1, 2) == 3
            client.stop()
        finally:
            quiet_kill(proc)


# ── Router topology, thread workers ───────────────────────────────────────────

class TestRouterThreadWorkers:
    """Client → Router → Worker(Client, workers=4)."""

    def test_echo(self, router_thread):
        client, conn = _connect(router_thread, "r-th-echo")
        assert conn.rpc(timeout=TIMEOUT).echo("hello") == "hello"
        client.stop()

    def test_add(self, router_thread):
        client, conn = _connect(router_thread, "r-th-add")
        assert conn.rpc(timeout=TIMEOUT).add(100, 200) == 300
        client.stop()

    def test_cpu_work(self, router_thread):
        client, conn = _connect(router_thread, "r-th-cpu")
        n = 1_000
        assert conn.rpc(timeout=TIMEOUT).cpu_work(n) == sum(i * i for i in range(n))
        client.stop()

    def test_exception_propagation(self, router_thread):
        client, conn = _connect(router_thread, "r-th-exc")
        with pytest.raises(Exception, match="negative"):
            conn.rpc(timeout=TIMEOUT).fail_if_negative(-99)
        client.stop()

    def test_concurrent_calls(self, router_thread):
        client, conn = _connect(router_thread, "r-th-conc")
        proxy = conn.rpc(timeout=TIMEOUT)
        errors = _concurrent_calls(
            proxy,
            fn_name="add",
            arg_factory=lambda tid, k: (tid, k),
            result_fn=lambda tid, k: tid + k,
        )
        client.stop()
        assert not errors, f"{len(errors)} failures: {errors[:3]}"

    def test_multiple_workers_cast(self, free_port):
        """cast() reaches multiple thread-worker clients via router."""
        N = 3

        rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
        rproc.start()
        wait_for_port(free_port)
        wprocs = [
            mp.Process(target=_ping_worker, args=(free_port, f"tw-{i}"), daemon=True)
            for i in range(N)
        ]
        for p in wprocs:
            p.start()
        expected = {f"tw-{i}" for i in range(N)}
        wait_for_members(free_port, expected, timeout=15.0, probe_name="tw-cast-probe")

        try:
            client, conn = _connect(free_port, "r-th-cast")
            results = conn.cast(timeout=TIMEOUT).ping()
            assert len(results) == N
            assert set(results.values()) == {f"tw-{i}" for i in range(N)}
            client.stop()
        finally:
            for p in wprocs:
                quiet_kill(p)
            quiet_kill(rproc)
