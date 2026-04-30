"""
aio/router/03_bidirectional — Node A (async).

Uses AsyncClient as both a worker (registers 'status') and a caller
(calls 'greet' on node-b).

Start 1_router.py and 2_node_b.py first, then this.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncClient


@callback
async def status() -> str:
    print("[node-a] status() called")
    await asyncio.sleep(0)
    return "node-a is alive"


async def main():
    node = AsyncClient(app_name="node-a", host="0.0.0.0", port=6003)
    conn = await node.connect()
    print("node-a connected — waiting for node-b…")

    await conn.wait_for_members("node-b", timeout=30)
    print("node-b is online — calling greet()")

    result = await conn.rpc(timeout=5, receiver="node-b").greet("node-a")
    print(f"[node-a] node-b replied: {result!r}")

    await asyncio.sleep(3)
    await node.stop()


if __name__ == "__main__":
    asyncio.run(main())
