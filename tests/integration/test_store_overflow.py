"""
Integration tests for ClientMessageStore overflow handling.

Background
----------
Each Client connection has an internal response store backed by a fixed-size
hash table (``buf_size = 2048``).  The hash key is ``uuid % buf_size``.
If two in-flight RPCs have UUIDs that map to the same slot (N and N + buf_size),
the second response to arrive finds the slot occupied and the native handler
fires ``error.StoreFull``.

``onResponse`` in the Zig handler catches StoreFull, logs a warning, drops the
duplicate response, and continues — the connection is **not** killed.
The Python caller whose response was dropped eventually receives a TimeoutError.

How we trigger it deterministically
------------------------------------
UUID assignment is sequential per connection starting from 1.
Fire-and-forget calls (``rpc_nowait``, ``return_result=False``) advance the
counter but never insert anything into the client-side store.

Strategy — send *both* colliding requests before polling either one:

1. Send ``BUF_SIZE - 1`` (= 2047) ``rpc_nowait`` calls → UUID counter = 2047.
2. Send UUID 2048 (``hold_echo``) **without waiting** for the response.
   Slot 0 = 2048 % 2048.
3. Send 2047 more ``rpc_nowait`` calls → UUID counter = 4095.
4. Send UUID 4096 (``hold_echo``) **without waiting**.
   Slot 0 = 4096 % 2048 — **same slot as UUID 2048**.
5. Sleep 500 ms so the service barrier releases and the Zig dispatcher inserts
   **both** responses into slot 0 in rapid succession (<200 ns apart, before
   any Python polling thread can wake from its ≥50 µs sleep).
   StoreFull fires for the second response → it is dropped.
6. Poll for UUID 2048 and UUID 4096 concurrently.
   Exactly one finds its response in the store; the other times out.
7. Verify the connection is still alive with a follow-up rpc().
"""
from __future__ import annotations

import multiprocessing as mp
import threading
import time

import pytest

from .conftest import HOST, TIMEOUT, wait_for_port, silence_subprocess, quiet_kill

# Must match core/store/ClientMessageStore.zig  ``const buf_size: u16 = 2048;``
BUF_SIZE = 2048


# ── subprocess entry points ────────────────────────────────────────────────────

def _proc_service_overflow(port: int) -> None:
    """Service with two callbacks:

    * ``hold_echo`` — waits on a 2-party barrier so that exactly two calls are
      released simultaneously.  This guarantees responses for UUID 2048 and
      UUID 4096 are sent back-to-back with no gap between them.
    * ``fast_echo`` — returns immediately; used solely to advance the UUID
      counter without touching the client message store.
    """
    silence_subprocess()
    from daffi import Service, callback

    _barrier = threading.Barrier(2)

    @callback
    def hold_echo(payload):
        _barrier.wait()
        return payload

    @callback
    def fast_echo(payload):
        return payload

    svc = Service(app_name="overflow-svc", host=HOST, port=port, workers=40)
    svc.start()
    svc.join()


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def overflow_service(free_port):
    proc = mp.Process(target=_proc_service_overflow, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.2)
    yield free_port
    quiet_kill(proc)


# ── tests ─────────────────────────────────────────────────────────────────────

