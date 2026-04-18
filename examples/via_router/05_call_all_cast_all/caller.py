"""
Caller – demonstrates all four call styles with multiple workers.

Setup (run each in a separate terminal):
    1. python router.py
    2. python worker.py worker-1
    3. python worker.py worker-2
    4. python caller.py         ← this script

rpc()          — one worker, blocking, returns result
rpc_nowait()   — one worker, fire-and-forget
cast()         — all matching workers, blocking, returns {name: result} dict
cast_nowait()  — all matching workers, fire-and-forget
"""
import time
from daffi import Client


if __name__ == "__main__":
    client = Client(app_name="caller", host="127.0.0.1", port=6005)
    conn = client.connect()

    # Give workers a moment to register their methods with the router.
    time.sleep(0.2)

    # ------------------------------------------------------------------ #
    # rpc() — one worker, blocking                                        #
    # ------------------------------------------------------------------ #
    # receiver=None → router picks a worker via round-robin.
    result = conn.rpc(timeout=5).compute(10)
    print(f"rpc().compute(10)                          = {result}  (one worker)")

    # Pin to a specific worker by name.
    result = conn.rpc(timeout=5, receiver="worker-1").compute(20)
    print(f"rpc(receiver='worker-1').compute(20)       = {result}")

    # ------------------------------------------------------------------ #
    # rpc_nowait() — one worker, fire-and-forget                          #
    # ------------------------------------------------------------------ #
    conn.rpc_nowait().invalidate_cache("session:abc")
    print("rpc_nowait().invalidate_cache(…)             (one worker, no result)")

    time.sleep(0.1)  # give the worker time to print before moving on

    # ------------------------------------------------------------------ #
    # cast() — all workers, blocking, returns {name: result}             #
    # ------------------------------------------------------------------ #
    # Auto-discover: every connected worker that exposes compute() is called.
    results = conn.cast(timeout=5).compute(5)
    print(f"\ncast().compute(5)                          = {results}")
    # e.g. {"worker-1": 10, "worker-2": 10}

    # Explicitly name which workers to include.
    results = conn.cast(timeout=5, receiver=["worker-1"]).status()
    print(f"cast(receiver=['worker-1']).status()        = {results}")

    # ------------------------------------------------------------------ #
    # cast_nowait() — all workers, fire-and-forget                        #
    # ------------------------------------------------------------------ #
    conn.cast_nowait().invalidate_cache("global:config")
    print("\ncast_nowait().invalidate_cache(…)            (all workers, no result)")

    time.sleep(0.2)  # give workers time to print before the process exits

    client.stop()
    print("\nDone.")
