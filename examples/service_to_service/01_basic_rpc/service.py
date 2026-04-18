"""
Service process – registers math and greeting callbacks.

Start this process first, then run client.py.
"""
from daffi import Service, callback


@callback
def add(a: int, b: int) -> int:
    print(f"[service] add({a}, {b})")
    return a + b


@callback
def multiply(a: int, b: int) -> int:
    print(f"[service] multiply({a}, {b})")
    return a * b


@callback
def greet(name: str) -> str:
    print(f"[service] greet({name!r})")
    return f"Hello, {name}!"


@callback
def log_message(msg: str) -> None:
    print(f"[service] log: {msg}")


if __name__ == "__main__":
    svc = Service(app_name="math-service", host="127.0.0.1", port=5001)
    svc.start()
    print("Math service running on 127.0.0.1:5001 – press Ctrl+C to stop.")
    svc.join()
