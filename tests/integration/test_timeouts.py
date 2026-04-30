"""
Integration tests for timeout behaviour across all call styles.

Scenarios
---------
rpc()
  1. Slow callback — service takes longer than the timeout → TimeoutError.
  2. No service running — connect succeeds (router exists) but no worker →
     TransmissionFailure (no receivers), not a hang.
  3. timeout=0 (infinite) — slow callback eventually completes; no error.
  4. Multiple sequential rpc() calls after a timeout — connection still works.

cast()
  5. All workers slow — cast(timeout=N) raises TimeoutError.
  6. One worker slow, rest fast — partial result dict:
       fast workers → correct value
       slow worker  → TimeoutError instance (stored in the dict, not re-raised)
  7. cast_nowait() with slow workers — returns immediately, no timeout raised.

rpc_nowait()
  8. Fire-and-forget to a slow worker — returns immediately regardless of how
     long the callback takes.
"""
from __future__ import annotations

import multiprocessing as mp
import time

import pytest

from conftest import (
    HOST, TIMEOUT,
    wait_for_port, wait_for_members, silence_subprocess, quiet_kill,
    proc_router,
)

SLOW_SECS   = 3.0   # how long the "slow" callback sleeps
SHORT_TO    = 1     # timeout that will expire before SLOW_SECS
N_WORKERS   = 3     # workers for cast tests (1 slow, rest fast)


# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_slow_service(port: int) -> None:
    """Service whose ``slow`` callback sleeps for SLOW_SECS before returning."""
    silence_subprocess()
    import time as _t
    from daffi import Service, callback

    @callback
    def slow(payload):
        _t.sleep(SLOW_SECS)
        return payload

    @callback
    def fast(payload):
        return payload

    svc = Service(app_name="timeout-svc", host=HOST, port=port, workers=4)
    svc.start()
    svc.join()


def _proc_router_only(port: int) -> None:
    """Router with no workers attached — RPC calls will find no receivers."""
    silence_subprocess()
    from daffi import Router

    r = Router(app_name="timeout-router-only", host=HOST, port=port)
    r.start()
    r.join()


def _proc_fast_worker(port: int, worker_id: int) -> None:
    silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def work(payload):
        return payload

    client = Client(
        app_name=f"timeout-fast-worker-{worker_id:02d}",
        host=HOST, port=port,
    )
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def _proc_slow_worker(port: int, worker_id: int) -> None:
    silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def work(payload):
        _t.sleep(SLOW_SECS)
        return payload

    client = Client(
        app_name=f"timeout-slow-worker-{worker_id:02d}",
        host=HOST, port=port,
    )
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def _proc_all_slow_workers(port: int, n: int) -> None:
    """Spawn N slow workers in one process (simplifies fixture teardown)."""
    silence_subprocess()
    import threading
    import time as _t
    from daffi import Client, callback

    @callback
    def work(payload):
        _t.sleep(SLOW_SECS)
        return payload

    clients = []
    for i in range(n):
        c = Client(
            app_name=f"timeout-allslow-{i:02d}",
            host=HOST, port=port,
        )
        c.connect()
        clients.append(c)

    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        for c in clients:
            c.stop()


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def slow_service(free_port):
    """Direct Service with a slow callback."""
    proc = mp.Process(target=_proc_slow_service, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.2)
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def router_no_workers(free_port):
    """Router with no workers — all rpc() calls fail with TransmissionFailure."""
    proc = mp.Process(target=_proc_router_only, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.15)
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def cast_mixed(free_port):
    """Router + (N_WORKERS-1) fast workers + 1 slow worker."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    worker_procs = []
    for i in range(N_WORKERS - 1):
        p = mp.Process(target=_proc_fast_worker, args=(free_port, i), daemon=True)
        p.start()
        worker_procs.append(p)

    slow_p = mp.Process(target=_proc_slow_worker, args=(free_port, N_WORKERS - 1), daemon=True)
    slow_p.start()
    worker_procs.append(slow_p)

    # Deterministic wait: poll the router membership until every worker has
    # registered its callbacks.  Under spawn a fixed sleep is flaky because
    # subprocess startup times depend on system load from the rest of the
    # suite; wait_for_members removes the guesswork.
    expected = {f"timeout-fast-worker-{i:02d}" for i in range(N_WORKERS - 1)}
    expected.add(f"timeout-slow-worker-{N_WORKERS - 1:02d}")
    wait_for_members(free_port, expected, timeout=15.0, probe_name="to-cast-mixed-probe")

    yield free_port, slow_p  # expose slow proc so tests can name it

    for p in worker_procs:
        quiet_kill(p)
    quiet_kill(rproc)


@pytest.fixture
def cast_all_slow(free_port):
    """Router + N_WORKERS all-slow workers."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(
        target=_proc_all_slow_workers, args=(free_port, N_WORKERS), daemon=True
    )
    wproc.start()
    expected = {f"timeout-allslow-{i:02d}" for i in range(N_WORKERS)}
    wait_for_members(free_port, expected, timeout=15.0, probe_name="to-cast-allslow-probe")
    yield free_port

    quiet_kill(wproc)
    quiet_kill(rproc)


