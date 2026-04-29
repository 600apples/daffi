"""
service/07_serde_msgpack — Client side.

Uses MSGPACK serialisation to send a dict to the service.
MSGPACK is more efficient than JSON for binary-heavy payloads and is
supported natively in many languages.

Requires:  pip install 'daffi[msgpack]'

Run 1_service.py first.
"""
from daffi import Client
from daffi import SerdeFormat


if __name__ == "__main__":
    client = Client(app_name="msgpack-client", host="0.0.0.0", port=5007)
    conn = client.connect()

    rpc = conn.rpc(timeout=5, serde=SerdeFormat.MSGPACK)

    records = [
        {"First_Name": "Alice", "Last_Name": "Smith", "Age": 30},
        {"First_Name": "Bob",   "Last_Name": "Jones", "Age": 25},
    ]
    for rec in records:
        result = rpc.transform(rec)
        print(f"full_name: {result.get('full_name')!r}")

    client.stop()
    print("Done.")
