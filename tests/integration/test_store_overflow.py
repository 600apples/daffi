"""
Integration tests for ClientMessageStore — concurrent in-flight RPCs.

Background
----------
The old store was a fixed-size 2048-slot hash table keyed by ``uuid % 2048``.
Two in-flight RPCs whose UUIDs differed by exactly 2048 would collide and one
response was silently dropped (``StoreFull``).

The new store is an ``AutoHashMap`` keyed by the full 16-bit UUID.  Every
in-flight RPC gets its own distinct entry — no false collisions, no dropped
responses.  The tests below verify:

  1. Two concurrent requests both get their responses delivered.
  2. rpc_nowait never pollutes the store.
  3. Heavy concurrent usage from many threads stays correct.
"""
from __future__ import annotations

import multiprocessing as mp
import threading
import time

import pytest

from .conftest import HOST, TIMEOUT, wait_for_port, silence_subprocess, quiet_kill


# ── subprocess entry points ────────────────────────────────────────────────────

def _proc_service_overflow(port: int) -> None:
    """Service with two callbacks:

    * ``hold_echo`` — waits on a 2-party barrier so that exactly two calls are
      released simultaneously, ensuring both responses arrive close together.
    * ``fast_echo`` — returns immediately; used for no-wait calls.
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
    """Verify correct concurrent behaviour of the AutoHashMap-backed store."""

    def test_concurrent_requests_both_succeed(self, overflow_service):
        """Both in-flight requests must deliver their responses.

        With the old 2048-slot modulo store, two RPCs whose UUIDs shared the
        same slot would cause one response to be dropped (StoreFull).  With the
        new AutoHashMap every UUID is a distinct key — both responses must
        arrive successfully.
        """
        from daffi import Client
        from daffi._bindings import send_message_from_client, MessageFlag
        from daffi._rpc_proxy import RpcResult
        from daffi._serialization import Serializer, SerdeFormat

        client = Client(app_name="overflow-cli", host=HOST, port=overflow_service)
        conn = client.connect()
        conn_num = client._conn_num

        try:
            # Send two concurrent hold_echo requests without registering
            # waiters so neither is fetched until we poll below.
            data_a, ib_a = Serializer.serialize(SerdeFormat.PICKLE, "payload-a")
            uuid_a, ts_a, found_a = send_message_from_client(
                data=data_a, flag=MessageFlag.REQUEST, serde=SerdeFormat.PICKLE,
                receiver="", func_name="hold_echo", return_result=True,
                conn_num=conn_num, is_bytes=ib_a,
            )
            assert found_a, "No receiver found for hold_echo"

            data_b, ib_b = Serializer.serialize(SerdeFormat.PICKLE, "payload-b")
            uuid_b, ts_b, found_b = send_message_from_client(
                data=data_b, flag=MessageFlag.REQUEST, serde=SerdeFormat.PICKLE,
                receiver="", func_name="hold_echo", return_result=True,
                conn_num=conn_num, is_bytes=ib_b,
            )
            assert found_b, "No receiver found for hold_echo"

            # UUIDs must be distinct.
            assert uuid_a != uuid_b

            # Wait for barrier to release and both responses to arrive.
            time.sleep(0.5)

            # Poll both UUIDs concurrently — both must succeed.
            results: list = [None, None]
            errors:  list = [None, None]

            def _poll(idx, uuid, ts):
                try:
                    data, _, serde = RpcResult(
                        conn_num=conn_num, uuid=uuid, ts=ts,
                        timeout=5, receivers=None, proxy=None,
                    ).result()
                    results[idx] = Serializer.deserialize(serde, data)[0][0]
                except Exception as exc:
                    errors[idx] = exc

            t_a = threading.Thread(target=_poll, args=(0, uuid_a, ts_a), daemon=True)
            t_b = threading.Thread(target=_poll, args=(1, uuid_b, ts_b), daemon=True)
            t_a.start(); t_b.start()
            t_a.join(timeout=15); t_b.join(timeout=10)

            assert errors == [None, None], (
                f"One or both requests failed: {errors}"
            )
            assert set(results) == {"payload-a", "payload-b"}, (
                f"Expected both payloads delivered, got: {results}"
            )

            # Connection must still be alive.
            ping = conn.rpc(timeout=TIMEOUT).fast_echo("ping-after-concurrent")
            assert ping == "ping-after-concurrent"

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
        All results must be correct — the HashMap handles concurrent inserts
        without false collisions.
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
