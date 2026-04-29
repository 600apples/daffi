"""
router/07_serde_msgpack — Worker.

Accepts dict payloads via MSGPACK serialisation.

Requires:  pip install 'daffi[msgpack]'

Start 1_router.py first, then this, then 3_caller.py.
"""
import os
from daffi import Client, callback

WORKER_NAME = os.environ.get("WORKER_NAME", "mp-worker-1")


@callback
def enrich(record: dict) -> dict:
    record = dict(record)
    record["worker"] = WORKER_NAME
    record["processed"] = True
    print(f"[{WORKER_NAME}] enrich: {record}")
    return record


if __name__ == "__main__":
    worker = Client(app_name=WORKER_NAME, host="0.0.0.0", port=6007)
    worker.connect()
    print(f"Worker {WORKER_NAME!r} connected — press Ctrl+C to stop.")
    worker.join()
