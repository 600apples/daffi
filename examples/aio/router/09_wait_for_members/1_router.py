"""
aio/router/09_wait_for_members — Router (async).

Start first.  Then start 2_worker.py and 3_caller.py in any order.
"""
import asyncio
from daffi.aio import AsyncRouter


async def main():
    router = AsyncRouter(host="0.0.0.0", port=6009)
    await router.start()
    print("Router running on 0.0.0.0:6009 — press Ctrl+C to stop.")
    await router.join()


if __name__ == "__main__":
    asyncio.run(main())
