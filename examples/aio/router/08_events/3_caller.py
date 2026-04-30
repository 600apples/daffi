"""
aio/router/08_events — Caller (async).

Registers an async event handler to observe membership changes.
The Router delivers "connected"/"disconnected" events whenever any node
joins or leaves.

Run 1_router.py and 2_worker.py first.
"""
import asyncio
from daffi.aio import AsyncClient


async def main():
    async def on_event(event: dict) -> None:
        name = event["member"]
        status = event["type"]
        print(f"[caller] event: {name!r} → {status}")

    caller = AsyncClient(app_name="event-caller", host="0.0.0.0", port=6008)
    caller.add_event_handler(on_event)
    conn = await caller.connect()

    result = await conn.rpc(timeout=5).ping("hello from caller")
    print(f"rpc ping result: {result!r}")

    await asyncio.sleep(0.3)

    await caller.stop()
    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())
