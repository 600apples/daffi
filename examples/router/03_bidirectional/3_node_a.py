"""
router/03_bidirectional — Node A.

Registers a 'status' callback, waits for node-b, then calls greet() on it.
Node B does the symmetric thing — each node is both a caller and a worker.

Start 1_router.py and 2_node_b.py first, then this.
"""
import time

from daffi import Client, callback


@callback
def status() -> str:
    print("[node-a] status() called")
    return "node-a is alive"


if __name__ == "__main__":
    node = Client(app_name="node-a", host="0.0.0.0", port=6003)
    conn = node.connect()
    print("node-a connected — waiting for node-b…")

    conn.wait_for_members("node-b", timeout=30)
    print("node-b is online — calling greet()")

    result = conn.rpc(timeout=5, receiver="node-b").greet("node-a")
    print(f"[node-a] node-b replied: {result!r}")

    time.sleep(3)
    node.stop()
