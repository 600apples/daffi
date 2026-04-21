"""
router/02_cast — Caller.

Demonstrates cast() and cast_nowait() via a Router:

  cast()        — fan-out to ALL workers that expose 'process'; collect results.
  cast_nowait() — fire-and-forget fan-out; no result waited for.

Tip: start 2_worker.py twice with different WORKER_NAME env vars to see
     the dict contain two entries.

Run 1_router.py and 2_worker.py first.
"""
from daffi import Client


if __name__ == "__main__":
    caller = Client(app_name="cast-caller", host="127.0.0.1", port=6002)
    conn = caller.connect()

    # cast() — blocking; waits for every worker and returns {name: result}.
    cast = conn.cast(timeout=5)
    results = cast.process("task-A")
    print(f"cast results: {results}")

    # cast to a subset of workers by name.
    cast_subset = conn.cast(timeout=5, receiver=["worker-1"])
    results = cast_subset.process("task-B")
    print(f"cast (subset) results: {results}")

    # cast_nowait() — fire-and-forget; returns None immediately.
    cast_nowait = conn.cast_nowait()
    cast_nowait.process("task-C")
    print("cast_nowait sent")

    caller.stop()
    print("Done.")
