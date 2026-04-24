"""
router/04_serde_pickle — Router.

Start first, then 2_worker.py, then 3_caller.py.
"""
from daffi import Router


if __name__ == "__main__":
    router = Router(host="127.0.0.1", port=6004)
    router.start()
    print("Router running on 127.0.0.1:6004 — press Ctrl+C to stop.")
    router.join()
