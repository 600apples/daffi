"""
router/08_events — Caller.

Registers an event handler to observe membership changes as seen by the
caller.  The Router delivers a "connected" event when a new node joins
and a "disconnected" event when it leaves.

Run 1_router.py and 2_worker.py first.
"""
import time
from daffi import Client


if __name__ == "__main__":
    def on_event(event: dict) -> None:
        name = event["member"]
        status = event["type"]
        print(f"[caller] event: {name!r} → {status}")

    caller = Client(app_name="event-caller", host="127.0.0.1", port=6008)
    caller.add_event_handler(on_event)
    conn = caller.connect()

    rpc = conn.rpc(timeout=5)
    result = rpc.ping("hello from caller")
    print(f"rpc ping result: {result!r}")

    time.sleep(0.3)

    caller.stop()
    print("Done.")
