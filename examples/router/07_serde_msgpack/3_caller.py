"""
router/07_serde_msgpack — Caller.

Demonstrates all four call styles with MSGPACK serialisation:
  rpc()         — blocking, one worker
  rpc_nowait()  — fire-and-forget, one worker
  cast()        — blocking broadcast, all workers
  cast_nowait() — fire-and-forget broadcast, all workers

Requires:  pip install 'daffi[msgpack]'

Run 1_router.py and 2_worker.py first.
"""
import time
from daffi import Client
from daffi.serialization import SerdeFormat


if __name__ == "__main__":
    caller = Client(app_name="mp-caller", host="127.0.0.1", port=6007)
    conn = caller.connect()

    record = {"id": 1, "name": "widget", "value": 42}

    # rpc — blocking.
    rpc = conn.rpc(timeout=5, serde=SerdeFormat.MSGPACK)
    result = rpc.enrich(record)
    print(f"rpc result: {result}")

    # rpc_nowait — fire-and-forget.
    rpc_nowait = conn.rpc_nowait(serde=SerdeFormat.MSGPACK)
    rpc_nowait.enrich(record)
    print("rpc_nowait sent")

    time.sleep(0.1)

    # cast — broadcast, collect all.
    cast = conn.cast(timeout=5, serde=SerdeFormat.MSGPACK)
    all_results = cast.enrich(record)
    print(f"cast results: {all_results}")

    # cast_nowait — broadcast, no results.
    cast_nowait = conn.cast_nowait(serde=SerdeFormat.MSGPACK)
    cast_nowait.enrich(record)
    print("cast_nowait sent")

    caller.stop()
    print("Done.")
