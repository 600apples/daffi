"""
router/09_wait_for_members — Router.

Start this first, then 2_worker.py, then 3_caller.py.
"""
from daffi import Router

if __name__ == "__main__":
    router = Router(host="0.0.0.0", port=6009)
    router.start()
    print("Router running on 0.0.0.0:6009 — press Ctrl+C to stop.")
    router.join()
