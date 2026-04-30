"""
aio/router/02_cast — Worker (async).

Run this script in 3 separate terminals:

  Terminal 1:  python 2_worker.py
  Terminal 2:  python 2_worker.py
  Terminal 3:  python 2_worker.py

Start 1_router.py first, then the workers, then 3_caller.py.
"""
import asyncio
import random
from daffi import callback
from daffi.aio import AsyncClient

TAG = random.choice(["🔵", "🟢", "🟡", "🔴", "🟣", "🟠"])


@callback
async def process(item: str) -> str:
    await asyncio.sleep(0)
    return TAG


async def main():
    worker = AsyncClient(host="0.0.0.0", port=6002)
    await worker.connect()
    print(f"{TAG}  worker connected — press Ctrl+C to stop.")
    await worker.join()


if __name__ == "__main__":
    asyncio.run(main())
