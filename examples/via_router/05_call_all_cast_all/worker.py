"""
Worker process – registers callbacks for the broadcast example.

Usage:
    python worker.py worker-1
    python worker.py worker-2
    # … start as many as you like

Each worker connects to the router and waits for incoming calls.
"""
import sys
import time
from daffi import Service, callback


@callback
def compute(value: int) -> int:
    """Double the value (simulates a CPU-bound task)."""
    name = sys.argv[1] if len(sys.argv) > 1 else "worker"
    print(f"[{name}] compute({value}) …")
    time.sleep(0.05)  # simulate work
    return value * 2


@callback
def status() -> str:
    """Return a human-readable status string for this worker."""
    name = sys.argv[1] if len(sys.argv) > 1 else "worker"
    return f"{name}: ready"


@callback
def invalidate_cache(key: str) -> None:
    """Simulate a cache-clear operation (no return value)."""
    name = sys.argv[1] if len(sys.argv) > 1 else "worker"
    print(f"[{name}] cache invalidated for key={key!r}")


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "worker"
    svc = Service(app_name=name, host="127.0.0.1", port=6005)
    svc.start()
    print(f"Worker {name!r} connected to router – press Ctrl+C to stop.")
    svc.join()
