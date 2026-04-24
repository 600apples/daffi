"""
router/03_bidirectional — Node B.

Node B exposes a 'greet' callback and waits.  Node A will call it, then
Node B calls back a function exposed by Node A.

Start 1_router.py first, then this, then 3_node_a.py.
"""
import time
from daffi import Client, callback


@callback
def greet(name: str) -> str:
    print(f"[node-b] greet({name!r})")
    return f"Hello, {name}! — from node-b"


if __name__ == "__main__":
    node = Client(app_name="node-b", host="127.0.0.1", port=6003)
    conn = node.connect()
    print("Node B connected — press Ctrl+C to stop.")

    # Wait until node-a connects and exposes its callbacks.
    time.sleep(2)

    rpc_a = conn.rpc(timeout=5, receiver="node-a")
    result = rpc_a.status()
    print(f"[node-b] node-a status: {result!r}")

    import signal
    signal.pause()
