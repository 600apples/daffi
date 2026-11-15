"""
js/05_cast — Router.

Start first, then start all three workers, then open index.html.
"""

from daffi import Router, TCPTransport

if __name__ == "__main__":
    transport = TCPTransport("127.0.0.1", 6020)
    transport.websocket_allowed_origins = ["*"]
    router = Router(transport=transport)
    router.start()
    print("Router on ws://127.0.0.1:6020 — press Ctrl+C to stop.")
    router.join()
