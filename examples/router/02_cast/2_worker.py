"""
router/02_cast — Worker.

Exposes a 'process' callback.  Start multiple instances of this script
(with different app_name env vars if needed) to see cast() fan out to all.

Start 1_router.py first, then one or more instances of this, then 3_caller.py.
"""
import os
from daffi import Client, callback

WORKER_NAME = os.environ.get("WORKER_NAME", "worker-1")


@callback
def process(item: str) -> str:
    print(f"[{WORKER_NAME}] process({item!r})")
    return f"{WORKER_NAME}: processed {item!r}"


if __name__ == "__main__":
    worker = Client(app_name=WORKER_NAME, host="127.0.0.1", port=6002)
    worker.connect()
    print(f"Worker {WORKER_NAME!r} connected — press Ctrl+C to stop.")
    import signal
    signal.pause()
