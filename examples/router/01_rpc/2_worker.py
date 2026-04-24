"""
router/01_rpc — Worker.

A Worker is a Client that exposes @callback functions.  It connects to
the Router; the Router then makes those functions available to Callers.

Start 1_router.py first, then this, then 3_caller.py.
"""
from daffi import Client, callback


@callback
def multiply(a: int, b: int) -> int:
    print(f"[worker] multiply({a}, {b})")
    return a * b


if __name__ == "__main__":
    worker = Client(app_name="calc-worker", host="127.0.0.1", port=6001)
    worker.connect()
    print("Worker connected to router — press Ctrl+C to stop.")
    import signal, time
    signal.pause()
