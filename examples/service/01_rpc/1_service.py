"""
service/01_rpc — Service side.

Demonstrates the simplest daffi pattern: a Service that exposes one
@callback function and waits for incoming RPC calls.

Run first, then run 2_client.py.
"""
from daffi import Service, callback


@callback
def add(a: int, b: int) -> int:
    print(f"[service] add({a}, {b})")
    return a + b


if __name__ == "__main__":
    svc = Service(app_name="calc-service", host="127.0.0.1", port=5001)
    svc.start()
    print("Service running on 127.0.0.1:5001 — press Ctrl+C to stop.")
    svc.join()
