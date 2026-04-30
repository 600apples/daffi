"""
aio/router/09_wait_for_members — Caller (async).

Demonstrates await conn.wait_for_members(): suspends the coroutine until
the required worker appears, then fires all RPC calls concurrently via
asyncio.gather() — something the sync version cannot do easily.

Start 1_router.py first.  Then start this and 2_worker.py in any order.
"""
import asyncio
from daffi.aio import AsyncClient


async def main():
    caller = AsyncClient(app_name="calc-caller", host="0.0.0.0", port=6009)
    conn = await caller.connect()

    print("Connected to router.  Waiting for 'calc-worker' to come online…")
    await conn.wait_for_members("calc-worker")
    print("calc-worker is online — issuing RPC calls concurrently.")

    rpc = conn.rpc(timeout=10, receiver="calc-worker")
    results = await asyncio.gather(*[rpc.process(n) for n in range(1, 6)])
    for n, res in zip(range(1, 6), results):
        print(f"  process({n}) = {res}")

    await caller.stop()
    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())
