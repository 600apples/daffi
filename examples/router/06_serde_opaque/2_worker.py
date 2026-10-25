"""
router/06_serde_opaque — Worker.

Receives raw bytes via OPAQUE serialisation, parses them as JSON,
and returns the processed result as raw bytes.

Start 1_router.py first, then this, then 3_caller.py.
"""

import json
import os
from daffi import Client, callback, TCPTransport

WORKER_NAME = os.environ.get("WORKER_NAME", "opaque-worker-1")


@callback
def handle_raw(payload: bytes) -> bytes:
    data = json.loads(payload)
    print(f"[{WORKER_NAME}] handle_raw: type={data.get('type')!r}")
    response = {"status": "ok", "worker": WORKER_NAME, "echo": data.get("type")}
    return json.dumps(response).encode("utf-8")


if __name__ == "__main__":
    worker = Client(app_name=WORKER_NAME, transport=TCPTransport("0.0.0.0", 6006))
    worker.connect()
    print(f"Worker {WORKER_NAME!r} connected — press Ctrl+C to stop.")
    worker.join()
