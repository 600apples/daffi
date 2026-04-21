"""
service/02_cast — Client side.

Demonstrates cast() and cast_nowait():

  cast()        — blocking broadcast; waits for all matching nodes to respond
                  and returns {node_name: result} dict.
  cast_nowait() — fire-and-forget broadcast; returns immediately.

Run 1_service.py first.
"""
from daffi import Client


if __name__ == "__main__":
    client = Client(app_name="cast-client", host="127.0.0.1", port=5002)
    conn = client.connect()

    # cast() — broadcast to all nodes that expose 'notify', wait for results.
    cast = conn.cast(timeout=5)
    results = cast.notify("hello from cast")
    print(f"cast results: {results}")
    # e.g. {"notify-service": "ack: hello from cast"}

    # cast_nowait() — fire-and-forget; no result is waited for.
    cast_nowait = conn.cast_nowait()
    cast_nowait.notify("fire and forget")
    print("cast_nowait sent (no result waited for)")

    client.stop()
    print("Done.")
