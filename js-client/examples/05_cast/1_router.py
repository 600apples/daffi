"""
js/05_cast — Router.

Start first, then start all three workers, then open index.html.
"""
from daffi import Router

if __name__ == "__main__":
    router = Router(host="127.0.0.1", port=6020)
    router.start()
    print("Router on ws://127.0.0.1:6020 — press Ctrl+C to stop.")
    router.join()
