# Events

daffi fires events when nodes connect to or disconnect from the network.  
Both Services and Clients can subscribe to these events.

---

## Subscribing

Call `add_event_handler(fn)` on a `Service`, `Router`, or `Client` **before** starting/connecting.

```python
def on_event(event: dict) -> None:
    name   = event["member"]   # app_name of the node
    etype  = event["type"]     # "connected" or "disconnected"
    print(f"{name} → {etype}")

svc.add_event_handler(on_event)
svc.start()
```

Multiple handlers can be registered; they run in registration order.

---

## Event dict

| Key | Type | Values |
|---|---|---|
| `"type"` | `str` | `"connected"` or `"disconnected"` |
| `"member"` | `str` | The `app_name` of the node whose state changed |

---

## Service-side example

The Service tracks how many clients are connected:

```python
from daffi import Service, callback

@callback
def ping(msg: str) -> str:
    return f"pong: {msg}"

if __name__ == "__main__":
    connected: set[str] = set()

    def on_event(event: dict) -> None:
        name = event["member"]
        if event["type"] == "connected":
            connected.add(name)
            print(f"✦ {name!r} connected   (total: {len(connected)})")
        elif event["type"] == "disconnected":
            connected.discard(name)
            print(f"✦ {name!r} disconnected (total: {len(connected)})")

    svc = Service(app_name="event-service", host="127.0.0.1", port=5009)
    svc.add_event_handler(on_event)
    svc.start()
    svc.join()
```

---

## Client-side example

Clients receive events about the nodes they are connected to:

```python
import time
from daffi import Client

if __name__ == "__main__":
    def on_event(event: dict) -> None:
        print(f"[client] {event['member']!r} → {event['type']}")

    client = Client(app_name="event-client", host="127.0.0.1", port=5009)
    client.add_event_handler(on_event)

    conn = client.connect()
    # "connected" fires here — service announces itself.

    result = conn.rpc(timeout=5).ping("hello")
    print(f"ping = {result!r}")

    time.sleep(0.2)
    client.stop()
    # "disconnected" fires on the service side.
```

---

## Router-side events

In the Router topology the Router itself fires events for every node that connects or disconnects. Workers and Callers can also subscribe.

```python
# In 1_router.py — track all connections through the router
def on_event(event: dict) -> None:
    print(f"[router] {event['member']!r} {event['type']}")

router = Router(host="127.0.0.1", port=6008)
router.add_event_handler(on_event)
router.start()
router.join()
```

---

## Example

Full working example: `examples/service/09_events/`  
Router variant: `examples/router/08_events/`
