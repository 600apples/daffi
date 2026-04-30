"""
aio/service/01_rpc — Service side (async).

AsyncService is the async counterpart of Service.  start(), join(), and
stop() are coroutines.  @callback functions can be declared as async def
and will be awaited directly by the AsyncTaskDispatcher.

Run first, then run 2_client.py.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncService


@callback
async def add(a: int, b: int) -> int:
    print(f"[service] add({a}, {b})")
    await asyncio.sleep(0)
    return a + b


async def main():
    svc = AsyncService(app_name="calc-service", host="0.0.0.0", port=5001)
    await svc.start()
    print("Service running on 0.0.0.0:5001 — press Ctrl+C to stop.")
    await svc.join()


if __name__ == "__main__":
    asyncio.run(main())
