"""
aio/router/01_rpc — Router (async).

AsyncRouter is the async counterpart of Router.  Because a router is a pure
server that only forwards messages, its start/join/stop are the only methods
you call, and all three are now coroutines.

Start first, then run 2_worker.py, then 3_caller.py.
"""
import asyncio
from daffi.aio import AsyncRouter


async def main():
    router = AsyncRouter(host="0.0.0.0", port=6001)
    await router.start()
    print("Router running on 0.0.0.0:6001 — press Ctrl+C to stop.")
    await router.join()


if __name__ == "__main__":
    asyncio.run(main())
