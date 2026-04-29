"""
router/07_serde_msgpack — Router.

Start first, then 2_worker.py, then 3_caller.py.
"""
from daffi import Router


if __name__ == "__main__":
    router = Router(host="0.0.0.0", port=6007)
    router.start()
    print("Router running on 0.0.0.0:6007 — press Ctrl+C to stop.")
    router.join()
