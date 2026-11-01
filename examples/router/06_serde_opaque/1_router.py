"""
router/06_serde_opaque — Router.

Start first, then 2_worker.py, then 3_caller.py.
"""

from daffi import Router, TCPTransport

if __name__ == "__main__":
    router = Router(transport=TCPTransport("0.0.0.0", 6006))
    router.start()
    print("Router running on 0.0.0.0:6006 — press Ctrl+C to stop.")
    router.join()
