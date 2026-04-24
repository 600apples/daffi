"""
router/09_wait_for_members — Worker.

Exposes a slow `process` callback that the caller waits to become available
before invoking.

Start after 1_router.py.  The caller (3_caller.py) blocks in
wait_for_members() until this worker has registered itself, so the startup
order of 2_worker.py and 3_caller.py does not matter.
"""
import time
from daffi import Client, callback


@callback
def process(value: int) -> dict:
    time.sleep(0.1)  # simulate work
    result = value ** 2
    print(f"[worker] process({value}) = {result}")
    return {"input": value, "result": result}


if __name__ == "__main__":
    worker = Client(app_name="calc-worker", host="127.0.0.1", port=6009)
    worker.connect()
    print("Worker connected — press Ctrl+C to stop.")
    import signal
    signal.pause()
