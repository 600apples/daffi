"""
aio/router/03_bidirectional — Router (async).

Start first, then 2_node_b.py, then 3_node_a.py.
"""
import asyncio
from daffi.aio import AsyncRouter


async def main():
    router = AsyncRouter(host="0.0.0.0", port=6003)
    await router.start()
    print("Router running on 0.0.0.0:6003 — press Ctrl+C to stop.")
    await router.join()


if __name__ == "__main__":
    asyncio.run(main())
