"""
Async integration test for ClientMessageStore — concurrent in-flight RPCs.

With the old modulo-2048 fixed array, two in-flight RPCs whose UUIDs differed
by exactly 2048 would hash to the same slot (StoreFull) and one response was
silently dropped.

With the new AutoHashMap implementation every UUID occupies a distinct entry,
so all concurrent requests are delivered successfully regardless of their
UUID values.

This test:
  1. Sends two concurrent requests and verifies BOTH responses arrive.
  2. Confirms the connection remains usable after high concurrency.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import time

import pytest

from .conftest import HOST, TIMEOUT, wait_for_port, silence_subprocess, quiet_kill


def _proc_service_overflow(port: int) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        _barrier = asyncio.Barrier(2)

        @callback
        async def hold_echo(payload):
            """Block until two callers have sent, then return."""
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

    async def test_concurrent_requests_both_succeed(self, overflow_service):
        """Both concurrent in-flight requests must deliver their responses.

        Previously the 2048-slot modulo store would drop one response when two
        UUIDs collided at the same hash slot.  With AutoHashMap every UUID is
        stored in a distinct bucket — both responses are delivered.
        """
        from daffi.aio import AsyncClient
        from daffi.aio._rpc_proxy import AsyncRpcResult
        from daffi._bindings import send_message_from_client, MessageFlag
        from daffi._serialization import Serializer, SerdeFormat

        client = AsyncClient(app_name="overflow-aio-caller", host=HOST, port=overflow_service)
        conn = await client.connect()
        conn_num = client._conn_num

        try:
            # Send two concurrent hold_echo requests without registering async
            # waiters so neither is fetched from the store until we explicitly
            # poll below.
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

            # The two UUIDs must be distinct (no wrap-around for this small test).
            assert uuid_a != uuid_b, "UUIDs must differ for a valid concurrency test"

            # Wait for the service barrier to release and both responses to arrive.
            await asyncio.sleep(0.5)

            # Both responses must be in the store — neither should time out.
            timeout_s = 3
            results = []
            for uuid, ts in [(uuid_a, ts_a), (uuid_b, ts_b)]:
                res = await AsyncRpcResult(
                    conn_num=conn_num, uuid=uuid, ts=ts, timeout=timeout_s,
                ).result()
                results.append(Serializer.deserialize(res[2], res[0])[0][0])

            assert set(results) == {"payload-a", "payload-b"}, (
                f"Expected both payloads delivered, got: {results}"
            )

            # Connection must still be alive.
            result = await conn.rpc(timeout=TIMEOUT).fast_echo("still-alive")
            assert result == "still-alive"
        finally:
            await client.stop()
