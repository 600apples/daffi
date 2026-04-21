"""
js/05_cast_broadcast — Python worker.

Run multiple instances with different names to demonstrate cast():

  python 2_worker.py worker-A
  python 2_worker.py worker-B

The browser's cast() will call every connected worker and collect
all results as { "worker-A": result, "worker-B": result }.
"""
import sys
from daffi import Client, callback


@callback
def ping() -> str:
    name = sys.argv[1] if len(sys.argv) > 1 else "worker"
    print(f"[{name}] ping!")
    return f"pong from {name}"


@callback
def compute(x: float, y: float) -> dict:
    name = sys.argv[1] if len(sys.argv) > 1 else "worker"
    result = {"worker": name, "sum": x + y, "product": x * y}
    print(f"[{name}] compute({x}, {y}) → {result}")
    return result


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "worker"
    worker = Client(app_name=name, host="127.0.0.1", port=6020)
    worker.connect()
    print(f"Worker '{name}' connected to router — press Ctrl+C to stop.")
    import signal
    signal.pause()
