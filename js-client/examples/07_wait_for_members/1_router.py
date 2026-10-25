"""
js/07_wait_for_members — Router.

Start this first, then 2_worker.py, then open index.html.
"""

from daffi import Router, TCPTransport

if __name__ == "__main__":
    router = Router(transports=TCPTransport("127.0.0.1", 6030))
    router.start()
    print("Router on ws://127.0.0.1:6030 — press Ctrl+C to stop.")
    router.join()
