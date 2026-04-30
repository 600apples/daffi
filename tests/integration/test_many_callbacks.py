"""
Integration tests for services with many @callback functions.

A single Service registers 10 named callbacks (cb_0 … cb_9); each one
returns its own index.  Tests exercise:

  • Sequential calls to all callbacks
  • Concurrent calls from multiple threads hitting the same connection
  • Argument passing (echo + arithmetic)
  • Mixed concurrent calls interleaved across all callback names
"""
from __future__ import annotations

import multiprocessing as mp
import threading
import time

import pytest

from conftest import HOST, TIMEOUT, wait_for_port, wait_for_members, silence_subprocess, quiet_kill

N_CALLBACKS = 10   # must match the number defined in _proc_service_many


# ── subprocess: service with many named callbacks ──────────────────────────────

def _proc_service_many(port: int) -> None:
    """Start a Service that exposes cb_0 … cb_9, each returning its index."""
    silence_subprocess()
    from daffi import Service, callback

    # Define each callback with a unique __name__ so the registry records it
    # under the right key.  Using a factory avoids the late-binding closure trap.
    def _make_cb(idx: int):
        def fn():
            return idx
        fn.__name__     = f"cb_{idx}"
        fn.__qualname__ = f"cb_{idx}"
        return fn

    registered = [callback(_make_cb(i)) for i in range(N_CALLBACKS)]  # noqa: F841

    svc = Service(app_name="many-cb-svc", host=HOST, port=port)
    svc.start()
    svc.join()


# ── subprocess: service with argument-taking callbacks ─────────────────────────

def _proc_service_args(port: int) -> None:
    """Service with callbacks that take and transform arguments."""
    silence_subprocess()
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def multiply(a: int, b: int) -> int:
        return a * b

    @callback
    def concat(s1: str, s2: str) -> str:
        return s1 + s2

    @callback
    def sum_list(items: list) -> int:
        return sum(items)

    svc = Service(app_name="args-cb-svc", host=HOST, port=port, workers=8)
    svc.start()
    svc.join()


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def many_cb_service(free_port):
    proc = mp.Process(target=_proc_service_many, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"many-cb-svc"})
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def args_cb_service(free_port):
    proc = mp.Process(target=_proc_service_args, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"args-cb-svc"})
    yield free_port
    quiet_kill(proc)


# ── tests: named callbacks ─────────────────────────────────────────────────────

class TestManyNamedCallbacks:
    """Sequential and concurrent invocations of cb_0 … cb_N-1."""

    def _connect(self, port: int, name: str):
        from daffi import Client
        client = Client(app_name=name, host=HOST, port=port)
        conn   = client.connect()
        return client, conn

    def test_each_callback_sequential(self, many_cb_service):
        """Call every callback once, verify each returns its own index."""
        client, conn = self._connect(many_cb_service, "mc-seq")
        proxy = conn.rpc(timeout=TIMEOUT)
        try:
            for i in range(N_CALLBACKS):
                result = getattr(proxy, f"cb_{i}")()
                assert result == i, f"cb_{i} returned {result!r}, expected {i}"
        finally:
            client.stop()

    def test_each_callback_repeated(self, many_cb_service):
        """Call each callback multiple times; results must be stable."""
        client, conn = self._connect(many_cb_service, "mc-rep")
        proxy = conn.rpc(timeout=TIMEOUT)
        try:
            for _ in range(5):
                for i in range(N_CALLBACKS):
                    assert getattr(proxy, f"cb_{i}")() == i
        finally:
            client.stop()

    def test_concurrent_calls_same_connection(self, many_cb_service):
        """N threads share one connection, each fires one callback per thread."""
        client, conn = self._connect(many_cb_service, "mc-conc-single")
        proxy  = conn.rpc(timeout=TIMEOUT)
        errors: list[Exception] = []
        lock   = threading.Lock()

        def _call(idx: int) -> None:
            try:
                result = getattr(proxy, f"cb_{idx % N_CALLBACKS}")()
                assert result == idx % N_CALLBACKS
            except Exception as exc:
                with lock:
                    errors.append(exc)

        n_threads = 30
        threads = [threading.Thread(target=_call, args=(i,)) for i in range(n_threads)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT)

        client.stop()
        assert not errors, f"{len(errors)} thread(s) failed: {errors[:3]}"

    def test_concurrent_calls_separate_clients(self, many_cb_service):
        """Multiple independent clients concurrently call different callbacks."""
        results: list = [None] * N_CALLBACKS
        errors:  list[Exception] = []
        lock = threading.Lock()

        def _task(idx: int) -> None:
            from daffi import Client
            client = Client(
                app_name=f"mc-sep-{idx}", host=HOST, port=many_cb_service
            )
            conn = client.connect()
            try:
                result = getattr(conn.rpc(timeout=TIMEOUT), f"cb_{idx}")()
                with lock:
                    results[idx] = result
            except Exception as exc:
                with lock:
                    errors.append(exc)
            finally:
                client.stop()

        threads = [threading.Thread(target=_task, args=(i,)) for i in range(N_CALLBACKS)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT)

        assert not errors, f"Errors: {errors}"
        assert results == list(range(N_CALLBACKS))

    def test_interleaved_concurrent_calls(self, many_cb_service):
        """Each of N threads fires all N callbacks; total N² calls."""
        errors: list[Exception] = []
        lock = threading.Lock()

        def _task(thread_id: int) -> None:
            from daffi import Client
            client = Client(
                app_name=f"mc-intl-{thread_id}", host=HOST, port=many_cb_service
            )
            conn  = client.connect()
            proxy = conn.rpc(timeout=TIMEOUT)
            try:
                for i in range(N_CALLBACKS):
                    result = getattr(proxy, f"cb_{i}")()
                    if result != i:
                        with lock:
                            errors.append(AssertionError(f"cb_{i} → {result!r}"))
            finally:
                client.stop()

        n_threads = 8
        threads = [threading.Thread(target=_task, args=(j,)) for j in range(n_threads)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT)

        assert not errors, f"{len(errors)} failures: {errors[:3]}"


