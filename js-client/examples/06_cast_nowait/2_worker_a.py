"""
js/06_cast_nowait — Worker A.

Start after 1_router.py.
"""
from daffi import Client, callback

NAME = "worker-A"


@callback
def notify(message: str) -> None:
    print(f"[{NAME}] notify: {message!r}")


@callback
def process(payload: dict) -> None:
    print(f"[{NAME}] process: {payload}")


if __name__ == "__main__":
    client = Client(app_name=NAME, host="127.0.0.1", port=6021)
    client.connect()
    print(f"'{NAME}' connected — press Ctrl+C to stop.")
    client.join()
