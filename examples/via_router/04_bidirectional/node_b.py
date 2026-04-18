"""
Node B – both a callee and a caller.

* Registers @callback functions so node_a can call it.
* After connecting, calls functions registered by node_a.

Start router.py first, then start this process, then run node_a.py.
"""
import time
from daffi import Client, callback


@callback
def ping(message: str) -> str:
    print(f"[node-b] ping received: {message!r}")
    return f"pong from node-b: {message}"


@callback
def echo(payload: str) -> str:
    print(f"[node-b] echo: {payload!r}")
    return payload


@callback
def status() -> dict:
    print("[node-b] status requested")
    return {"node": "node-b", "uptime": time.monotonic(), "healthy": True}


if __name__ == "__main__":
    client = Client(app_name="node-b", host="127.0.0.1", port=6003)
    conn = client.connect()
    print("Node B connected to router.")

    # Wait for node-a to register its functions and call back.
    ca = conn.rpc(timeout=5, receiver="node-a")
    print("Waiting for node-a …")
    while True:
        try:
            result = ca.ping("hello from node-b")
            print(f"node-a replied: {result!r}")
            break
        except Exception:
            time.sleep(0.2)

    print(f"\nnode-a status : {ca.status()}")

    # Stay alive so node_a can call us after it connects.
    print("Node B staying alive – waiting for calls from node-a …")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        client.stop()
