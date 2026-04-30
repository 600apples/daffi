"""
aio/router/08_events — Router (async).

Start first, then 2_worker.py, then 3_caller.py.
"""
import asyncio
from daffi.aio import AsyncRouter


async def main():
    router = AsyncRouter(host="0.0.0.0", port=6008)
    await router.start()
    print("Router running on 0.0.0.0:6008 — press Ctrl+C to stop.")
    await router.join()


if __name__ == "__main__":
    asyncio.run(main())
