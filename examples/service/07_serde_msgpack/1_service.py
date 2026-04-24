"""
service/07_serde_msgpack — Service side.

MSGPACK serialisation is compact and language-agnostic.  It supports the
same basic types as JSON (dict, list, str, int, float, bool, None) but
encodes them in a binary format — smaller on the wire than JSON.

Requires:  pip install 'daffi[msgpack]'

Run first, then run 2_client.py.
"""
from daffi import Service, callback


@callback
def transform(record: dict) -> dict:
    """Normalise field names and add a computed field."""
    result = {k.lower(): v for k, v in record.items()}
    if "first_name" in result and "last_name" in result:
        result["full_name"] = f"{result['first_name']} {result['last_name']}"
    print(f"[service] transform → {result}")
    return result


if __name__ == "__main__":
    svc = Service(app_name="msgpack-service", host="127.0.0.1", port=5007)
    svc.start()
    print("Service running on 127.0.0.1:5007 — press Ctrl+C to stop.")
    svc.join()
