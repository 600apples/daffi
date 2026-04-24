"""
router/08_events — Worker.

Uses add_event_handler() to track which other nodes are online.
The Router broadcasts "connected" / "disconnected" events to every
connected node whenever the membership changes.

Start 1_router.py first, then this, then 3_caller.py.
"""
import signal
from daffi import Client, callback


@callback
def ping(msg: str) -> str:
    return f"pong: {msg}"


if __name__ == "__main__":
    online_nodes: set[str] = set()

    def on_event(event: dict) -> None:
        name = event["member"]
        if event["type"] == "connected":
            online_nodes.add(name)
            print(f"[worker] ✦ {name!r} joined  — online: {sorted(online_nodes)}")
        elif event["type"] == "disconnected":
            online_nodes.discard(name)
            print(f"[worker] ✦ {name!r} left    — online: {sorted(online_nodes)}")

    worker = Client(app_name="event-worker", host="127.0.0.1", port=6008)
    worker.add_event_handler(on_event)
    conn = worker.connect()
    print("Worker connected — press Ctrl+C to stop.")
    signal.pause()
