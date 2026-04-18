"""
Client process – sends events to the service without waiting for results.

cast() sends each call as fire-and-forget.  A final call() to flush()
confirms how many events the service received.

Start service.py first, then run this script.
"""
import time
from daffi import Client

EVENTS = [
    ("auth",    "info",  "user alice logged in"),
    ("payment", "info",  "transaction 0x1a2b processed"),
    ("auth",    "warn",  "failed login attempt for user bob"),
    ("storage", "error", "disk usage above 90 %"),
    ("payment", "info",  "transaction 0x3c4d processed"),
]

if __name__ == "__main__":
    client = Client(app_name="log-producer", host="127.0.0.1", port=5003)
    conn = client.connect()

    cast = conn.rpc_nowait()           # fire-and-forget, no return value awaited
    c    = conn.rpc(timeout=5)  # blocking call for the final confirmation

    print(f"Sending {len(EVENTS)} events …")
    for source, level, message in EVENTS:
        cast.ingest_event(source, level, message)

    # Small pause so the service has time to process all sent messages
    # before we ask for the count.
    time.sleep(0.1)

    total = c.flush()
    print(f"Service confirmed {total} events stored.")

    client.stop()
    print("Done.")
