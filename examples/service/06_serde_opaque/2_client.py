"""
service/06_serde_opaque — Client side.

With OPAQUE serialisation the caller must provide the payload already
serialised as bytes (or str).  daffi ships it to the service unchanged.

Run 1_service.py first.
"""
import json
from daffi import Client
from daffi.serialization import SerdeFormat


PAYLOAD = {
    "event": "user_login",
    "user_id": 42,
    "timestamp": "2024-04-17T08:00:00Z",
    "meta": {"ip": "10.0.0.1", "ua": "Mozilla/5.0"},
}

if __name__ == "__main__":
    # Serialise to bytes before sending — OPAQUE does not do this for you.
    raw = json.dumps(PAYLOAD).encode("utf-8")

    client = Client(app_name="opaque-client", host="127.0.0.1", port=5006)
    conn = client.connect()

    rpc = conn.rpc(timeout=5, serde=SerdeFormat.OPAQUE)
    response = rpc.echo_raw(raw)

    print(f"echoed back {len(response)} bytes")
    print(f"decoded: {json.loads(response)}")

    client.stop()
    print("Done.")
