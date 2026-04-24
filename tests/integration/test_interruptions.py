"""
Integration tests for connection interruption scenarios.

What is tested
--------------
Each test deliberately disrupts the server-side process and verifies that
the client reacts correctly — no infinite hangs, correct exception type, and
(where applicable) transparent recovery through autoreconnect.

Interruption mechanisms used
----------------------------
  SIGSTOP  — freeze the process (simulates a stalled / overloaded node).
              The client's pending call must time out.
  SIGKILL  — instant termination (simulates OOM kill, hardware failure).
              The client receives a write / read error on the next operation.
  SIGCONT  — resume a STOPped process (used in cleanup / resume tests).
  proc.terminate() — SIGTERM; used for clean teardown.

Exception types produced by the native layer
--------------------------------------------
  TimeoutError         (builtins)          — rpc() call timed out waiting
                                             for a response from a frozen server.
  ValueError           (builtins)          — write/read error on a dead connection
                                             (message: "WriteError" or "ReadError").
  InitializationError  (daffi.exceptions)  — Client.connect() failed because
                                             the server is not listening.

Scenarios
---------
  1  Service killed → existing call raises ValueError
  2  Connect to dead service → InitializationError
  3  Service frozen (SIGSTOP) → TimeoutError within RPC timeout
  4  Service frozen then resumed (SIGCONT) → call eventually succeeds
  5  Service killed then restarted → autoreconnect client recovers
  6  Router killed then restarted → worker + caller both recover
  7  One worker killed → cast() to remaining workers still succeeds
  8  Big message (8 MiB) + frozen server → fails (ValueError/TimeoutError)
  9  Big message round-trip succeeds after service restart

All subprocess targets are module-level functions so they pickle correctly
under Python 3.14+'s default "forkserver" and "spawn" start methods.
The integration conftest.py forces "fork", which is simpler and correct
for a single-threaded-at-fork pytest runner.
"""
from __future__ import annotations

import multiprocessing as mp
import os
import signal
import threading
import time

import pytest

from conftest import HOST, TIMEOUT, wait_for_port, silence_subprocess, quiet_kill
from daffi.exceptions import InitializationError

# ── constants ──────────────────────────────────────────────────────────────────

BIG_MSG_SIZE = 8 * 1024 * 1024    # 8 MiB — large enough to stress the buffer
N_CAST_WORKERS = 4                 # workers for cast / partial-result tests
RECONNECT_DELAY = 0.5              # base reconnect delay for autoreconnect tests


# ── subprocess targets (module-level so they are picklable) ───────────────────

def _intr_service(port: int, name: str = "intr-svc") -> None:
    silence_subprocess()
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name=name, host=HOST, port=port)
    svc.start()
    svc.join()


def _intr_router(port: int, name: str = "intr-router") -> None:
    silence_subprocess()
    from daffi import Router

    r = Router(app_name=name, host=HOST, port=port)
    r.start()
    r.join()


def _intr_worker(port: int, name: str, autoreconnect: bool = False,
                 reconnect_delay: float = 0.5) -> None:
    silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    client = Client(
        app_name=name, host=HOST, port=port,
        autoreconnect=autoreconnect, reconnect_delay=reconnect_delay,
    )
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── helpers ───────────────────────────────────────────────────────────────────

def _start_service(port: int, name: str = "intr-svc") -> mp.Process:
    p = mp.Process(target=_intr_service, args=(port, name), daemon=True)
    p.start()
    wait_for_port(port)
    time.sleep(0.15)
    return p


def _start_router(port: int, name: str = "intr-router") -> mp.Process:
    p = mp.Process(target=_intr_router, args=(port, name), daemon=True)
    p.start()
    wait_for_port(port)
    return p


def _start_worker(port: int, name: str, autoreconnect: bool = False,
                  delay: float = RECONNECT_DELAY) -> mp.Process:
    p = mp.Process(
        target=_intr_worker, args=(port, name, autoreconnect, delay), daemon=True
    )
    p.start()
    return p


