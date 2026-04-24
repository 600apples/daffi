"""
js/05_cast — Worker B.

Start after 1_router.py.
"""
from daffi import Client, callback

NAME = "worker-B"


@callback
def ping() -> str:
    print(f"[{NAME}] ping!")
    return f"pong from {NAME}"


@callback
def square(n: float) -> dict:
    result = {"worker": NAME, "input": n, "result": n * n}
    print(f"[{NAME}] square({n}) → {result}")
    return result


if __name__ == "__main__":
    client = Client(app_name=NAME, host="127.0.0.1", port=6020)
    client.connect()
    print(f"'{NAME}' connected — press Ctrl+C to stop.")
    client.join()
