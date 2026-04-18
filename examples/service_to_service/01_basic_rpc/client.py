"""
Client process – calls remote functions registered on the service.

Demonstrates call() (blocking, returns result) and cast() (fire-and-forget).

Start service.py first, then run this script.
"""
from daffi import Client


if __name__ == "__main__":
    client = Client(app_name="math-client", host="127.0.0.1", port=5001)
    conn = client.connect()

    # call() — blocking, waits for the return value.
    # receiver=None means "any node that exposes this function".
    c = conn.rpc(timeout=5)

    result = c.add(10, 20)
    print(f"add(10, 20)      = {result}")

    result = c.multiply(6, 7)
    print(f"multiply(6, 7)   = {result}")

    result = c.greet("World")
    print(f"greet('World')   = {result!r}")

    # cast() — fire-and-forget, returns immediately without waiting.
    conn.rpc_nowait().log_message("client finished all calls")

    client.stop()
    print("Done.")
