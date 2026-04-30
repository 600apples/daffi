"""
router/01_rpc — Caller.

Connects to the Router and calls the worker's 'multiply' function.
conn.rpc() picks a worker using round-robin; conn.rpc(receiver="name")
pins the call to a specific worker.

Run 1_router.py and 2_worker.py first.
"""
from daffi import Client
import time

if __name__ == "__main__":
    caller = Client(app_name="calc-caller", host="192.168.1.101", port=6001)
    conn = caller.connect()

    rpc = conn.rpc(timeout=100)


    result = rpc.multiply(6, 7)
    print(f"multiply(6, 7) = {result}")

    # Pin the call to a specific worker by name.
    rpc_pinned = conn.rpc(timeout=500, receiver="calc-worker")
    while True:
        time.sleep(100)

        result = rpc_pinned.multiply(3, 3)
        print(f"multiply(3, 3) [pinned to calc-worker] = {result}")

    caller.stop()
    print("Done.")
