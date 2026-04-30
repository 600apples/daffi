"""
aio/router/03_bidirectional — Node B (async).

Uses AsyncClient as both a worker (registers 'greet') and a caller
(calls 'status' on node-a).  Both nodes are peers — neither is a
dedicated server.

Start 1_router.py first, then this, then 3_node_a.py.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncClient


@callback
async def greet(name: str) -> str:
    print(f"[node-b] greet({name!r}) called")
    await asyncio.sleep(0)
    return f"Hello, {name}! — from node-b"


async def main():
    node = AsyncClient(app_name="node-b", host="0.0.0.0", port=6003)
    conn = await node.connect()
    print("node-b connected — waiting for node-a…")

    await conn.wait_for_members("node-a", timeout=30)
    print("node-a is online — calling status()")

    result = await conn.rpc(timeout=5, receiver="node-a").status()
    print(f"[node-b] node-a replied: {result!r}")

    await asyncio.sleep(3)
    await node.stop()


if __name__ == "__main__":
    asyncio.run(main())
