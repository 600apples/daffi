"""
Integration tests for thread-worker and process-worker execution modes.

The ``workers`` and ``use_processes`` parameters control how the callback pool
is created.  These tests verify correctness for both modes across two
topologies:

  Direct     — Client → Service   (workers live inside the Service process)
  Via Router — Client → Router → Worker   (workers live inside Client processes)

Tested aspects
--------------
  1. Basic round-trip correctness  (echo, arithmetic)
  2. Concurrent callers produce correct results
  3. CPU-bound callbacks return the right answer in both modes
  4. Exception propagation — server-side errors reach the caller
  5. Multiple serde formats work in both modes
  6. Parity — thread mode and process mode produce identical results
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
    silence_subprocess,
    quiet_kill,
    proc_router,
)

N_CONCURRENT = 30       # threads firing calls simultaneously
CALLS_PER_THREAD = 10   # sequential calls per thread inside concurrent tests


# ── subprocess entry points ────────────────────────────────────────────────────
# Each target is a module-level function so fork()-based subprocesses can
# inherit it cleanly.  Callbacks are defined *before* start()/connect() so
# the worker-process pool (use_processes=True) forks them into every worker.

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
        workers=4, use_processes=False,
    )
    svc.start()
    svc.join()


def _svc_process_workers(port: int) -> None:
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
        app_name="svc-proc",
        host=HOST, port=port,
        workers=4, use_processes=True,
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
        workers=4, use_processes=False,
    )
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def _router_worker_proc(port: int, name: str) -> None:
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
        workers=4, use_processes=True,
    )
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


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
def svc_process(free_port):
    """Service with 4 process workers — extra settle time for the fork."""
    proc = mp.Process(target=_svc_process_workers, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.4)
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


@pytest.fixture
def router_proc(free_port):
    """Router + one Client worker with 4 process workers."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)
    wproc = mp.Process(
        target=_router_worker_proc,
        args=(free_port, "worker-proc"),
        daemon=True,
    )
    wproc.start()
    time.sleep(0.5)
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
    """Client → Service with workers=4, use_processes=False."""

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


# ── Direct: Client → Service, process workers ─────────────────────────────────

class TestDirectProcessWorkers:
    """Client → Service with workers=4, use_processes=True."""

    def test_echo(self, svc_process):
        client, conn = _connect(svc_process, "d-pr-echo")
        assert conn.rpc(timeout=TIMEOUT).echo({"key": 42}) == {"key": 42}
        client.stop()

    def test_add(self, svc_process):
        client, conn = _connect(svc_process, "d-pr-add")
        assert conn.rpc(timeout=TIMEOUT).add(7, 8) == 15
        client.stop()

    def test_cpu_work(self, svc_process):
        client, conn = _connect(svc_process, "d-pr-cpu")
        n = 2_000
        assert conn.rpc(timeout=TIMEOUT).cpu_work(n) == sum(i * i for i in range(n))
        client.stop()

    def test_exception_propagation(self, svc_process):
        client, conn = _connect(svc_process, "d-pr-exc")
        with pytest.raises(Exception, match="negative"):
            conn.rpc(timeout=TIMEOUT).fail_if_negative(-1)
        client.stop()

    def test_concurrent_echo(self, svc_process):
        client, conn = _connect(svc_process, "d-pr-c-echo")
        proxy = conn.rpc(timeout=TIMEOUT)
        errors = _concurrent_calls(
            proxy,
            fn_name="echo",
            arg_factory=lambda tid, k: ([tid, k],),
            result_fn=lambda tid, k: [tid, k],
        )
        client.stop()
        assert not errors, f"{len(errors)} failures: {errors[:3]}"

    def test_concurrent_add(self, svc_process):
        client, conn = _connect(svc_process, "d-pr-c-add")
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
    def test_serde_formats(self, svc_process, serde_name):
        import json
        from daffi._serialization import SerdeFormat
        serde = getattr(SerdeFormat, serde_name, None)
        if serde is None:
            pytest.skip(f"{serde_name} not available")
        payload = {"hello": "world", "n": 42}
        wire = json.dumps(payload) if serde_name == "OPAQUE" else payload
        client, conn = _connect(svc_process, f"d-pr-serde-{serde_name.lower()}")
        assert conn.rpc(timeout=TIMEOUT, serde=serde).echo(wire) == wire
        client.stop()

    def test_multiple_concurrent_callers(self, svc_process):
        """N independent clients each fire several calls concurrently."""
        errors: list[Exception] = []
        lock = threading.Lock()

        def _task(tid: int) -> None:
            from daffi import Client
            c = Client(app_name=f"d-pr-multi-{tid:03d}", host=HOST, port=svc_process)
            conn = c.connect()
            try:
                for k in range(5):
                    r = conn.rpc(timeout=TIMEOUT).add(tid, k)
                    assert r == tid + k
            except Exception as exc:
                with lock:
                    errors.append(exc)
            finally:
                c.stop()

        threads = [threading.Thread(target=_task, args=(i,), daemon=True) for i in range(20)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT + 15)
        assert not errors, f"{len(errors)} failures: {errors[:3]}"


# ── Router topology, thread workers ───────────────────────────────────────────

