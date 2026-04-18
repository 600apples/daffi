"""
Router process for the bidirectional example.

Start this first.
"""
from daffi import Router

if __name__ == "__main__":
    router = Router(app_name="router", host="127.0.0.1", port=6003)
    router.start()
    print("Router running on 127.0.0.1:6003 – press Ctrl+C to stop.")
    router.join()
