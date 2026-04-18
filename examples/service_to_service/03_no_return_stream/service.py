"""
Service process – receives a fire-and-forget stream of events.

The callbacks return nothing; the client does not wait for a response,
making this pattern suitable for high-throughput logging or telemetry.

Start this process first, then run client.py.
"""
from daffi import Service, callback


_received: list[str] = []


@callback
def ingest_event(source: str, level: str, message: str) -> None:
    entry = f"[{level.upper()}] {source}: {message}"
    _received.append(entry)
    print(f"[service] stored #{len(_received):04d}  {entry}")


@callback
def flush() -> int:
    """Called by the client to confirm delivery; returns total stored count."""
    print(f"[service] flush requested – {len(_received)} events stored")
    return len(_received)


if __name__ == "__main__":
    svc = Service(app_name="log-service", host="127.0.0.1", port=5003)
    svc.start()
    print("Log service running on 127.0.0.1:5003 – press Ctrl+C to stop.")
    svc.join()
