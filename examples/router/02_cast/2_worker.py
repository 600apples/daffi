"""
router/02_cast — Worker.

Run this script in 3 separate terminals:

  Terminal 1:  python 2_worker.py
  Terminal 2:  python 2_worker.py
  Terminal 3:  python 2_worker.py

Start 1_router.py first, then the workers, then 3_caller.py.
"""
import random

from daffi import Client, callback

TAG = random.choice(["🔵", "🟢", "🟡", "🔴", "🟣", "🟠"])


@callback
def process(item: str) -> str:
    return TAG


if __name__ == "__main__":
    worker = Client(host="0.0.0.0", port=6002)
    worker.connect()
    print(f"{TAG}  worker connected — press Ctrl+C to stop.")
    worker.join()
