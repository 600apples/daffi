"""
Integration tests for concurrent client access.

Scenarios
---------
1. Many threads share ONE Client connection, fire rpc() calls simultaneously.
2. Many independent Client connections fire rpc() calls simultaneously.
3. Same two scenarios via Router (two-hop path).

Each scenario verifies correctness (every echo returns the right value) rather
than throughput — that's the job of the perf benchmarks.
"""
from __future__ import annotations

import multiprocessing as mp
import threading

import pytest

from conftest import (
    HOST,
    TIMEOUT,
    wait_for_port,
    wait_for_members,
    silence_subprocess,
    quiet_kill,
)

N_THREADS         = 50    # concurrent callers per scenario
CALLS_PER_THREAD  = 20    # sequential calls inside each thread


# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_service(port: int) -> None:
    silence_subprocess()
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    svc = Service(app_name="conc-service", host=HOST, port=port, workers=16)
    svc.start()
    svc.join()


def _proc_router(port: int) -> None:
    silence_subprocess()
    from daffi import Router

    r = Router(app_name="conc-router", host=HOST, port=port)
    r.start()
    r.join()


def _proc_worker(port: int) -> None:
    silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    client = Client(app_name="conc-worker", host=HOST, port=port, workers=16)
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def conc_service(free_port):
    proc = mp.Process(target=_proc_service, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    # Deterministic — replaces a fixed sleep that occasionally raced
    # registration on slower CI runners.
    wait_for_members(free_port, {"conc-service"}, probe_name="_conc-svc-probe")
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def conc_router(free_port):
    rproc = mp.Process(target=_proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)
    wproc = mp.Process(target=_proc_worker, args=(free_port,), daemon=True)
    wproc.start()
    # Block until the router actually has the worker registered — without this
    # the test occasionally fires its first echo() before conc-worker has
    # finished its handshake, surfacing as ReceiverNotFound.
    wait_for_members(free_port, {"conc-worker"}, probe_name="_conc-rtr-probe")
    yield free_port
    quiet_kill(wproc)
    quiet_kill(rproc)


# ── Scenario 1: shared connection, many threads ────────────────────────────────

class TestSharedConnectionConcurrency:
    """N threads share one Client/connection; verify all rpc() results are correct."""

    def _shared_echo_threads(self, port: int, prefix: str) -> list[Exception]:
        from daffi import Client

        client = Client(app_name=f"{prefix}-shared", host=HOST, port=port)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT)

        errors: list[Exception] = []
        lock   = threading.Lock()
        barrier = threading.Barrier(N_THREADS)

        def _task(tid: int):
            barrier.wait(timeout=30)
            try:
                for k in range(CALLS_PER_THREAD):
                    payload = {"thread": tid, "call": k}
                    result  = proxy.echo(payload)
                    assert result == payload, f"t={tid} k={k}: got {result!r}"
            except Exception as exc:
                with lock:
                    errors.append(exc)

        threads = [threading.Thread(target=_task, args=(i,), daemon=True) for i in range(N_THREADS)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT + 20)
        client.stop()
        return errors

    def test_direct_shared_connection(self, conc_service):
        errors = self._shared_echo_threads(conc_service, "dir")
        assert not errors, f"{len(errors)} failure(s): {errors[:3]}"

    def test_router_shared_connection(self, conc_router):
        errors = self._shared_echo_threads(conc_router, "rtr")
        assert not errors, f"{len(errors)} failure(s): {errors[:3]}"


# ── Scenario 2: independent connections, many threads ─────────────────────────

class TestIndependentConnectionsConcurrency:
    """Each thread owns its own Client + connection."""

    def _independent_echo_threads(self, port: int, prefix: str) -> list[Exception]:
        errors: list[Exception] = []
        lock   = threading.Lock()
        barrier = threading.Barrier(N_THREADS)

        def _task(tid: int):
            from daffi import Client
            client = Client(app_name=f"{prefix}-ind-{tid:03d}", host=HOST, port=port)
            conn   = client.connect()
            proxy  = conn.rpc(timeout=TIMEOUT)
            barrier.wait(timeout=30)
            try:
                for k in range(CALLS_PER_THREAD):
                    payload = (tid, k)
                    result  = proxy.echo(payload)
                    assert list(result) == list(payload)
            except Exception as exc:
                with lock:
                    errors.append(exc)
            finally:
                client.stop()

        threads = [threading.Thread(target=_task, args=(i,), daemon=True) for i in range(N_THREADS)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT + 20)
        return errors

    def test_direct_independent_connections(self, conc_service):
        errors = self._independent_echo_threads(conc_service, "dir")
        assert not errors, f"{len(errors)} failure(s): {errors[:3]}"

    def test_router_independent_connections(self, conc_router):
        errors = self._independent_echo_threads(conc_router, "rtr")
        assert not errors, f"{len(errors)} failure(s): {errors[:3]}"


# ── Scenario 3: mixed arithmetic under concurrency ────────────────────────────

class TestConcurrentArithmetic:
    """Many threads call add() concurrently; assert exact numeric results."""

    def test_direct_concurrent_add(self, conc_service):
        from daffi import Client

        client = Client(app_name="conc-add-dir", host=HOST, port=conc_service)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT)

        results = [None] * N_THREADS
        errors: list[Exception] = []
        lock   = threading.Lock()
        barrier = threading.Barrier(N_THREADS)

        def _task(tid: int):
            barrier.wait(timeout=30)
            try:
                results[tid] = proxy.add(tid, tid)
            except Exception as exc:
                with lock:
                    errors.append(exc)

        threads = [threading.Thread(target=_task, args=(i,), daemon=True) for i in range(N_THREADS)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT + 10)
        client.stop()

        assert not errors
        for i, r in enumerate(results):
            if r is not None:
                assert r == i + i, f"add({i},{i}) = {r}"

    def test_router_concurrent_add(self, conc_router):
        from daffi import Client

        client = Client(app_name="conc-add-rtr", host=HOST, port=conc_router)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT)

        results = [None] * N_THREADS
        errors: list[Exception] = []
        lock   = threading.Lock()
        barrier = threading.Barrier(N_THREADS)

        def _task(tid: int):
            barrier.wait(timeout=30)
            try:
                results[tid] = proxy.add(tid, 1)
            except Exception as exc:
                with lock:
                    errors.append(exc)

        threads = [threading.Thread(target=_task, args=(i,), daemon=True) for i in range(N_THREADS)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT + 10)
        client.stop()

        assert not errors
        for i, r in enumerate(results):
            if r is not None:
                assert r == i + 1, f"add({i},1) = {r}"