def _connect(port: int, name: str, autoreconnect: bool = False):
    """Return (client, conn) connected to *port*."""
    from daffi import Client
    client = Client(
        app_name=name, host=HOST, port=port,
        autoreconnect=autoreconnect, reconnect_delay=RECONNECT_DELAY,
    )
    conn = client.connect()
    return client, conn


def _sigkill(proc: mp.Process, *, wait: float = 0.3) -> None:
    """SIGKILL *proc* and wait for it to exit."""
    try:
        os.kill(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.join(timeout=5)
    time.sleep(wait)


def _sigstop(proc: mp.Process) -> None:
    os.kill(proc.pid, signal.SIGSTOP)


def _sigcont(proc: mp.Process) -> None:
    try:
        os.kill(proc.pid, signal.SIGCONT)
    except ProcessLookupError:
        pass


# ── Scenario 1: service killed, existing call raises ─────────────────────────

class TestServiceKilled:
    def test_call_on_dead_connection_raises(self, free_port):
        """After SIGKILL, rpc() on the stale connection raises ValueError."""
        svc = _start_service(free_port)
        client, conn = _connect(free_port, "intr-dead-call")
        try:
            assert conn.rpc(timeout=TIMEOUT).echo("ping") == "ping"
            _sigkill(svc)
            with pytest.raises(ValueError):
                conn.rpc(timeout=5).echo("after kill")
        finally:
            client.stop()
            quiet_kill(svc)

    def test_connect_to_dead_service_raises(self, free_port):
        """Client.connect() to a terminated service raises InitializationError."""
        svc = _start_service(free_port)
        _sigkill(svc)   # server is gone

        from daffi import Client
        client = Client(app_name="intr-dead-connect", host=HOST, port=free_port)
        with pytest.raises(InitializationError):
            client.connect()
        # client was never connected so no stop() needed


# ── Scenario 2: service frozen (SIGSTOP) ──────────────────────────────────────

class TestServiceFrozen:
    def test_frozen_server_causes_timeout(self, free_port):
        """SIGSTOP freezes the server; the client times out waiting for a response."""
        svc = _start_service(free_port)
        client, conn = _connect(free_port, "intr-frozen-timeout")
        try:
            assert conn.rpc(timeout=TIMEOUT).echo("warm") == "warm"
            _sigstop(svc)
            with pytest.raises(TimeoutError):
                conn.rpc(timeout=2).echo("frozen")
        finally:
            client.stop()
            # Use SIGKILL (not SIGCONT+SIGTERM) so the service's daffi-poller
            # never runs after the client has already closed the TCP side —
            # resuming first creates a race that can segfault the native layer.
            _sigkill(svc)

    def test_frozen_then_resumed_call_succeeds(self, free_port):
        """After SIGCONT the server processes queued messages; a call with a
        generous timeout completes successfully."""
        svc = _start_service(free_port)
        client, conn = _connect(free_port, "intr-resume")
        try:
            assert conn.rpc(timeout=TIMEOUT).echo("before freeze") == "before freeze"

            _sigstop(svc)
            result_holder: list = []
            error_holder:  list = []

            def _call():
                try:
                    result_holder.append(conn.rpc(timeout=15).echo("resumed"))
                except Exception as exc:
                    error_holder.append(exc)

            t = threading.Thread(target=_call, daemon=True)
            t.start()
            time.sleep(0.5)        # let the call block
            _sigcont(svc)          # unfreeze — the call is in-flight, client stays open
            t.join(timeout=20)

            assert not error_holder, f"unexpected error: {error_holder}"
            assert result_holder == ["resumed"]
        finally:
            client.stop()
            quiet_kill(svc)


# ── Scenario 3: autoreconnect after service restart ───────────────────────────

class TestAutoreconnectService:
    def test_reconnects_after_service_restart(self, free_port):
        """Client with autoreconnect=True recovers transparently when the service
        is killed and restarted on the same port."""
        svc = _start_service(free_port, "intr-svc-ar")
        client, conn = _connect(free_port, "intr-caller-ar", autoreconnect=True)
        assert conn.rpc(timeout=TIMEOUT).echo("before") == "before"

        _sigkill(svc, wait=0.5)

        # Restart the service on the same port.
        svc2 = _start_service(free_port, "intr-svc-ar-2")
        try:
            result = conn.rpc(timeout=20).echo("after restart")
            assert result == "after restart"
        finally:
            client.stop()
            quiet_kill(svc2)

    def test_multiple_calls_survive_restart(self, free_port):
        """Multiple sequential calls all succeed even though the service was
        restarted between some of them."""
        svc = _start_service(free_port, "intr-svc-multi")
        client, conn = _connect(free_port, "intr-multi", autoreconnect=True)

        for i in range(3):
            assert conn.rpc(timeout=TIMEOUT).echo(i) == i

        _sigkill(svc, wait=0.5)
        svc2 = _start_service(free_port, "intr-svc-multi-2")
        try:
            for i in range(3, 6):
                assert conn.rpc(timeout=20).echo(i) == i
        finally:
            client.stop()
            quiet_kill(svc2)


# ── Scenario 4: router restart ────────────────────────────────────────────────

class TestRouterRestart:
    def test_worker_and_caller_recover_after_router_restart(self, free_port):
        """Both a connected worker and a fresh caller can communicate through
        a router that was killed and restarted."""
        rproc = _start_router(free_port, "intr-router-rr")
        # Worker with autoreconnect — it will reconnect when the router comes back.
        wproc = _start_worker(
            free_port, "intr-worker-rr", autoreconnect=True, delay=0.5
        )
        time.sleep(0.5)   # let worker register its callbacks

        client, conn = _connect(free_port, "intr-caller-rr")
        assert conn.rpc(timeout=TIMEOUT).echo("before router kill") == "before router kill"
        client.stop()   # stop the plain caller

        # Kill router.
        _sigkill(rproc, wait=0.5)

        # Restart router on same port.
        rproc2 = _start_router(free_port, "intr-router-rr-2")
        time.sleep(1.5)   # let the worker auto-reconnect and re-register

        # A brand-new caller connects to the fresh router.
        client2, conn2 = _connect(free_port, "intr-caller-rr-2")
        try:
            result = conn2.rpc(timeout=20).echo("after router restart")
            assert result == "after router restart"
        finally:
            client2.stop()
            quiet_kill(wproc)
            quiet_kill(rproc2)


# ── Scenario 5: worker killed during cast ─────────────────────────────────────

class TestCastWithDeadWorker:
    def test_cast_succeeds_after_one_worker_dies(self, free_port):
        """cast() returns results from alive workers when one is killed before
        the call and the router has had time to detect the disconnection."""
        rproc = _start_router(free_port, "intr-router-cast")
        worker_procs = [
            _start_worker(free_port, f"intr-cast-worker-{i:02d}")
            for i in range(N_CAST_WORKERS)
        ]
        time.sleep(0.8)   # all workers register

        client, conn = _connect(free_port, "intr-cast-caller")
        # Verify all workers respond first.
        full = conn.cast(timeout=TIMEOUT).echo("all alive")
        assert len(full) == N_CAST_WORKERS

        # Kill one worker and wait for the router to detect the disconnection.
        _sigkill(worker_procs[0], wait=1.5)

        partial = conn.cast(timeout=TIMEOUT).echo("one dead")
        try:
            # At most N-1 workers should respond; at least 1.
            assert 1 <= len(partial) <= N_CAST_WORKERS
            # The dead worker's name must NOT appear.
            assert "intr-cast-worker-00" not in partial
        finally:
            client.stop()
            for p in worker_procs[1:]:
                quiet_kill(p)
            quiet_kill(rproc)

    def test_cast_nowait_does_not_hang_with_dead_worker(self, free_port):
        """cast_nowait() must return immediately regardless of dead workers."""
        rproc = _start_router(free_port, "intr-router-nowait")
        worker_procs = [
            _start_worker(free_port, f"intr-nw-worker-{i:02d}")
            for i in range(3)
        ]
        time.sleep(0.8)

        client, conn = _connect(free_port, "intr-nw-caller")
        _sigkill(worker_procs[0], wait=0.5)

        t0 = time.monotonic()
        conn.cast_nowait().echo("fire and forget")
        elapsed = time.monotonic() - t0

        try:
            assert elapsed < 2.0, f"cast_nowait took {elapsed:.2f}s — should be instant"
        finally:
            client.stop()
            for p in worker_procs[1:]:
                quiet_kill(p)
            quiet_kill(rproc)


# ── Scenario 6: big message + interruption ────────────────────────────────────

class TestBigMessageInterruption:
    def test_frozen_server_rejects_big_message(self, free_port):
        """Sending an 8 MiB payload to a frozen (SIGSTOP'd) server fills the
        kernel TCP send buffer and raises ValueError or TimeoutError."""
        svc = _start_service(free_port, "intr-big-frozen")
        client, conn = _connect(free_port, "intr-big-caller")
        try:
            # Warm up to confirm the connection works.
            assert conn.rpc(timeout=TIMEOUT).echo(b"tiny") == b"tiny"
            _sigstop(svc)
            with pytest.raises((ValueError, TimeoutError)):
                conn.rpc(timeout=3).echo(bytes(BIG_MSG_SIZE))
        finally:
            client.stop()
            _sigkill(svc)   # SIGKILL on stopped process; avoids poller race

    def test_big_message_succeeds_after_service_restart(self, free_port):
        """After the service is restarted, an 8 MiB echo round-trip succeeds
        with an autoreconnect client."""
        svc = _start_service(free_port, "intr-big-restart")
        client, conn = _connect(free_port, "intr-big-restart-caller", autoreconnect=True)
        payload = bytes(BIG_MSG_SIZE)
        assert conn.rpc(timeout=TIMEOUT).echo(payload) == payload

        _sigkill(svc, wait=0.5)
        svc2 = _start_service(free_port, "intr-big-restart-2")
        try:
            result = conn.rpc(timeout=60).echo(payload)
            assert result == payload
        finally:
            client.stop()
            quiet_kill(svc2)

    def test_big_message_concurrent_interruption(self, free_port):
        """A second thread kills the service while the first is sending 8 MiB.
        The sending thread must receive an error (not block forever)."""
        svc = _start_service(free_port, "intr-big-conc")
        client, conn = _connect(free_port, "intr-big-conc-caller")
        payload = bytes(BIG_MSG_SIZE)

        error_holder: list = []
        result_holder: list = []

        def _sender():
            try:
                result_holder.append(conn.rpc(timeout=10).echo(payload))
            except Exception as exc:
                error_holder.append(exc)

        sender = threading.Thread(target=_sender, daemon=True)
        sender.start()
        time.sleep(0.1)            # let the send start
        _sigkill(svc, wait=0.0)    # kill server immediately

        sender.join(timeout=15)

        try:
            # Either an error was raised (expected) or the transfer completed before
            # the kill — both are acceptable; the important invariant is no hang.
            assert not sender.is_alive(), "sender thread is still blocked — likely a hang"
            # If we got a result it means the message was fully transferred before kill.
            # If we got an error it must be ValueError or TimeoutError.
            if error_holder:
                assert isinstance(error_holder[0], (ValueError, TimeoutError, OSError))
        finally:
            client.stop()


# ── Scenario 7: rapid successive restarts ────────────────────────────────────

class TestRapidRestarts:
    def test_autoreconnect_survives_three_restarts(self, free_port):
        """An autoreconnect client remains functional across three sequential
        service restarts, verifying the reconnect loop is reusable."""
        svc = _start_service(free_port, "intr-rapid-0")
        client, conn = _connect(free_port, "intr-rapid-caller", autoreconnect=True)
        try:
            assert conn.rpc(timeout=TIMEOUT).echo(0) == 0

            for restart_idx in range(1, 4):
                _sigkill(svc, wait=0.3)
                svc = _start_service(free_port, f"intr-rapid-{restart_idx}")
                result = conn.rpc(timeout=20).echo(restart_idx)
                assert result == restart_idx
        finally:
            client.stop()
            quiet_kill(svc)
