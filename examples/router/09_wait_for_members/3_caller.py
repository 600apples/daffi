"""
router/09_wait_for_members — Caller.

Demonstrates conn.wait_for_members(): the caller connects to the Router and
blocks until the required worker(s) appear in the member list before issuing
any RPC call.  This lets you start the caller and the worker in any order
without sprinkling manual sleep() calls or error-retry loops throughout your
code.

Start 1_router.py first.  Then start this script and 2_worker.py in any
order — the caller will wait automatically.
"""
from daffi import Client

if __name__ == "__main__":
    caller = Client(app_name="calc-caller", host="0.0.0.0", port=6009)
    conn = caller.connect()

    print("Connected to router.  Waiting for 'calc-worker' to come online…")

    # Block here (polling every 1 s) until the worker registers itself.
    # Pass timeout=<seconds> to raise TimeoutError if it never arrives.
    conn.wait_for_members("calc-worker")

    print("calc-worker is online — issuing RPC calls.")

    for n in range(1, 6):
        result = conn.rpc(timeout=10, receiver="calc-worker").process(n)
        print(f"  process({n}) = {result}")

    caller.stop()
    print("Done.")
