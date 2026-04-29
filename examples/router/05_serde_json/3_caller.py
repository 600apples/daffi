"""
router/05_serde_json — Caller.

Shows all four call styles with JSON serialisation:
  rpc()         — blocking, single worker
  rpc_nowait()  — fire-and-forget, single worker
  cast()        — blocking broadcast, all workers
  cast_nowait() — fire-and-forget broadcast, all workers

Run 1_router.py and 2_worker.py first.
"""
import time
from daffi import Client
from daffi import SerdeFormat


BATCH = {"values": [10, 20, 30, 40, 50]}

if __name__ == "__main__":
    caller = Client(app_name="json-caller", host="0.0.0.0", port=6005)
    conn = caller.connect()

    # rpc — blocking call to one worker.
    rpc = conn.rpc(timeout=5, serde=SerdeFormat.JSON)
    stats = rpc.compute_stats(BATCH)
    print(f"rpc result: {stats}")

    # rpc_nowait — fire-and-forget to one worker.
    rpc_nowait = conn.rpc_nowait(serde=SerdeFormat.JSON)
    rpc_nowait.compute_stats(BATCH)
    print("rpc_nowait sent")

    time.sleep(0.1)

    # cast — broadcast to all workers, collect results.
    cast = conn.cast(timeout=5, serde=SerdeFormat.JSON)
    all_stats = cast.compute_stats(BATCH)
    print(f"cast results: {all_stats}")

    # cast_nowait — broadcast, no results.
    cast_nowait = conn.cast_nowait(serde=SerdeFormat.JSON)
    cast_nowait.compute_stats(BATCH)
    print("cast_nowait sent")

    caller.stop()
    print("Done.")