class TestStoreOverflow:
    """Verify that a full ClientMessageStore gracefully drops the overflowing
    response and that the connection survives."""

    def test_overflow_drops_one_response_connection_survives(self, overflow_service):
        """
        Engineer a deterministic UUID hash collision between two rpc() calls,
        verify that exactly one is dropped (TimeoutError) and that the
        connection remains alive afterwards.

        Why this is reliable
        --------------------
        Both requests are sent *before* any polling begins.  A 500 ms sleep
        gives the service time to release the barrier and lets the Zig
        dispatcher (no GIL) insert *both* responses into slot 0 within ~200 ns
        — far shorter than Python's ≥50 µs polling sleep.  StoreFull fires
        for the second insert, dropping that response.  When polling finally
        starts (after the sleep), exactly one response is in the store.
        """
        from daffi import Client
        from daffi._bindings import send_message_from_client, MessageFlag
        from daffi._rpc_proxy import RpcResult
        from daffi._serialization import Serializer, SerdeFormat

        client = Client(app_name="overflow-cli", host=HOST, port=overflow_service)
        conn = client.connect()
        conn_num = client._conn_num

        try:
            # ── step 1: fire the first hold_echo to anchor the UUID slot ─────
            # The connection handshake has already consumed some UUIDs.  We
            # don't know the exact counter, so we send UUID_A and then advance
            # by exactly BUF_SIZE - 1 rpc_nowait calls so that UUID_B = UUID_A
            # + BUF_SIZE, ensuring they hash to the same slot.
            data_a, ib_a = Serializer.serialize(SerdeFormat.PICKLE, "payload-a")
            uuid_a, ts_a, found = send_message_from_client(
                data=data_a, flag=MessageFlag.REQUEST, serde=SerdeFormat.PICKLE,
                receiver="", func_name="hold_echo", return_result=True,
                conn_num=conn_num, is_bytes=ib_a,
            )
            assert found, "No receiver found for hold_echo"

            # ── step 2: advance UUID counter by exactly BUF_SIZE - 1 ─────────
            # Each rpc_nowait increments the UUID counter by 1 without creating
            # a store entry.  After BUF_SIZE - 1 calls the counter is at
            # uuid_a + (BUF_SIZE - 1), so the next send gets UUID_B = uuid_a + BUF_SIZE.
            for _ in range(BUF_SIZE - 1):
                conn.rpc_nowait().fast_echo(None)

            # ── step 3: send UUID_B (same slot as UUID_A — collision!) ────────
            data_b, ib_b = Serializer.serialize(SerdeFormat.PICKLE, "payload-b")
            uuid_b, ts_b, found = send_message_from_client(
                data=data_b, flag=MessageFlag.REQUEST, serde=SerdeFormat.PICKLE,
                receiver="", func_name="hold_echo", return_result=True,
                conn_num=conn_num, is_bytes=ib_b,
            )
            assert found, "No receiver found for hold_echo"
            assert uuid_b == uuid_a + BUF_SIZE, (
                f"Expected UUID_B = {uuid_a + BUF_SIZE}, got {uuid_b}. "
                "UUID counter was not advanced by exactly BUF_SIZE - 1."
            )
            assert uuid_a % BUF_SIZE == uuid_b % BUF_SIZE, (
                f"Both UUIDs must hash to the same slot "
                f"(uuid_a={uuid_a} slot={uuid_a % BUF_SIZE}, "
                f"uuid_b={uuid_b} slot={uuid_b % BUF_SIZE})."
            )

            # ── step 5: sleep so the dispatcher processes both responses ──────
            # The service barrier needs to receive *both* hold_echo calls before
            # releasing.  The 2047 fast_echo calls in step 3 are queued ahead of
            # UUID 4096's hold_echo; with workers=40 they complete in ~50 ms.
            # After the barrier releases, both responses travel over loopback and
            # the Zig dispatcher (no GIL) inserts them within ~200 ns of each
            # other — before any Python polling sleep can expire.
            # StoreFull fires for whichever UUID arrived second; its response is
            # dropped.  After 500 ms, exactly one response is in the store.
            time.sleep(0.5)

            # ── step 6: poll for both UUIDs concurrently ─────────────────────
            results: list = [None, None]
            errors:  list = [None, None]

            def _poll(idx, uuid, ts):
                try:
                    data, _, serde = RpcResult(
                        conn_num=conn_num, uuid=uuid, ts=ts,
                        timeout=5, receivers=None, proxy=None,
                    ).result()
                    results[idx] = Serializer.deserialize(serde, data)[0][0]
                except TimeoutError as exc:
                    errors[idx] = exc

            t_a = threading.Thread(target=_poll, args=(0, uuid_a, ts_a), daemon=True)
            t_b = threading.Thread(target=_poll, args=(1, uuid_b, ts_b), daemon=True)
            t_a.start()
            t_b.start()
            t_a.join(timeout=15)
            t_b.join(timeout=10)

            # ── step 7: exactly one caller must have received TimeoutError ────
            n_errors  = sum(1 for e in errors  if e is not None)
            n_success = sum(1 for r in results if r is not None)

            assert n_errors == 1, (
                f"Expected 1 StoreFull-caused TimeoutError, got {n_errors}.\n"
                f"  errors={errors}\n  results={results}\n"
                "If n_errors=0 both responses were inserted (timing changed);\n"
                "if n_errors=2 the connection died instead of just dropping one."
            )
            assert n_success == 1, (
                f"Expected 1 successful result, got {n_success}.\n"
                f"  errors={errors}\n  results={results}"
            )

            # The successful payload must be one of the two we sent.
            good = results[0] if results[0] is not None else results[1]
            assert good in ("payload-a", "payload-b"), (
                f"Unexpected result: {good!r}"
            )

            # ── step 8: connection must still be alive ────────────────────────
            ping = conn.rpc(timeout=TIMEOUT).fast_echo("ping-after-overflow")
            assert ping == "ping-after-overflow", (
                f"Connection died after StoreFull; got {ping!r}"
            )

        finally:
            client.stop()

    def test_rpc_nowait_never_pollutes_store(self, overflow_service):
        """
        rpc_nowait (return_result=False) must never insert anything into the
        client message store.  Fire a large burst, then verify that a normal
        blocking rpc() still works perfectly on the same connection.
        """
        from daffi import Client

        client = Client(app_name="overflow-nowait-cli", host=HOST, port=overflow_service)
        conn = client.connect()

        try:
            for i in range(500):
                conn.rpc_nowait().fast_echo(i)

            result = conn.rpc(timeout=TIMEOUT).fast_echo("after-nowait-flood")
            assert result == "after-nowait-flood"

        finally:
            client.stop()

    def test_connection_survives_heavy_concurrent_rpc(self, overflow_service):
        """
        50 threads sharing one connection each fire 10 rpc() calls.
        With buf_size=2048 >> 50 concurrent RPCs there is no collision;
        all results must be correct.
        """
        from daffi import Client

        N_THREADS = 50
        CALLS = 10

        client = Client(app_name="overflow-heavy-cli", host=HOST, port=overflow_service)
        conn = client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)

        errors: list[Exception] = []
        lock = threading.Lock()
        barrier = threading.Barrier(N_THREADS)

        def _task(tid: int):
            barrier.wait(timeout=30)
            try:
                for k in range(CALLS):
                    payload = (tid, k)
                    result = proxy.fast_echo(payload)
                    assert list(result) == list(payload), (
                        f"tid={tid} k={k}: expected {payload!r} got {result!r}"
                    )
            except Exception as exc:
                with lock:
                    errors.append(exc)

        threads = [
            threading.Thread(target=_task, args=(i,), daemon=True)
            for i in range(N_THREADS)
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT + 20)

        client.stop()
        assert not errors, f"{len(errors)} failure(s): {errors[:3]}"
