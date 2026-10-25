"""
js/03_router_json — Router.

Start first, then 2_worker.py, then open index.html in a browser.

The browser acts as a Caller: it connects to the Router and sends
RPC requests to the Python worker.
"""

from daffi import Router, TCPTransport

if __name__ == "__main__":
    router = Router(transports=TCPTransport("127.0.0.1", 6010))
    router.start()
    print("Router on ws://127.0.0.1:6010 — press Ctrl+C to stop.")
    router.join()
