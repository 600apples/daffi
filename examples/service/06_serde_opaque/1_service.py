"""
service/06_serde_opaque — Service side.

OPAQUE serialisation passes the payload through unchanged (zero-copy).
The single argument must be bytes or str; daffi does not interpret it.
Use this when you own the serialisation layer (e.g. protobuf, msgpack
with a custom schema, or any binary format).

Run first, then run 2_client.py.
"""
import json
from daffi import Service, callback


@callback
def echo_raw(payload: bytes) -> bytes:
    """Receive raw bytes, decode as UTF-8 JSON, print, and echo back."""
    data = json.loads(payload.decode("utf-8"))
    print(f"[service] received {len(payload)} bytes  "
          f"keys={list(data.keys()) if isinstance(data, dict) else type(data).__name__}")
    return payload  # echo unchanged


if __name__ == "__main__":
    svc = Service(app_name="opaque-service", host="127.0.0.1", port=5006)
    svc.start()
    print("Service running on 127.0.0.1:5006 — press Ctrl+C to stop.")
    svc.join()
