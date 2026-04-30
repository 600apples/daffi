"""
Integration test: cast() result grows as workers join dynamically.

Layout
------
Router → 1 worker  →  cast() returns dict with 1 key
       → 2 workers →  cast() returns dict with 2 keys
       → 3 workers →  cast() returns dict with 3 keys

The test verifies that:
  * cast() without an explicit receiver fans out to *all* peers that expose
    the requested method.
  * When a new worker joins, the next cast() sees it immediately.
  * Result keys are exactly the app_names of the connected workers.
"""
from __future__ import annotations

import multiprocessing as mp
import time

import pytest

from .conftest import (
    HOST, TIMEOUT,
    wait_for_port, wait_for_members,
    silence_subprocess, quiet_kill, proc_router,
)


# ── worker subprocess ─────────────────────────────────────────────────────────

def _process_worker(port: int, worker_id: int) -> None:
    """Worker that exposes a single 'process' callback."""
    silence_subprocess()
    import time as _time
    from daffi import Client, callback

    @callback
    def process(data):
        return {"result": data, "worker": worker_id}

    client = Client(
        app_name=f"dyn-worker-{worker_id}",
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


# ── fixture ───────────────────────────────────────────────────────────────────

@pytest.fixture
def router_only(free_port):
    """Start only the Router; workers are spawned inside the test body."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)
    yield free_port
    quiet_kill(rproc)


# ── helpers ───────────────────────────────────────────────────────────────────

def _spawn_worker(port: int, worker_id: int) -> mp.Process:
    p = mp.Process(target=_process_worker, args=(port, worker_id), daemon=True)
    p.start()
    return p


# ── tests ─────────────────────────────────────────────────────────────────────

class TestDynamicCast:
    """cast() fan-out grows as workers join one at a time."""

    def test_cast_grows_1_to_3_workers(self, router_only):
        """
        Start with 1 worker, verify 1 key.
        Add a 2nd worker, verify 2 keys.
        Add a 3rd worker, verify 3 keys.
        Keys must be exactly the worker app_names.
        """
        from daffi import Client

        client = Client(app_name="dyn-caller", host=HOST, port=router_only)
        conn = client.connect()
        workers: list[mp.Process] = []

        try:
            payload = {"x": 1}

            # ── 1 worker ──────────────────────────────────────────────────────
            workers.append(_spawn_worker(router_only, 1))
            conn.wait_for_members("dyn-worker-1", timeout=15)

            results = conn.cast(timeout=TIMEOUT).process(payload)
            assert isinstance(results, dict), "cast must return a dict"
            assert set(results.keys()) == {"dyn-worker-1"}, (
                f"expected 1 key, got: {set(results.keys())}"
            )

            # ── 2 workers ─────────────────────────────────────────────────────
            workers.append(_spawn_worker(router_only, 2))
            conn.wait_for_members("dyn-worker-2", timeout=15)

            results = conn.cast(timeout=TIMEOUT).process(payload)
            assert set(results.keys()) == {"dyn-worker-1", "dyn-worker-2"}, (
                f"expected 2 keys, got: {set(results.keys())}"
            )

            # ── 3 workers ─────────────────────────────────────────────────────
            workers.append(_spawn_worker(router_only, 3))
            conn.wait_for_members("dyn-worker-3", timeout=15)

            results = conn.cast(timeout=TIMEOUT).process(payload)
            assert set(results.keys()) == {
                "dyn-worker-1", "dyn-worker-2", "dyn-worker-3"
            }, f"expected 3 keys, got: {set(results.keys())}"

        finally:
            client.stop()
            for p in workers:
                quiet_kill(p)

    def test_cast_result_values_correct(self, router_only):
        """Every worker's response contains the right worker id in the value."""
        from daffi import Client

        client = Client(app_name="dyn-caller-vals", host=HOST, port=router_only)
        conn = client.connect()
        workers: list[mp.Process] = []

        try:
            for wid in (1, 2, 3):
                workers.append(_spawn_worker(router_only, wid))
                conn.wait_for_members(f"dyn-worker-{wid}", timeout=15)

            results = conn.cast(timeout=TIMEOUT).process("hello")
            assert len(results) == 3

            for name, val in results.items():
                expected_id = int(name.split("-")[-1])
                assert val["worker"] == expected_id, (
                    f"{name}: expected worker={expected_id}, got {val}"
                )
                assert val["result"] == "hello"

        finally:
            client.stop()
            for p in workers:
                quiet_kill(p)
