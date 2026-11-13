# Event handlers

Daffi provides event handlers for monitoring changes in network membership.

Register handlers with `on_member_added` and `on_member_removed` to receive notifications when nodes connect or disconnect. Each handler receives the peer's `app_name` as a string.

Both `Service` and `Client` support these methods. They can be used as decorators or as plain method calls. Register handlers **before** `start()` / `connect()`.

---

## Registering handlers

```python
from daffi import Service, TCPTransport


svc = Service(
    transport=TCPTransport("127.0.0.1", 5000),
)


@svc.on_member_added
def on_join(member: str) -> None:
    print(f"connected: {member}")


@svc.on_member_removed
def on_leave(member: str) -> None:
    print(f"disconnected: {member}")


svc.start()
svc.join()
```

Or register without decorators:

```python
def on_join(member: str) -> None:
    print(f"connected: {member}")

svc.on_member_added(on_join)
```

Multiple handlers can be registered; they run in registration order.

---

## Handlers

| Method | Description |
|---|---|
| `on_member_added` | Called when a node joins the network. Receives `app_name`. |
| `on_member_removed` | Called when a node leaves the network. Receives `app_name`. |

Event handlers are useful for monitoring network membership, tracking worker availability, and implementing application-level lifecycle logic.

For waiting until specific peers appear before calling them, prefer `conn.wait_for_members(...)` — see [Router and workers](router.md#waiting-for-members).

---

## Service-side example

```python
from daffi import Service, callback, TCPTransport

@callback
def ping(msg: str) -> str:
    return f"pong: {msg}"

if __name__ == "__main__":
    connected: set[str] = set()

    svc = Service(app_name="event-service", transport=TCPTransport("127.0.0.1", 5009))

    @svc.on_member_added
    def on_join(member: str) -> None:
        connected.add(member)
        print(f"{member!r} connected (total: {len(connected)})")

    @svc.on_member_removed
    def on_leave(member: str) -> None:
        connected.discard(member)
        print(f"{member!r} disconnected (total: {len(connected)})")

    svc.start()
    svc.join()
```

---

## Examples

| Example | Location |
|---|---|
| Events (Service) | `examples/service/09_events/` |
| Events (Router) | `examples/router/08_events/` |
