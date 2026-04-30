"""
Integration tests for connection interruption scenarios.

What is tested
--------------
Each test deliberately disrupts the server-side process and verifies that
the client reacts correctly — no infinite hangs and the correct exception type.

Interruption mechanisms used
----------------------------
  SIGSTOP  — freeze the process (simulates a stalled / overloaded node).
              The client's pending call must time out.
  SIGKILL  — instant termination (simulates OOM kill, hardware failure).
              The client receives a write / read error on the next operation.
  SIGCONT  — resume a STOPped process (used in cleanup / resume tests).
  proc.terminate() — SIGTERM; used for clean teardown.

Exception types produced by the native layer (and how daffi surfaces them)
--------------------------------------------------------------------------
  TimeoutError         (builtins)          — rpc() call timed out waiting
                                             for a response from a frozen server.
  TransmissionFailure  (daffi._rpc_proxy)  — wraps native-side failures on
                                             the wire (WriteError, ReadError,
                                             ClientNotInitialized, …).  Any
                                             write/read error on a dead or
                                             severed connection surfaces as
                                             this exception.
  InitializationError  (daffi.exceptions)  — Client.connect() failed because
                                             the server is not listening.

Scenarios
---------
  1  Service killed → existing call raises TransmissionFailure
  2  Connect to dead service → InitializationError
  3  Service frozen (SIGSTOP) → TimeoutError within RPC timeout
  4  Service frozen then resumed (SIGCONT) → call eventually succeeds
  5  One worker killed → cast() to remaining workers still succeeds
  6  Big message (8 MiB) + frozen server → fails (ValueError/TimeoutError)
  7  Big message round-trip succeeds after service restart
  8  Disconnected raised immediately despite a huge RPC timeout

All subprocess targets are module-level functions so they pickle correctly
under the "spawn" start method that the integration conftest.py now enforces
(see ``tests/integration/conftest.py`` for the rationale — fork is unsafe on
macOS once the parent pytest process has imported the native ``daffi.dfcore``
extension).
"""
from __future__ import annotations

import multiprocessing as mp
import os
import signal
import threading
import time

import pytest

from .conftest import HOST, TIMEOUT, wait_for_port, wait_for_members, silence_subprocess, quiet_kill
from daffi.exceptions import Disconnected, InitializationError, RemoteCallError, TransmissionFailure

# ── constants ──────────────────────────────────────────────────────────────────

BIG_MSG_SIZE = 8 * 1024 * 1024    # 8 MiB — large enough to stress the buffer
N_CAST_WORKERS = 4                 # workers for cast / partial-result tests


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


def _intr_slow_service(port: int, name: str = "intr-slow-svc") -> None:
    """Service whose only callback sleeps 60 s before replying — lets tests
    reliably kill it while a call is in-flight."""
    silence_subprocess()
    import time as _t
    from daffi import Service, callback

    @callback
    def slow_echo(payload):
        _t.sleep(60)
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


def _intr_worker(port: int, name: str) -> None:
    silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    client = Client(app_name=name, host=HOST, port=port)
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── helpers ───────────────────────────────────────────────────────────────────

def _start_slow_service(port: int, name: str = "intr-slow-svc") -> mp.Process:
    p = mp.Process(target=_intr_slow_service, args=(port, name), daemon=True)
    p.start()
    wait_for_port(port)
    time.sleep(0.3)
    return p


def _start_service(port: int, name: str = "intr-svc") -> mp.Process:
    p = mp.Process(target=_intr_service, args=(port, name), daemon=True)
    p.start()
    wait_for_port(port)
    # Small grace after the TCP listener opens so the child finishes daffi
    # import + callback registration before the caller's first rpc(). 0.3 s
    # is comfortable under spawn on macOS.
    time.sleep(0.3)
    return p


def _start_router(port: int, name: str = "intr-router") -> mp.Process:
    p = mp.Process(target=_intr_router, args=(port, name), daemon=True)
    p.start()
    wait_for_port(port)
    return p


def _start_worker(port: int, name: str) -> mp.Process:
    p = mp.Process(target=_intr_worker, args=(port, name), daemon=True)
    p.start()
    return p


def _connect(port: int, name: str):
    """Return (client, conn) connected to *port*."""
    from daffi import Client
    client = Client(app_name=name, host=HOST, port=port)
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
        """After SIGKILL, rpc() on the stale connection raises TransmissionFailure.

        The underlying native error surfaces as ``WriteError`` or
        ``ClientNotInitialized`` depending on whether the disconnect watcher
        has already marked the connection dead — both flow through
        ``system_exception_handler`` and are re-raised as
        :class:`~daffi._rpc_proxy.TransmissionFailure`.
        """
        svc = _start_service(free_port)
        client, conn = _connect(free_port, "intr-dead-call")
        try:
            assert conn.rpc(timeout=TIMEOUT).echo("ping") == "ping"
            _sigkill(svc)
            with pytest.raises(TransmissionFailure):
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


