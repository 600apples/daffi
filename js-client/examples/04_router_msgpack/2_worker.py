"""
js/04_router_msgpack — Python worker.

Accepts and returns data via MSGPACK serialisation.
The browser sends msgpack-encoded args; the worker receives them as
native Python objects and responds with msgpack-encoded results.

Requires: pip install 'daffi[msgpack]'

Start 1_router.py first, then this, then open index.html.

Auto-reconnect behaviour
------------------------
Passing ``autoreconnect=True`` (and optionally ``reconnect_delay``) makes
:meth:`Client.connect` return an :class:`~daffi.rpc_proxy.AutoReconnect`
adapter.  Every call on that adapter checks the connection liveness first:
if the link is down it blocks with exponential back-off until the server
comes back, then executes the call on the fresh connection.

For a pure worker (no outgoing RPC calls) that just needs to re-register its
``@callback`` functions after a router restart, the pattern below works well:

  worker = Client(app_name="mp-worker", ..., autoreconnect=True)
  conn = worker.connect()  # conn is an AutoReconnect instance

Workers respond to incoming calls via the task-dispatcher, which is restarted
automatically each time ``AutoReconnect._do_reconnect`` succeeds.

Try it:
  1. Start the router: python 1_router.py
  2. Start this worker: python 2_worker.py
  3. Open index.html and make a few calls.
  4. Kill the router (Ctrl+C in its terminal).
  5. Restart the router: python 1_router.py
  6. Make calls from the browser again — the worker reconnects automatically.
"""
from daffi import Client, callback


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
    worker = Client(
        app_name="mp-worker",
        host="127.0.0.1",
        port=6011,
        autoreconnect=True,
        reconnect_delay=2.0,
    )
    conn = worker.connect()   # returns AutoReconnect adapter
    print("Worker connected to router — press Ctrl+C to stop.")
    print("(If the router restarts, any call through 'conn' will reconnect automatically.)")
    worker.join()
