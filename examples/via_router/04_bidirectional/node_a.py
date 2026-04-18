"""
Node A – both a caller and a callee.

* Registers @callback functions so node_b can call it.
* After connecting, calls functions registered by node_b.

Because both nodes connect to the same Router every node can call every
other node's registered functions.

Start router.py first, then start node_b.py, then run this script.
"""
import time
from daffi import Client, callback


@callback
def ping(message: str) -> str:
    print(f"[node-a] ping received: {message!r}")
    return f"pong from node-a: {message}"


@callback
def status() -> dict:
    print("[node-a] status requested")
    return {"node": "node-a", "uptime": time.monotonic(), "healthy": True}


if __name__ == "__main__":
    client = Client(app_name="node-a", host="127.0.0.1", port=6003)
    conn = client.connect()
    print("Node A connected to router.")

    # Wait for node-b to be available.
    print("Waiting for node-b …")
    while True:
        cb_probe = conn.rpc(timeout=1, receiver="node-b")
        try:
            result = cb_probe.ping("hello from node-a")
            print(f"node-b replied: {result!r}")
            break
        except Exception:
            time.sleep(0.2)

    # Regular exchange
    cb = conn.rpc(timeout=5, receiver="node-b")

    print(f"\nnode-b status : {cb.status()}")
    print(f"node-b echo   : {cb.echo('test payload')!r}")

    client.stop()
    print("Node A done.")
