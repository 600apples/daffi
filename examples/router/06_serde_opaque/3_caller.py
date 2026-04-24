"""
router/06_serde_opaque — Caller.

Sends pre-serialised bytes to the worker and reads the raw bytes response.
Also shows cast_nowait() for fire-and-forget broadcasts.

Run 1_router.py and 2_worker.py first.
"""
import json
from daffi import Client
from daffi.serialization import SerdeFormat


if __name__ == "__main__":
    caller = Client(app_name="opaque-caller", host="127.0.0.1", port=6006)
    conn = caller.connect()

    rpc = conn.rpc(timeout=5, serde=SerdeFormat.OPAQUE)

    for event_type in ["login", "logout", "purchase"]:
        raw = json.dumps({"type": event_type, "ts": 1713340800}).encode("utf-8")
        response_bytes = rpc.handle_raw(raw)
        response = json.loads(response_bytes)
        print(f"event={event_type!r}  response={response}")

    # cast_nowait — broadcast without waiting for results.
    cast_nowait = conn.cast_nowait(serde=SerdeFormat.OPAQUE)
    cast_nowait.handle_raw(json.dumps({"type": "shutdown"}).encode("utf-8"))
    print("cast_nowait sent")

    caller.stop()
    print("Done.")
