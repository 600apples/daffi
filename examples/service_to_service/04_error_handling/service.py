"""
Service process – demonstrates how exceptions propagate back to the caller.

When a callback raises an exception the framework serialises it and
re-raises it on the client side as a RemoteCallError subclass.

Start this process first, then run client.py.
"""
from daffi import Service, callback


@callback
def divide(a: float, b: float) -> float:
    if b == 0:
        raise ZeroDivisionError("Cannot divide by zero")
    return a / b


@callback
def parse_int(value: str) -> int:
    return int(value)   # raises ValueError for non-numeric strings


if __name__ == "__main__":
    svc = Service(app_name="calc-service", host="127.0.0.1", port=5004)
    svc.start()
    print("Calc service running on 127.0.0.1:5004 – press Ctrl+C to stop.")
    svc.join()
