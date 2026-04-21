"""
service/05_serde_json — Client side.

Sends a plain Python dict using JSON serialisation.
JSON is language-agnostic — the same service can be called from Go, Rust,
or any other language that can speak daffi's wire protocol.

Run 1_service.py first.
"""
from daffi import Client
from daffi.serialization import SerdeFormat


CART = {
    "customer": "Bob",
    "items": [
        {"name": "Apple",  "price": 0.99, "qty": 6},
        {"name": "Banana", "price": 0.49, "qty": 10},
        {"name": "Cherry", "price": 2.99, "qty": 2},
    ],
}

if __name__ == "__main__":
    client = Client(app_name="json-client", host="127.0.0.1", port=5005)
    conn = client.connect()

    rpc = conn.rpc(timeout=5, serde=SerdeFormat.JSON)
    summary = rpc.summarise(CART)
    print(f"summary: {summary}")

    client.stop()
    print("Done.")
