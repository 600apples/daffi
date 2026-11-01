"""
router/10_multitransport — Worker.

Connects to the Router over TCP and exposes multiply().  Callers on the
Router's Unix socket reach this worker too.

Start 1_router.py first, then this, then 3_caller.py.
"""

from daffi import Client, TCPTransport, callback

PORT = 6010


@callback
def multiply(a: int, b: int) -> int:
    print(f"[worker] multiply({a}, {b})")
    return a * b


if __name__ == "__main__":
    worker = Client(app_name="calc-worker", transport=TCPTransport("127.0.0.1", PORT))
    worker.connect()
    print(f"Worker connected over tcp://127.0.0.1:{PORT} — press Ctrl+C to stop.")
    worker.join()