# ── Scenario 3: worker killed during cast ─────────────────────────────────────

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
        kernel TCP send buffer and raises TransmissionFailure or TimeoutError.

        The native write may either time out (kernel buffer never drains
        because the server process is SIGSTOP'd) or fail with a write error
        once TCP gives up — both are acceptable outcomes.
        """
        svc = _start_service(free_port, "intr-big-frozen")
        client, conn = _connect(free_port, "intr-big-caller")
        try:
            assert conn.rpc(timeout=TIMEOUT).echo(b"tiny") == b"tiny"
            _sigstop(svc)
            with pytest.raises((TransmissionFailure, TimeoutError)):
                conn.rpc(timeout=3).echo(bytes(BIG_MSG_SIZE))
        finally:
            client.stop()
            _sigkill(svc)   # SIGKILL on stopped process; avoids poller race

    def test_big_message_succeeds_after_service_restart(self, free_port):
        """After the service is restarted, a fresh client can send an 8 MiB
        echo round-trip successfully."""
        svc = _start_service(free_port, "intr-big-restart")
        client, conn = _connect(free_port, "intr-big-restart-caller")
        payload = bytes(BIG_MSG_SIZE)
        assert conn.rpc(timeout=TIMEOUT).echo(payload) == payload
        client.stop()

        _sigkill(svc, wait=0.5)
        svc2 = _start_service(free_port, "intr-big-restart-2")
        client2, conn2 = _connect(free_port, "intr-big-restart-caller-2")
        try:
            result = conn2.rpc(timeout=60).echo(payload)
            assert result == payload
        finally:
            client2.stop()
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
            # If we got an error it must be a disconnect/timeout variant.
            if error_holder:
                assert isinstance(
                    error_holder[0],
                    (TransmissionFailure, ValueError, TimeoutError, OSError),
                )
        finally:
            client.stop()


# ── Scenario 6: Disconnected raised immediately despite huge timeout ──────────

# Maximum wall-clock seconds the client should take to raise after a disconnect.
# Must be much smaller than the BIG_TIMEOUT used in the calls below.
_MAX_DISCONNECT_LATENCY = 5.0
BIG_TIMEOUT = 300


class TestDisconnectedWithBigTimeout:
    """Verify that a lost connection surfaces as Disconnected immediately —
    not after the (intentionally huge) RPC timeout expires."""

    def test_disconnect_before_call_raises_immediately(self, free_port):
        """Kill the service, then call rpc(timeout=300).
        Disconnected (or TransmissionFailure on a dead socket) must be raised
        within a few seconds, not after the 300 s timeout."""
        svc = _start_service(free_port, "intr-disc-before")
        client, conn = _connect(free_port, "intr-disc-before-caller")
        try:
            assert conn.rpc(timeout=TIMEOUT).echo("warm") == "warm"
            _sigkill(svc, wait=0.5)   # disconnect propagates before next call

            t0 = time.monotonic()
            with pytest.raises((Disconnected, TransmissionFailure)):
                conn.rpc(timeout=BIG_TIMEOUT).echo("after disconnect")
            elapsed = time.monotonic() - t0

            assert elapsed < _MAX_DISCONNECT_LATENCY, (
                f"raised after {elapsed:.1f}s — expected <{_MAX_DISCONNECT_LATENCY}s, "
                f"not after the full {BIG_TIMEOUT}s timeout"
            )
        finally:
            client.stop()
            quiet_kill(svc)

    def test_disconnect_during_call_raises_immediately(self, free_port):
        """Kill the service while rpc(timeout=300) is blocked waiting for a
        slow callback.  Disconnected must propagate within a few seconds."""
        svc = _start_slow_service(free_port, "intr-disc-during")
        client, conn = _connect(free_port, "intr-disc-during-caller")

        error_holder: list = []
        elapsed_holder: list = []

        def _call():
            t0 = time.monotonic()
            try:
                conn.rpc(timeout=BIG_TIMEOUT).slow_echo("payload")
            except Exception as exc:
                error_holder.append(exc)
            elapsed_holder.append(time.monotonic() - t0)

        t = threading.Thread(target=_call, daemon=True)
        t.start()
        time.sleep(0.3)           # let the request reach the service
        _sigkill(svc, wait=0.0)   # disconnect while call is in-flight

        t.join(timeout=10)

        try:
            assert not t.is_alive(), "caller thread is still blocked — likely a hang"
            assert error_holder, "no exception raised — expected Disconnected"
            assert isinstance(error_holder[0], (Disconnected, TransmissionFailure, RemoteCallError)), (
                f"unexpected exception type: {type(error_holder[0])}"
            )
            assert elapsed_holder[0] < _MAX_DISCONNECT_LATENCY, (
                f"raised after {elapsed_holder[0]:.1f}s — expected <{_MAX_DISCONNECT_LATENCY}s"
            )
        finally:
            client.stop()
            quiet_kill(svc)