# ── rpc() timeout tests ───────────────────────────────────────────────────────

class TestRpcTimeout:

    def test_slow_callback_raises_timeout_error(self, slow_service):
        """rpc(timeout=SHORT_TO) on a callback that sleeps SLOW_SECS > SHORT_TO."""
        from daffi import Client

        client = Client(app_name="to-rpc-slow", host=HOST, port=slow_service)
        conn = client.connect()
        try:
            with pytest.raises(TimeoutError):
                conn.rpc(timeout=SHORT_TO).slow("hello")
        finally:
            client.stop()

    def test_timeout_measures_wall_clock(self, slow_service):
        """TimeoutError is raised near the requested timeout, not instantly or forever.

        Note: ``misc.timestamp()`` in the native layer truncates to integer seconds,
        so the effective wait can be anywhere in ``(0, SHORT_TO + 1]`` seconds
        depending on when within the second the call is made.  We only assert
        that the call didn't fail instantly (> 0.1 s) and didn't hang forever
        (< SHORT_TO + 2 s).
        """
        from daffi import Client

        client = Client(app_name="to-rpc-wall", host=HOST, port=slow_service)
        conn = client.connect()
        try:
            t0 = time.monotonic()
            with pytest.raises(TimeoutError):
                conn.rpc(timeout=SHORT_TO).slow("x")
            elapsed = time.monotonic() - t0
            assert elapsed > 0.1, (
                f"TimeoutError raised suspiciously fast ({elapsed:.3f}s)"
            )
            assert elapsed < SHORT_TO + 2.0, (
                f"TimeoutError raised far too late ({elapsed:.3f}s > {SHORT_TO + 2.0}s)"
            )
        finally:
            client.stop()

    def test_connection_works_after_timeout(self, slow_service):
        """After a TimeoutError the connection is still usable for fast calls."""
        from daffi import Client

        client = Client(app_name="to-rpc-recovery", host=HOST, port=slow_service)
        conn = client.connect()
        try:
            with pytest.raises(TimeoutError):
                conn.rpc(timeout=SHORT_TO).slow("discard")

            # fast callback must work immediately after
            result = conn.rpc(timeout=TIMEOUT).fast("ping")
            assert result == "ping"
        finally:
            client.stop()

    def test_multiple_timeouts_do_not_corrupt_store(self, slow_service):
        """Repeated TimeoutErrors from the same connection leave the store clean."""
        from daffi import Client

        client = Client(app_name="to-rpc-repeat", host=HOST, port=slow_service)
        conn = client.connect()
        try:
            for _ in range(3):
                with pytest.raises(TimeoutError):
                    conn.rpc(timeout=SHORT_TO).slow("x")

            # store must be clean: fast call still returns correct result
            result = conn.rpc(timeout=TIMEOUT).fast("after-timeouts")
            assert result == "after-timeouts"
        finally:
            client.stop()

    def test_no_receiver_raises_on_call(self, router_no_workers):
        """rpc() to a router with no workers raises immediately (no hang).

        The native layer raises ``ValueError("ReceiverNotFound")`` before
        ``system_exception_handler`` can rewrap it, so callers see either
        ``ValueError`` or ``TransmissionFailure`` depending on the code path.
        Either way the call must not hang.
        """
        from daffi import Client
        from daffi.exceptions import TransmissionFailure

        client = Client(app_name="to-rpc-norcv", host=HOST, port=router_no_workers)
        conn = client.connect()
        try:
            t0 = time.monotonic()
            with pytest.raises((ValueError, TransmissionFailure)):
                conn.rpc(timeout=TIMEOUT).echo("nobody home")
            elapsed = time.monotonic() - t0
            assert elapsed < 2.0, f"Call to empty router hung for {elapsed:.3f}s"
        finally:
            client.stop()

    def test_zero_timeout_waits_indefinitely(self, slow_service):
        """timeout=0 means no deadline; a slow callback eventually completes."""
        from daffi import Client

        client = Client(app_name="to-rpc-inf", host=HOST, port=slow_service)
        conn = client.connect()
        try:
            # timeout=0 → infinite; SLOW_SECS=3 so this must succeed
            result = conn.rpc(timeout=0).slow("infinite-wait")
            assert result == "infinite-wait"
        finally:
            client.stop()


# ── cast() timeout tests ──────────────────────────────────────────────────────

