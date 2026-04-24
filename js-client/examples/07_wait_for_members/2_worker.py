"""
js/07_wait_for_members — Python worker.

Exposes callbacks reachable from the browser via JSON.  The browser calls
waitForMembers('py-worker') before issuing any RPC so the startup order of
this script and the browser page does not matter.

Start after 1_router.py.
"""
import time
from daffi import Client, callback


@callback
def process(value: int) -> dict:
    time.sleep(0.05)  # simulate work
    result = value ** 2
    print(f"[py-worker] process({value}) = {result}")
    return {"input": value, "result": result}


@callback
def ping() -> str:
    print("[py-worker] ping()")
    return "pong from py-worker"


if __name__ == "__main__":
    worker = Client(app_name="py-worker", host="127.0.0.1", port=6030)
    worker.connect()
    print("Worker connected to router — press Ctrl+C to stop.")
    import signal
    signal.pause()
