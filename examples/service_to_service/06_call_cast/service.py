"""
Service – registers several callbacks for the call/cast demonstration.

Start this process first, then run client.py.
"""
from daffi import Service, callback


@callback
def add(a: int, b: int) -> int:
    print(f"[service] add({a}, {b})")
    return a + b


@callback
def notify(message: str) -> None:
    """Fire-and-forget handler — called by cast() and cast_all()."""
    print(f"[service] notification: {message}")


if __name__ == "__main__":
    svc = Service(app_name="demo-service", host="127.0.0.1", port=5006)
    svc.start()
    print("Service running on 127.0.0.1:5006 – press Ctrl+C to stop.")
    svc.join()
