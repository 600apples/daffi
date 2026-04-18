"""
Router (dispatcher) process – the central message broker.

All workers and callers connect here.  The router routes every RPC call
to whichever connected node has registered the requested function.

Start this process first.
"""
from daffi import Router

if __name__ == "__main__":
    router = Router(app_name="router", host="127.0.0.1", port=6000)
    router.start()
    print("Router running on 127.0.0.1:6000 – press Ctrl+C to stop.")
    router.join()
