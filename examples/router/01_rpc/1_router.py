"""
router/01_rpc — Router.

The Router forwards calls between callers and workers.  Workers connect
to the Router (not directly to callers) so the caller never needs to know
each worker's address.

Start first, then run 2_worker.py, then 3_caller.py.
"""
from daffi import Router


if __name__ == "__main__":
    router = Router(host="0.0.0.0", port=6001)
    router.start()
    print("Router running on 0.0.0.0:6001 — press Ctrl+C to stop.")
    router.join()