# ── tests: argument-taking callbacks ──────────────────────────────────────────

class TestCallbacksWithArguments:
    """Callbacks that take arguments and perform simple transformations."""

    def _proxy(self, port: int, name: str):
        from daffi import Client
        client = Client(app_name=name, host=HOST, port=port)
        conn   = client.connect()
        return client, conn.rpc(timeout=TIMEOUT)

    def test_multiply(self, args_cb_service):
        client, proxy = self._proxy(args_cb_service, "args-mul")
        assert proxy.multiply(6, 7) == 42
        assert proxy.multiply(0, 999) == 0
        assert proxy.multiply(-3, 4) == -12
        client.stop()

    def test_concat(self, args_cb_service):
        client, proxy = self._proxy(args_cb_service, "args-cat")
        assert proxy.concat("hello ", "world") == "hello world"
        assert proxy.concat("", "x") == "x"
        client.stop()

    def test_sum_list(self, args_cb_service):
        client, proxy = self._proxy(args_cb_service, "args-sum")
        assert proxy.sum_list([1, 2, 3, 4, 5]) == 15
        assert proxy.sum_list([]) == 0
        assert proxy.sum_list(list(range(100))) == 4950
        client.stop()

    def test_echo_various_types(self, args_cb_service):
        client, proxy = self._proxy(args_cb_service, "args-echo")
        for payload in [42, 3.14, "text", [1, 2], {"k": "v"}, None]:
            assert proxy.echo(payload) == payload
        client.stop()

    def test_concurrent_mixed_callbacks(self, args_cb_service):
        """Threads concurrently call different argument-taking callbacks."""
        errors: list[Exception] = []
        lock = threading.Lock()

        def _task(tid: int) -> None:
            from daffi import Client
            client = Client(
                app_name=f"args-conc-{tid}", host=HOST, port=args_cb_service
            )
            conn  = client.connect()
            proxy = conn.rpc(timeout=TIMEOUT)
            try:
                assert proxy.multiply(tid, 2) == tid * 2
                assert proxy.concat(str(tid), "!") == f"{tid}!"
                assert proxy.sum_list(list(range(tid + 1))) == tid * (tid + 1) // 2
            except Exception as exc:
                with lock:
                    errors.append(exc)
            finally:
                client.stop()

        threads = [threading.Thread(target=_task, args=(i,)) for i in range(20)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT)

        assert not errors, f"Errors: {errors}"