class TestCastTimeout:

    def test_all_workers_slow_result_dict_contains_timeout_errors(self, cast_all_slow):
        """cast(timeout=N) when every worker is slow:
        - the call itself does NOT raise (exceptions are stored in the dict)
        - every value in the result dict is a TimeoutError instance
        """
        from daffi import Client

        client = Client(app_name="to-cast-allslow", host=HOST, port=cast_all_slow)
        conn = client.connect()
        try:
            results = conn.cast(timeout=SHORT_TO).work("broadcast")

            assert isinstance(results, dict), (
                f"cast() must return a dict, got {type(results)}"
            )
            assert len(results) == N_WORKERS, (
                f"Expected {N_WORKERS} entries in result dict, got {len(results)}"
            )
            for name, val in results.items():
                assert isinstance(val, TimeoutError), (
                    f"Worker {name!r}: expected TimeoutError, got {val!r}"
                )
        finally:
            client.stop()

    def test_one_slow_worker_partial_result(self, cast_mixed):
        """cast(timeout=N) when one worker is slow:
        - fast workers' entries in the result dict contain the correct value
        - slow worker's entry contains a TimeoutError instance (not re-raised)
        - the call itself does NOT raise
        """
        from daffi import Client

        port, slow_proc = cast_mixed
        slow_name = f"timeout-slow-worker-{N_WORKERS - 1:02d}"

        client = Client(app_name="to-cast-mixed", host=HOST, port=port)
        conn = client.connect()
        try:
            results = conn.cast(timeout=SHORT_TO).work("payload")

            assert isinstance(results, dict), f"cast() must return a dict, got {type(results)}"
            assert slow_name in results, (
                f"Slow worker '{slow_name}' must appear in result dict.\n"
                f"Got keys: {list(results)}"
            )

            # slow worker's slot must hold a TimeoutError, not the value
            slow_val = results[slow_name]
            assert isinstance(slow_val, TimeoutError), (
                f"Expected TimeoutError for slow worker, got {slow_val!r}"
            )

            # all other workers must have returned the correct value
            fast_names = [k for k in results if k != slow_name]
            assert len(fast_names) == N_WORKERS - 1, (
                f"Expected {N_WORKERS - 1} fast workers, got {fast_names}"
            )
            for name in fast_names:
                assert results[name] == "payload", (
                    f"Fast worker {name!r} returned {results[name]!r}"
                )
        finally:
            client.stop()

    def test_cast_nowait_returns_immediately_with_slow_workers(self, cast_all_slow):
        """cast_nowait() must return without waiting regardless of worker speed."""
        from daffi import Client

        client = Client(app_name="to-castnw-slow", host=HOST, port=cast_all_slow)
        conn = client.connect()
        try:
            t0 = time.monotonic()
            conn.cast_nowait().work("fire-and-forget")
            elapsed = time.monotonic() - t0
            assert elapsed < 1.0, (
                f"cast_nowait() blocked for {elapsed:.3f}s on slow workers"
            )
        finally:
            client.stop()

    def test_cast_partial_result_connection_still_works(self, cast_mixed):
        """After a partial-timeout cast the connection is still usable."""
        from daffi import Client

        port, _ = cast_mixed
        client = Client(app_name="to-cast-alive", host=HOST, port=port)
        conn = client.connect()
        try:
            # first call: partial timeout (slow worker times out)
            results = conn.cast(timeout=SHORT_TO).work("first")
            assert isinstance(results, dict)

            # follow-up fast call to one worker must succeed
            fast_name = next(
                k for k in results
                if not isinstance(results[k], TimeoutError)
            )
            result = conn.rpc(timeout=TIMEOUT, receiver=fast_name).work("second")
            assert result == "second"
        finally:
            client.stop()


# ── rpc_nowait() timeout tests ────────────────────────────────────────────────

class TestRpcNowaitTimeout:

    def test_rpc_nowait_does_not_block_on_slow_service(self, slow_service):
        """rpc_nowait() to a slow callback returns immediately."""
        from daffi import Client

        client = Client(app_name="to-nw-nodly", host=HOST, port=slow_service)
        conn = client.connect()
        try:
            t0 = time.monotonic()
            conn.rpc_nowait().slow("fire-and-forget")
            elapsed = time.monotonic() - t0
            assert elapsed < 1.0, (
                f"rpc_nowait() blocked for {elapsed:.3f}s on slow service"
            )
        finally:
            client.stop()

    def test_rpc_after_rpc_nowait_to_slow_service(self, slow_service):
        """A blocking rpc(fast) after rpc_nowait(slow) must not be affected."""
        from daffi import Client

        client = Client(app_name="to-nw-then-rpc", host=HOST, port=slow_service)
        conn = client.connect()
        try:
            conn.rpc_nowait().slow("background")
            result = conn.rpc(timeout=TIMEOUT).fast("foreground")
            assert result == "foreground"
        finally:
            client.stop()
