# Getting Started

## Installation

```bash
pip install daffi

# MessagePack serialisation (optional)
pip install "daffi[msgpack]"
```

Requires Python 3.9+. Linux and macOS are supported.

---

## Your first service

Create two files:

**`1_service.py`**
```python
from daffi import Service, callback

@callback
def add(a: int, b: int) -> int:
    print(f"[service] add({a}, {b})")
    return a + b

if __name__ == "__main__":
    svc = Service(app_name="calc-service", host="127.0.0.1", port=5001)
    svc.start()
    print("Service running on 127.0.0.1:5001 — press Ctrl+C to stop.")
    svc.join()
```

**`2_client.py`**
```python
from daffi import Client

if __name__ == "__main__":
    client = Client(app_name="calc-client", host="127.0.0.1", port=5001)
    conn = client.connect()

    result = conn.rpc(timeout=5).add(3, 4)
    print(f"add(3, 4) = {result}")   # → 7

    client.stop()
```

Run them:

```bash
python 1_service.py &
python 2_client.py
```

---

## What just happened?

1. `Service` starts a native TCP listener.
2. `@callback` registers `add` with the framework; it is advertised to callers during the handshake.
3. `Client.connect()` performs a handshake, receives the list of available callbacks.
4. `conn.rpc(timeout=5)` returns a proxy. Calling `.add(3, 4)` on it serialises the arguments, sends them to the Service, and blocks until the result arrives.

---

## Next steps

| Topic | Link |
|---|---|
| Direct Client → Service communication | [Client → Service](usage/service.md) |
| Scalable Router + Worker topology | [Client → Router → Worker](usage/router.md) |
| rpc vs cast (broadcast) | [Call Styles](usage/call-styles.md) |
| Serialization formats | [Serialization](usage/serialization.md) |
| Event subscriptions | [Events](usage/events.md) |
| Browser / JavaScript client | [JavaScript Client](js-client.md) |
