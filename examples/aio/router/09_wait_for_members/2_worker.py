"""
aio/router/09_wait_for_members — Worker (async).

Exposes an async `process` callback.  The caller blocks in
wait_for_members() until this worker registers, so startup order
between 2_worker.py and 3_caller.py does not matter.

Start after 1_router.py.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncClient


@callback
async def process(value: int) -> dict:
    await asyncio.sleep(0.1)   # simulate async I/O
    result = value ** 2
    print(f"[worker] process({value}) = {result}")
    return {"input": value, "result": result}


async def main():
    worker = AsyncClient(app_name="calc-worker", host="0.0.0.0", port=6009)
    await worker.connect()
    print("Worker connected — press Ctrl+C to stop.")
    await worker.join()


if __name__ == "__main__":
    asyncio.run(main())
