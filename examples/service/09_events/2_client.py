"""
service/09_events — Client side.

Clients can also subscribe to events via add_event_handler().
The handler fires when the service (or other nodes) connects or disconnects
from the client's perspective.

Run 1_service.py first.
"""
import time
from daffi import Client


if __name__ == "__main__":
    def on_event(event: dict) -> None:
        name = event["member"]
        status = event["type"]     # "connected" or "disconnected"
        print(f"[client] event: {name!r} → {status}")

    client = Client(app_name="event-client", host="127.0.0.1", port=5009)
    client.add_event_handler(on_event)

    conn = client.connect()
    # The service fires a "connected" event on its side; the client fires one too.

    rpc = conn.rpc(timeout=5)
    result = rpc.ping("hello")
    print(f"rpc: ping('hello') = {result!r}")

    # Pause so the service can print the connection event before we disconnect.
    time.sleep(0.2)

    client.stop()
    # Stopping triggers a "disconnected" event on the service side.
    print("Done.")
