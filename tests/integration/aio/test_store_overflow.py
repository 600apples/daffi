"""
Async integration test for ClientMessageStore overflow handling.

Mirrors tests/integration/test_store_overflow.py using daffi.aio.

The store overflow path (StoreFull) is identical for both sync and async
clients because it lives inside the Zig native layer.  This test verifies
that the async Python layer surfaces the same behaviour:

  - The connection is NOT killed on StoreFull.
  - The dropped response causes a TimeoutError for that UUID.
  - Subsequent rpc() calls on the same connection succeed.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import time

import pytest

from .conftest import HOST, TIMEOUT, wait_for_port, silence_subprocess, quiet_kill

BUF_SIZE = 2048


def _proc_service_overflow(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        _barrier = asyncio.Barrier(2)

        @callback
        async def hold_echo(payload):
            await _barrier.wait()
            return payload

        @callback
        async def fast_echo(payload):
            return payload

        svc = AsyncService(app_name="overflow-aio-svc", host=HOST, port=port, workers=4)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


@pytest.fixture
def overflow_service(free_port):
    proc = mp.Process(target=_proc_service_overflow, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.2)
    yield free_port
    quiet_kill(proc)


@pytest.mark.asyncio
class TestStoreOverflowAsync:

    async def test_connection_survives_store_overflow(self, overflow_service):
        """After a StoreFull event the connection remains usable.

        Why this uses the low-level send API
        -------------------------------------
        Using ``ensure_future(conn.rpc(...).hold_echo(...))`` registers an
        asyncio.Event waiter in the notifier.  When Zig delivers the first
        response and writes to the wakeup fd, ``_on_readable`` sets that
        event, the coroutine immediately wakes and *reads* slot S from the
        Zig store — freeing it before uuid_b's response can arrive.  No
        StoreFull.

        Instead we send both requests via the low-level API with no waiter
        registered.  ``_on_readable`` still fires (draining the wakeup fd)
        but nobody reads the store, so slot S stays occupied.  When uuid_b's
        response arrives Zig finds slot S occupied → StoreFull → drops it.
        After the sleep we create ``AsyncRpcResult`` objects whose first
        action is a direct store lookup (no wait needed for the surviving
        response; the dropped one times out).
        """
        from daffi.aio import AsyncClient
        from daffi.aio._rpc_proxy import AsyncRpcResult
        from daffi._bindings import send_message_from_client, MessageFlag
        from daffi._serialization import Serializer, SerdeFormat
        from daffi.exceptions import CallTimeout

        client = AsyncClient(app_name="overflow-aio-caller", host=HOST, port=overflow_service)
        conn = await client.connect()
        conn_num = client._conn_num

        try:
            # ── step 1: send uuid_a without registering an async waiter ──────
            data_a, ib_a = Serializer.serialize(SerdeFormat.PICKLE, "payload-a")
            uuid_a, ts_a, found = send_message_from_client(
                data=data_a, flag=MessageFlag.REQUEST, serde=SerdeFormat.PICKLE,
                receiver="", func_name="hold_echo", return_result=True,
                conn_num=conn_num, is_bytes=ib_a,
            )
            assert found, "No receiver found for hold_echo"

            # ── step 2: advance UUID counter by BUF_SIZE-1 ───────────────────
            data_nw, ib_nw = Serializer.serialize(SerdeFormat.PICKLE, None)
            for _ in range(BUF_SIZE - 1):
                send_message_from_client(
                    data=data_nw, flag=MessageFlag.REQUEST, serde=SerdeFormat.PICKLE,
                    receiver="", func_name="fast_echo", return_result=False,
                    conn_num=conn_num, is_bytes=ib_nw,
                )

            # ── step 3: send uuid_b (same slot as uuid_a) without a waiter ───
            data_b, ib_b = Serializer.serialize(SerdeFormat.PICKLE, "payload-b")
            uuid_b, ts_b, found = send_message_from_client(
                data=data_b, flag=MessageFlag.REQUEST, serde=SerdeFormat.PICKLE,
                receiver="", func_name="hold_echo", return_result=True,
                conn_num=conn_num, is_bytes=ib_b,
            )
            assert found, "No receiver found for hold_echo"
            assert uuid_b == uuid_a + BUF_SIZE, (
                f"Expected UUID_B = {uuid_a + BUF_SIZE}, got {uuid_b}."
            )

            # ── step 4: sleep — service barrier releases, Zig inserts both ───
            # _on_readable fires for each wakeup-fd write but finds no waiter,
            # so the Zig store is never read.  Slot S stays occupied; the
            # second insert triggers StoreFull and the response is dropped.
            await asyncio.sleep(0.5)

            # ── step 5: poll — exactly one uuid is in the store ──────────────
            # The async service's event loop may run either hold_echo coroutine
            # first after the barrier releases, so either uuid_a or uuid_b may
            # have been dropped by StoreFull.  Check both and require exactly
            # one success and one timeout.
            timeout_s = 3
            results = []
            for uuid, ts in [(uuid_a, ts_a), (uuid_b, ts_b)]:
                try:
                    res = await AsyncRpcResult(
                        conn_num=conn_num, uuid=uuid, ts=ts, timeout=timeout_s,
                    ).result()
                    results.append(Serializer.deserialize(res[2], res[0])[0][0])
                except (CallTimeout, TimeoutError):
                    results.append(None)

            successes = [r for r in results if r is not None]
            assert len(successes) == 1, (
                f"Expected exactly 1 success (StoreFull drops the other), got: {results}"
            )
            assert successes[0] in ("payload-a", "payload-b")

            # ── step 6: connection must still be alive ────────────────────────
            result = await conn.rpc(timeout=TIMEOUT).fast_echo("still-alive")
            assert result == "still-alive"
        finally:
            await client.stop()
