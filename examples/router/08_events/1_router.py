"""
router/08_events — Router.

Start first, then 2_worker.py, then 3_caller.py.
"""
from daffi import Router


if __name__ == "__main__":
    router = Router(host="127.0.0.1", port=6008)
    router.start()
    print("Router running on 127.0.0.1:6008 — press Ctrl+C to stop.")
    router.join()
