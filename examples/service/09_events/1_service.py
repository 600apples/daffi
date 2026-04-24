"""
service/09_events — Service side.

add_event_handler() lets you react to nodes joining and leaving the network.
The framework fires the handler whenever any Client connects or disconnects.

Event dict keys:
  "type"   — "connected" or "disconnected"
  "member" — app_name of the node whose state changed

Multiple handlers can be registered; they run in registration order.

Run first, then run 2_client.py.
"""
import time
from daffi import Service, callback


@callback
def ping(msg: str) -> str:
    return f"pong: {msg}"


if __name__ == "__main__":
    connected_clients: set[str] = set()

    def on_event(event: dict) -> None:
        name = event["member"]
        if event["type"] == "connected":
            connected_clients.add(name)
            print(f"[service] ✦ {name!r} connected   (total: {len(connected_clients)})")
        elif event["type"] == "disconnected":
            connected_clients.discard(name)
            print(f"[service] ✦ {name!r} disconnected (total: {len(connected_clients)})")

    svc = Service(app_name="event-service", host="127.0.0.1", port=5009)
    svc.add_event_handler(on_event)
    svc.start()
    print("Service running on 127.0.0.1:5009 — press Ctrl+C to stop.")
    svc.join()
