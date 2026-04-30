"""
aio/service/09_events — Service side (async).

add_event_handler() accepts async coroutines.  Using an async handler means
membership events are dispatched in the event loop — no extra threads.

Event dict keys:
  "type"   — "connected" or "disconnected"
  "member" — app_name of the node whose state changed

Run first, then run 2_client.py.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncService


@callback
async def ping(msg: str) -> str:
    await asyncio.sleep(0)
    return f"pong: {msg}"


async def main():
    connected_clients: set[str] = set()

    async def on_event(event: dict) -> None:
        name = event["member"]
        if event["type"] == "connected":
            connected_clients.add(name)
            print(f"[service] ✦ {name!r} connected   (total: {len(connected_clients)})")
        elif event["type"] == "disconnected":
            connected_clients.discard(name)
            print(f"[service] ✦ {name!r} disconnected (total: {len(connected_clients)})")

    svc = AsyncService(app_name="event-service", host="0.0.0.0", port=5009)
    svc.add_event_handler(on_event)
    await svc.start()
    print("Service running on 0.0.0.0:5009 — press Ctrl+C to stop.")
    await svc.join()


if __name__ == "__main__":
    asyncio.run(main())
