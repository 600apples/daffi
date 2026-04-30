"""
aio/service/01_rpc — Client side (async).

AsyncClient connects to the AsyncService and makes awaitable RPC calls.
Multiple calls can be gathered with asyncio.gather() for true concurrency.

Run 1_service.py first.
"""
import asyncio
from daffi.aio import AsyncClient


async def main():
    client = AsyncClient(app_name="calc-client", host="0.0.0.0", port=5001)
    conn = await client.connect()

    rpc = conn.rpc(timeout=5)

    result = await rpc.add(3, 4)
    print(f"add(3, 4) = {result}")

    result = await rpc.add(10, 20)
    print(f"add(10, 20) = {result}")

    # Two calls in flight simultaneously.
    r1, r2 = await asyncio.gather(rpc.add(1, 2), rpc.add(100, 200))
    print(f"concurrent: add(1,2)={r1}  add(100,200)={r2}")

    await client.stop()
    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())
