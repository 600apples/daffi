"""
router/02_cast — Router.

Start this first, then open three terminals and run 2_worker.py with
different WORKER_NAME values (alpha, beta, gamma), then 3_caller.py.
"""
from daffi import Router


if __name__ == "__main__":
    router = Router(host="127.0.0.1", port=6002)
    router.start()
    print("Router running on 127.0.0.1:6002 — press Ctrl+C to stop.")
    router.join()
