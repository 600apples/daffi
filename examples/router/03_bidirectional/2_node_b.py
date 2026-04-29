"""
router/03_bidirectional — Node B.

Registers a 'greet' callback, waits for node-a, then calls status() on it.
Node A does the symmetric thing — each node is both a caller and a worker.

Start 1_router.py first, then this, then 3_node_a.py.
"""
import time

from daffi import Client, callback


@callback
def greet(name: str) -> str:
    print(f"[node-b] greet({name!r}) called")
    return f"Hello, {name}! — from node-b"


if __name__ == "__main__":
    node = Client(app_name="node-b", host="0.0.0.0", port=6003)
    conn = node.connect()
    print("node-b connected — waiting for node-a…")

    conn.wait_for_members("node-a", timeout=30)
    print("node-a is online — calling status()")

    result = conn.rpc(timeout=5, receiver="node-a").status()
    print(f"[node-b] node-a replied: {result!r}")

    time.sleep(3)
    node.stop()
