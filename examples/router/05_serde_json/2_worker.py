"""
router/05_serde_json — Worker.

Accepts plain dict payloads via JSON serialisation and returns a dict.

Start 1_router.py first, then this, then 3_caller.py.
"""
import os
from daffi import Client, callback

WORKER_NAME = os.environ.get("WORKER_NAME", "json-worker-1")


@callback
def compute_stats(data: dict) -> dict:
    values = data.get("values", [])
    if not values:
        return {"count": 0, "sum": 0, "avg": 0}
    total = sum(values)
    result = {"count": len(values), "sum": total, "avg": round(total / len(values), 4)}
    print(f"[{WORKER_NAME}] compute_stats → {result}")
    return result


if __name__ == "__main__":
    worker = Client(app_name=WORKER_NAME, host="127.0.0.1", port=6005)
    worker.connect()
    print(f"Worker {WORKER_NAME!r} connected — press Ctrl+C to stop.")
    import signal
    signal.pause()
