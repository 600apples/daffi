"""
js/04_router_msgpack — Router.

Start first, then 2_worker.py, then open index.html in a browser.
"""

from daffi import Router, TCPTransport

if __name__ == "__main__":
    transport = TCPTransport("127.0.0.1", 6011)
    transport.websocket_allowed_origins = ["*"]
    router = Router(transport=transport)
    router.start()
    print("Router on ws://127.0.0.1:6011 — press Ctrl+C to stop.")
    router.join()
