"""
js/04_router_msgpack — Python worker.

Accepts and returns data via MSGPACK serialisation.
The browser sends msgpack-encoded args; the worker receives them as
native Python objects and responds with msgpack-encoded results.

Requires: pip install 'daffi[msgpack]'

Start 1_router.py first, then this, then open index.html.
"""
from daffi import Client, callback
from daffi.serialization import SerdeFormat


@callback
def summarise(records: list) -> dict:
    """Compute summary stats over a list of {value, label} dicts."""
    values = [r["value"] for r in records if "value" in r]
    total  = sum(values)
    result = {
        "count": len(values),
        "total": round(total, 4),
        "avg":   round(total / len(values), 4) if values else 0,
        "min":   min(values) if values else None,
        "max":   max(values) if values else None,
    }
    print(f"[worker] summarise({len(records)} records) → {result}")
    return result


@callback
def transform(item: dict) -> dict:
    """Normalise a record: lowercase keys, strip whitespace from string values."""
    result = {k.lower(): (v.strip() if isinstance(v, str) else v) for k, v in item.items()}
    print(f"[worker] transform → {result}")
    return result


if __name__ == "__main__":
    worker = Client(app_name="mp-worker", host="127.0.0.1", port=6011)
    worker.connect()
    print("Worker connected to router — press Ctrl+C to stop.")
    import signal
    signal.pause()
