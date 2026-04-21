"""
router/03_bidirectional — Node A.

Node A exposes a 'status' callback and also calls Node B's 'greet' function.
Both nodes are clients of the same Router and can call each other.

Run 1_router.py and 2_node_b.py first.
"""
from daffi import Client, callback


@callback
def status() -> str:
    print("[node-a] status() called")
    return "node-a is alive"


if __name__ == "__main__":
    node = Client(app_name="node-a", host="127.0.0.1", port=6003)
    conn = node.connect()
    print("Node A connected.")

    # Call a function that lives on node-b.
    rpc_b = conn.rpc(timeout=5, receiver="node-b")
    result = rpc_b.greet("node-a")
    print(f"[node-a] greet result: {result!r}")

    import time
    time.sleep(3)   # let node-b call us back

    node.stop()
    print("Done.")
