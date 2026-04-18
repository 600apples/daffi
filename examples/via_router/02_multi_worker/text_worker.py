"""
Text worker – exposes string-processing functions via the router.

Start router.py first, then start this process and math_worker.py,
then run caller.py.
"""
import time
from daffi import Client, callback


@callback
def upper(text: str) -> str:
    print(f"[text-worker] upper({text!r})")
    return text.upper()


@callback
def lower(text: str) -> str:
    print(f"[text-worker] lower({text!r})")
    return text.lower()


@callback
def reverse(text: str) -> str:
    print(f"[text-worker] reverse({text!r})")
    return text[::-1]


@callback
def word_count(text: str) -> int:
    print(f"[text-worker] word_count({text!r})")
    return len(text.split())


if __name__ == "__main__":
    client = Client(app_name="text-worker", host="127.0.0.1", port=6001)
    client.connect()
    print("Text worker connected – waiting for calls.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        client.stop()
