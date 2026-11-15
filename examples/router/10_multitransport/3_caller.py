"""
router/10_multitransport — Caller.

Connects to the same Router over the Unix socket and calls the worker that
joined over TCP.

Start 1_router.py and 2_worker.py first.
"""

from daffi import Client, UnixTransport

SOCK = "/tmp/daffi_router.sock"


if __name__ == "__main__":
    caller = Client(app_name="calc-caller", transport=UnixTransport(SOCK))
    conn = caller.connect()
    conn.wait_for_members("calc-worker", timeout=20)

    result = conn.rpc(timeout=5, receiver="calc-worker").multiply(6, 7)
    print(f"multiply(6, 7) via unix socket = {result}")

    caller.stop()
    print("Done.")
