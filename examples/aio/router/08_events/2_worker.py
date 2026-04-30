"""
aio/router/08_events — Worker (async).

Uses add_event_handler() with an async coroutine to track which other
nodes are online.  Async handlers are awaited in the event loop — no
thread-pool spawned for membership events.

Start 1_router.py first, then this, then 3_caller.py.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncClient


@callback
async def ping(msg: str) -> str:
    await asyncio.sleep(0)
    return f"pong: {msg}"


async def main():
    online_nodes: set[str] = set()

    async def on_event(event: dict) -> None:
        name = event["member"]
        if event["type"] == "connected":
            online_nodes.add(name)
            print(f"[worker] ✦ {name!r} joined  — online: {sorted(online_nodes)}")
        elif event["type"] == "disconnected":
            online_nodes.discard(name)
            print(f"[worker] ✦ {name!r} left    — online: {sorted(online_nodes)}")

    worker = AsyncClient(app_name="event-worker", host="0.0.0.0", port=6008)
    worker.add_event_handler(on_event)
    await worker.connect()
    print("Worker connected — press Ctrl+C to stop.")
    await worker.join()


if __name__ == "__main__":
    asyncio.run(main())
