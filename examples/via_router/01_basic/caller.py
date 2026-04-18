"""
Caller node – connects to the router and calls functions on the worker.

The router transparently routes each call to the node that registered
the requested function (math-worker in this example).

Start router.py and worker.py first, then run this script.
"""
from daffi import Client


if __name__ == "__main__":
    client = Client(app_name="caller", host="127.0.0.1", port=6000)
    conn = client.connect()

    # receiver="math-worker" pins the call to that specific node.
    # Leave receiver=None to let the router pick any node with the function.
    c = conn.rpc(timeout=5, receiver="math-worker")

    print(f"add(3, 4)       = {c.add(3, 4)}")
    print(f"multiply(6, 7)  = {c.multiply(6, 7)}")

    client.stop()
    print("Done.")
