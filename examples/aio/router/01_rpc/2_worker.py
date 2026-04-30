"""
aio/router/01_rpc — Worker (async).

AsyncClient with an async @callback.  The callback is awaited directly by
the AsyncTaskDispatcher — no thread-pool needed.

Start 1_router.py first, then this, then 3_caller.py.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncClient


@callback
async def multiply(a: int, b: int) -> int:
    print(f"[worker] multiply({a}, {b})")
    await asyncio.sleep(0)
    return a * b


async def main():
    worker = AsyncClient(app_name="calc-worker", host="0.0.0.0", port=6001)
    await worker.connect()
    print("Worker connected to router — press Ctrl+C to stop.")
    await worker.join()


if __name__ == "__main__":
    asyncio.run(main())
