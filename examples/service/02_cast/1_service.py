"""
service/02_cast — Service side.

Exposes a 'notify' callback.  The client will reach it using both cast()
(blocking broadcast, returns {name: result} dict) and cast_nowait()
(fire-and-forget broadcast).

Run first, then run 2_client.py.
"""
from daffi import Service, callback


@callback
def notify(message: str) -> str:
    print(f"[service] notify: {message!r}")
    return f"ack: {message}"


if __name__ == "__main__":
    svc = Service(app_name="notify-service", host="127.0.0.1", port=5002)
    svc.start()
    print("Service running on 127.0.0.1:5002 — press Ctrl+C to stop.")
    svc.join()
