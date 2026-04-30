"""
aio/router/01_rpc — Caller (async).

AsyncClient connects to the Router and calls the worker's 'multiply'
function with await.  conn.rpc() picks a worker using round-robin;
conn.rpc(receiver=…) pins the call to a specific worker.

Run 1_router.py and 2_worker.py first.
"""
import asyncio
from daffi.aio import AsyncClient


async def main():
    caller = AsyncClient(app_name="calc-caller", host="0.0.0.0", port=6001)
    conn = await caller.connect()

    result = await conn.rpc(timeout=5).multiply(6, 7)
    print(f"multiply(6, 7) = {result}")

    # Pin the call to a specific worker by name.
    result = await conn.rpc(timeout=5, receiver="calc-worker").multiply(3, 3)
    print(f"multiply(3, 3) [pinned to calc-worker] = {result}")

    await caller.stop()
    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())