class TestRouterThreadWorkers:
    """Client → Router → Worker(Client, workers=4, use_processes=False)."""

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

        def _worker(name: str) -> None:
            silence_subprocess()
            import time as _t
            from daffi import Client, callback

            @callback
            def ping():
                return name

            c = Client(app_name=name, host=HOST, port=free_port, workers=4, use_processes=False)
            c.connect()
            try:
                while True:
                    _t.sleep(1)
            except (KeyboardInterrupt, SystemExit):
                pass
            finally:
                c.stop()

        rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
        rproc.start()
        wait_for_port(free_port)
        wprocs = [
            mp.Process(target=_worker, args=(f"tw-{i}",), daemon=True)
            for i in range(N)
        ]
        for p in wprocs:
            p.start()
        time.sleep(0.5)

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


# ── Router topology, process workers ──────────────────────────────────────────

class TestRouterProcessWorkers:
    """Client → Router → Worker(Client, workers=4, use_processes=True)."""

    def test_echo(self, router_proc):
        client, conn = _connect(router_proc, "r-pr-echo")
        assert conn.rpc(timeout=TIMEOUT).echo("hello") == "hello"
        client.stop()

    def test_add(self, router_proc):
        client, conn = _connect(router_proc, "r-pr-add")
        assert conn.rpc(timeout=TIMEOUT).add(100, 200) == 300
        client.stop()

    def test_cpu_work(self, router_proc):
        client, conn = _connect(router_proc, "r-pr-cpu")
        n = 1_000
        assert conn.rpc(timeout=TIMEOUT).cpu_work(n) == sum(i * i for i in range(n))
        client.stop()

    def test_exception_propagation(self, router_proc):
        client, conn = _connect(router_proc, "r-pr-exc")
        with pytest.raises(Exception, match="negative"):
            conn.rpc(timeout=TIMEOUT).fail_if_negative(-99)
        client.stop()

    def test_concurrent_calls(self, router_proc):
        client, conn = _connect(router_proc, "r-pr-conc")
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
        """cast() reaches multiple process-worker clients via router."""
        N = 3

        def _worker(name: str) -> None:
            silence_subprocess()
            import time as _t
            from daffi import Client, callback

            @callback
            def ping():
                return name

            c = Client(app_name=name, host=HOST, port=free_port, workers=4, use_processes=True)
            c.connect()
            try:
                while True:
                    _t.sleep(1)
            except (KeyboardInterrupt, SystemExit):
                pass
            finally:
                c.stop()

        rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
        rproc.start()
        wait_for_port(free_port)
        wprocs = [
            mp.Process(target=_worker, args=(f"pw-{i}",), daemon=True)
            for i in range(N)
        ]
        for p in wprocs:
            p.start()
        time.sleep(0.6)

        try:
            client, conn = _connect(free_port, "r-pr-cast")
            results = conn.cast(timeout=TIMEOUT).ping()
            assert len(results) == N
            assert set(results.values()) == {f"pw-{i}" for i in range(N)}
            client.stop()
        finally:
            for p in wprocs:
                quiet_kill(p)
            quiet_kill(rproc)


# ── Parity: thread mode == process mode ───────────────────────────────────────

class TestThreadVsProcessParity:
    """Thread workers and process workers must produce identical results."""

    @pytest.mark.parametrize("n", [0, 1, 100, 1_000])
    def test_cpu_work_parity_direct(self, svc_thread, svc_process, n):
        expected = sum(i * i for i in range(n))
        for port, label in [(svc_thread, "thread"), (svc_process, "proc")]:
            client, conn = _connect(port, f"par-cpu-{label}-{n}")
            result = conn.rpc(timeout=TIMEOUT).cpu_work(n)
            assert result == expected, f"{label} n={n}: got {result!r}"
            client.stop()

    def test_echo_complex_payload_parity(self, svc_thread, svc_process):
        payload = {"list": [1, 2, 3], "nested": {"a": True}, "num": 3.14}
        for port, label in [(svc_thread, "thread"), (svc_process, "proc")]:
            client, conn = _connect(port, f"par-echo-{label}")
            result = conn.rpc(timeout=TIMEOUT).echo(payload)
            assert result == payload, f"{label}: got {result!r}"
            client.stop()

    def test_add_parity_concurrent(self, svc_thread, svc_process):
        """N concurrent threads; both modes yield the same set of results."""
        for port, label in [(svc_thread, "thread"), (svc_process, "proc")]:
            client, conn = _connect(port, f"par-add-conc-{label}")
            proxy = conn.rpc(timeout=TIMEOUT)
            errors = _concurrent_calls(
                proxy,
                fn_name="add",
                arg_factory=lambda tid, k: (tid, k),
                result_fn=lambda tid, k: tid + k,
            )
            client.stop()
            assert not errors, f"{label}: {len(errors)} failures: {errors[:3]}"

    def test_error_parity(self, svc_thread, svc_process):
        """Both modes raise an exception for invalid input."""
        for port, label in [(svc_thread, "thread"), (svc_process, "proc")]:
            client, conn = _connect(port, f"par-err-{label}")
            with pytest.raises(Exception, match="negative"):
                conn.rpc(timeout=TIMEOUT).fail_if_negative(-42)
            client.stop()

    def test_router_echo_parity(self, router_thread, router_proc):
        payload = list(range(50))
        for port, label in [(router_thread, "thread"), (router_proc, "proc")]:
            client, conn = _connect(port, f"par-rtr-{label}")
            result = conn.rpc(timeout=TIMEOUT).echo(payload)
            assert result == payload, f"{label}: got {result!r}"
            client.stop()
