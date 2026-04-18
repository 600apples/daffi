"""
Worker node – connects to the router and exposes math functions.

Because it connects to a *Router* (not a Service) the client library
automatically starts a task-dispatcher so this node can receive and
execute incoming calls from any other node on the same router.

Start router.py first, then start this process, then run caller.py.
"""
import time
from daffi import Client, callback


@callback
def add(a: int, b: int) -> int:
    print(f"[worker] add({a}, {b})")
    return a + b


@callback
def multiply(a: int, b: int) -> int:
    print(f"[worker] multiply({a}, {b})")
    return a * b


if __name__ == "__main__":
    client = Client(app_name="math-worker", host="127.0.0.1", port=6000)
    client.connect()
    print("Math worker connected to router – waiting for calls. Press Ctrl+C to stop.")
    # Keep the process alive so the router can dispatch calls to it.
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        client.stop()
