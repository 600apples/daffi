"""
aio/service/03_class_callbacks — Service side (async).

Applying @callback to a class automatically registers every public method
as a remote callback.  Methods decorated with @local are excluded.

All public methods here are async — they are awaited by the
AsyncTaskDispatcher without spawning threads.

Run first, then run 2_client.py.
"""
import asyncio
from daffi import callback
from daffi.registry import local
from daffi.aio import AsyncService


@callback
class TextProcessor:
    """All public async methods become remote callbacks; @local ones do not."""

    def __init__(self):
        self._call_count = 0

    async def upper(self, text: str) -> str:
        self._call_count += 1
        print(f"[service] upper({text!r})  [call #{self._call_count}]")
        await asyncio.sleep(0)
        return text.upper()

    async def reverse(self, text: str) -> str:
        self._call_count += 1
        print(f"[service] reverse({text!r})  [call #{self._call_count}]")
        await asyncio.sleep(0)
        return text[::-1]

    async def word_count(self, text: str) -> int:
        self._call_count += 1
        print(f"[service] word_count({text!r})  [call #{self._call_count}]")
        await asyncio.sleep(0)
        return len(text.split())

    @local
    def reset(self):
        """@local — not exported; only callable within this process."""
        self._call_count = 0


async def main():
    svc = AsyncService(app_name="text-service", host="0.0.0.0", port=5003)
    await svc.start()
    print("Service running on 0.0.0.0:5003 — press Ctrl+C to stop.")
    await svc.join()


if __name__ == "__main__":
    asyncio.run(main())
