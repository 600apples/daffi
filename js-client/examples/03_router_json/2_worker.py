"""
js/03_router_json — Python worker.

Connects to the Router and exposes callbacks reachable from the
browser via JSON serde.

Start 1_router.py first, then this, then open index.html.
"""
from daffi import Client, callback


@callback
def reverse(text: str) -> str:
    result = text[::-1]
    print(f"[worker] reverse({text!r}) = {result!r}")
    return result


@callback
def word_count(text: str) -> int:
    count = len(text.split())
    print(f"[worker] word_count({text!r}) = {count}")
    return count


if __name__ == "__main__":
    worker = Client(app_name="json-worker", host="127.0.0.1", port=6010)
    worker.connect()
    print("Worker connected to router — press Ctrl+C to stop.")
    worker.join()
