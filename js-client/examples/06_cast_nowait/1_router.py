"""
js/06_cast_nowait — Router.

Start first, then start all three workers, then open index.html.
"""

from daffi import Router, TCPTransport

if __name__ == "__main__":
    router = Router(transports=TCPTransport("127.0.0.1", 6021))
    router.start()
    print("Router on ws://127.0.0.1:6021 — press Ctrl+C to stop.")
    router.join()
