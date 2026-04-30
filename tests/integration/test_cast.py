"""
Integration tests for cast() — blocking fan-out broadcast.

cast() sends a call to *all* registered workers that expose the requested
method and returns a ``{worker_name: result}`` dict.  cast_nowait() does the
same without waiting for responses.

Layout
------
Client → Router → N Workers
"""
from __future__ import annotations

import multiprocessing as mp
import time

import pytest

from .conftest import (
    HOST, TIMEOUT, wait_for_port, wait_for_members,
    silence_subprocess, quiet_kill, proc_router,
)

N_WORKERS = 5   # number of worker processes for cast tests


# ── subprocess entry points ───────────────────────────────────────────────────

def _worker(port: int, worker_id: int) -> None:
    silence_subprocess()
    import time as _time
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def identity(value: int) -> int:
        return value

    client = Client(
        app_name=f"cast-worker-{worker_id:02d}",
        host=HOST,
        port=port,
    )
    client.connect()
    try:
        while True:
            _time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def cast_setup(free_port):
    """Start Router + N_WORKERS worker subprocesses; yield the router port."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    worker_procs = []
    for i in range(N_WORKERS):
        p = mp.Process(target=_worker, args=(free_port, i), daemon=True)
        p.start()
        worker_procs.append(p)

    expected = {f"cast-worker-{i:02d}" for i in range(N_WORKERS)}
    wait_for_members(free_port, expected, timeout=15.0, probe_name="cast-setup-probe")

    yield free_port

    for p in worker_procs:
        quiet_kill(p)
    quiet_kill(rproc)


# ── tests ─────────────────────────────────────────────────────────────────────

class TestCastBroadcast:
    """cast() fan-out tests via Router → N Workers."""

    def _connect(self, port: int, name: str):
        from daffi import Client
        client = Client(app_name=name, host=HOST, port=port)
        conn = client.connect()
        return client, conn

    def test_cast_reaches_all_workers(self, cast_setup):
        """cast() returns one entry per worker."""
        client, conn = self._connect(cast_setup, "cast-caller-reach")
        try:
            results = conn.cast(timeout=TIMEOUT).echo("ping")
            assert isinstance(results, dict)
            assert len(results) == N_WORKERS
        finally:
            client.stop()

    def test_cast_all_values_correct(self, cast_setup):
        """Every worker echoes the payload unchanged."""
        client, conn = self._connect(cast_setup, "cast-caller-values")
        payload = {"test": "broadcast", "numbers": [1, 2, 3]}
        try:
            results = conn.cast(timeout=TIMEOUT).echo(payload)
            assert all(v == payload for v in results.values())
        finally:
            client.stop()

    def test_cast_worker_names_in_result(self, cast_setup):
        """Result keys are the worker app_names."""
        client, conn = self._connect(cast_setup, "cast-caller-names")
        try:
            results = conn.cast(timeout=TIMEOUT).echo("name-check")
            expected_names = {f"cast-worker-{i:02d}" for i in range(N_WORKERS)}
            assert set(results.keys()) == expected_names
        finally:
            client.stop()

    def test_cast_identity_int(self, cast_setup):
        """cast() with an integer argument."""
        client, conn = self._connect(cast_setup, "cast-caller-int")
        try:
            results = conn.cast(timeout=TIMEOUT).identity(99)
            assert all(v == 99 for v in results.values())
        finally:
            client.stop()

    def test_cast_string_payload(self, cast_setup):
        client, conn = self._connect(cast_setup, "cast-caller-str")
        try:
            results = conn.cast(timeout=TIMEOUT).echo("hello broadcast")
            assert len(results) == N_WORKERS
            assert all(v == "hello broadcast" for v in results.values())
        finally:
            client.stop()

    def test_cast_large_payload(self, cast_setup):
        """cast() works with a payload that is several KB."""
        client, conn = self._connect(cast_setup, "cast-caller-large")
        payload = list(range(5_000))
        try:
            results = conn.cast(timeout=TIMEOUT).echo(payload)
            assert len(results) == N_WORKERS
            assert all(v == payload for v in results.values())
        finally:
            client.stop()

    def test_cast_multiple_sequential_calls(self, cast_setup):
        """Same connection can cast() several times in a row."""
        client, conn = self._connect(cast_setup, "cast-caller-seq")
        try:
            for i in range(5):
                results = conn.cast(timeout=TIMEOUT).echo(i)
                assert len(results) == N_WORKERS
                assert all(v == i for v in results.values())
        finally:
            client.stop()

    def test_cast_nowait_does_not_raise(self, cast_setup):
        """cast_nowait() must not block or raise; it's fire-and-forget."""
        client, conn = self._connect(cast_setup, "cast-caller-nowait")
        try:
            # cast_nowait returns immediately with no result to check.
            conn.cast_nowait().echo("fire-and-forget")
            # Give workers a moment to process before teardown.
            time.sleep(0.1)
        finally:
            client.stop()

    def test_cast_targeted_single_worker(self, cast_setup):
        """cast(receiver=name) targets only one specific worker."""
        target = "cast-worker-00"
        client, conn = self._connect(cast_setup, "cast-caller-targeted")
        try:
            results = conn.cast(timeout=TIMEOUT, receiver=target).echo("targeted")
            assert set(results.keys()) == {target}
            assert results[target] == "targeted"
        finally:
            client.stop()
