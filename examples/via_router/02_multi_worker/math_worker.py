"""
Math worker – exposes arithmetic functions via the router.

Start router.py first, then start this process and text_worker.py,
then run caller.py.
"""
import time
from daffi import Client, callback


@callback
def add(a: float, b: float) -> float:
    print(f"[math-worker] add({a}, {b})")
    return a + b


@callback
def subtract(a: float, b: float) -> float:
    print(f"[math-worker] subtract({a}, {b})")
    return a - b


@callback
def multiply(a: float, b: float) -> float:
    print(f"[math-worker] multiply({a}, {b})")
    return a * b


@callback
def divide(a: float, b: float) -> float:
    print(f"[math-worker] divide({a}, {b})")
    if b == 0:
        raise ZeroDivisionError("Cannot divide by zero")
    return a / b


if __name__ == "__main__":
    client = Client(app_name="math-worker", host="127.0.0.1", port=6001)
    client.connect()
    print("Math worker connected – waiting for calls.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        client.stop()
