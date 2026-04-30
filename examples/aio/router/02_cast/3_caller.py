"""
aio/router/02_cast — Caller (async).

Broadcasts to ALL connected workers and collects every response.

  await conn.cast()         — fan-out to all workers, collect {name: result}
  await conn.cast_nowait()  — fire-and-forget, no results collected

Start 1_router.py and 2_worker.py (×3) first.
"""
import asyncio
from daffi.aio import AsyncClient
from daffi._rpc_proxy import get_available_members


async def main():
    caller = AsyncClient(app_name="cast-caller", host="0.0.0.0", port=6002)
    conn = await caller.connect()

    workers = [
        m["name"]
        for m in get_available_members(caller._conn_num)
        if m["name"] != caller.app_name
    ]
    print(f"Connected workers: {workers}\n")

    results = await conn.cast(timeout=5).process("task-A")
    for name, reply in results.items():
        print(f"  {name}: {reply}")

    await conn.cast_nowait().process("task-B")
    print("  Sent (no reply collected)")

    await caller.stop()
    print("\nDone.")


if __name__ == "__main__":
    asyncio.run(main())
