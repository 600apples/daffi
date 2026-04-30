"""
aio/service/09_events — Client side (async).

AsyncClient can subscribe to membership events via add_event_handler().
The async handler fires when the service connects or disconnects.

Run 1_service.py first.
"""
import asyncio
from daffi.aio import AsyncClient


async def main():
    async def on_event(event: dict) -> None:
        name = event["member"]
        status = event["type"]   # "connected" or "disconnected"
        print(f"[client] event: {name!r} → {status}")

    client = AsyncClient(app_name="event-client", host="0.0.0.0", port=5009)
    client.add_event_handler(on_event)

    conn = await client.connect()

    result = await conn.rpc(timeout=5).ping("hello")
    print(f"rpc: ping('hello') = {result!r}")

    await asyncio.sleep(0.2)

    await client.stop()
    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())
