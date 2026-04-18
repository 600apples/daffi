"""
Worker process for the broadcast example.

Run multiple instances of this script, each with a different name:

    python worker.py worker-1
    python worker.py worker-2
    python worker.py worker-3

When the caller sends a broadcast (receiver=None), the router delivers
the call to *all* connected nodes that have registered the function.
"""
import sys
import time
from daffi import Client, callback


def main(name: str):
    # Use a module-level variable so the callback can read the worker name.
    # The @callback decorator captures the function at decoration time.
    _name = name

    @callback
    def process_task(task_id: int, payload: str) -> str:
        payload = "".join(reversed(payload))

        result = f"[{_name}] processed task #{task_id}: {payload}"
        print(result)
        return result

    client = Client(app_name=name, host="127.0.0.1", port=6002)
    client.connect()
    print(f"{name} connected – waiting for tasks.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        client.stop()


if __name__ == "__main__":
    worker_name = "reverse-text-worker"
    main(worker_name)
