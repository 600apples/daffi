"""
aio/service/10_stream — Service side (async).

Each chunk arrives as a separate async callback invocation.  The service
can await persistence or network I/O between chunks without blocking.

Run first, then run 2_client.py.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncService

_chunks: list[bytes] = []


@callback
async def receive_chunk(data: bytes) -> None:
    _chunks.append(data)
    total = sum(len(c) for c in _chunks)
    print(f"[service] chunk {len(_chunks):>3}: {len(data)} bytes  {data!r}  "
          f"(total so far: {total} bytes)")
    await asyncio.sleep(0)   # simulate async storage write


async def main():
    svc = AsyncService(app_name="stream-service", host="0.0.0.0", port=5010)
    await svc.start()
    print("Service running on 0.0.0.0:5010 — press Ctrl+C to stop.")
    await svc.join()


if __name__ == "__main__":
    asyncio.run(main())
