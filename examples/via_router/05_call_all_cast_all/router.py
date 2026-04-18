"""
Router process – shared message broker for all workers and callers.

Start this first, then launch two or more worker.py processes:

    python worker.py worker-1
    python worker.py worker-2

Then run caller.py.
"""
from daffi import Router

if __name__ == "__main__":
    router = Router(app_name="router", host="127.0.0.1", port=6005)
    router.start()
    print("Router running on 127.0.0.1:6005 – press Ctrl+C to stop.")
    router.join()
