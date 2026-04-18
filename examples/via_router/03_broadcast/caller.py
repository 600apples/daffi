"""
Caller for the broadcast example.

cast_nowait() delivers the call to every connected node that has registered
the requested function – all workers receive and process the task in
parallel without the caller waiting for any result.

Start router.py and at least two worker.py instances first:

    python worker.py worker-1
    python worker.py worker-2

Then run this script.
"""
import time
from daffi import Client


TASKS = [
    (1, "compress image"),
    (2, "transcode video"),
    (3, "generate report"),
]

if __name__ == "__main__":
    client = Client(app_name="broadcaster", host="127.0.0.1", port=6002)
    conn = client.connect()

    # cast_nowait() — fire-and-forget broadcast to ALL nodes with process_task.
    print("Broadcasting tasks to all workers …")
    for task_id, payload in TASKS:
        conn.cast_nowait().process_task(task_id, payload)
        print(f"  dispatched task #{task_id}: {payload!r}")

    # Give workers time to print their output before this process exits.
    time.sleep(0.5)

    client.stop()
    print("Done.")
