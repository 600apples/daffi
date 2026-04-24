"""
router/03_bidirectional — Router.

In bidirectional mode every connected node is both a caller AND a worker.
Node A can call functions on Node B, and Node B can call functions on Node A —
all through the same Router.

Start first, then 2_node_b.py, then 3_node_a.py.
"""
from daffi import Router


if __name__ == "__main__":
    router = Router(host="127.0.0.1", port=6003)
    router.start()
    print("Router running on 127.0.0.1:6003 — press Ctrl+C to stop.")
    router.join()
