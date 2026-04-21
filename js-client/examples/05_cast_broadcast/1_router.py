"""
js/05_cast_broadcast — Router.

Start first, then run two (or more) instances of 2_worker.py with
different names, then open index.html in a browser.

  python 1_router.py
  python 2_worker.py worker-A
  python 2_worker.py worker-B
"""
from daffi import Router

if __name__ == "__main__":
    router = Router(host="127.0.0.1", port=6020)
    router.start()
    print("Router on ws://127.0.0.1:6020 — press Ctrl+C to stop.")
    router.join()
