# Unix Sockets

Unix domain sockets bypass the TCP/IP stack entirely, making them significantly faster for same-machine communication. Use them when your Service and Client(s) run on the same host.

!!! info "Platform support"
    Unix sockets are supported on **Linux** and **macOS** only.

---

## Service

Pass a `UnixTransport`:

```python
from daffi import Service, callback, UnixTransport

SOCK = "/tmp/daffi_example.sock"

@callback
def ping(msg: str) -> str:
    print(f"[service] ping({msg!r})")
    return f"pong: {msg}"

if __name__ == "__main__":
    svc = Service(app_name="unix-service", transports=UnixTransport(SOCK))
    svc.start()
    print(f"Service listening on unix://{SOCK} — press Ctrl+C to stop.")
    svc.join()
```

---

## Client

```python
from daffi import Client, UnixTransport

SOCK = "/tmp/daffi_example.sock"

if __name__ == "__main__":
    client = Client(app_name="unix-client", transport=UnixTransport(SOCK))
    conn = client.connect()

    for msg in ["hello", "world", "unix sockets are fast"]:
        result = conn.rpc(timeout=5).ping(msg)
        print(f"ping({msg!r}) → {result!r}")

    client.stop()
```

The API is identical to TCP — only the constructor argument changes.

---

## Router with Unix socket

The Router listens on a `UnixTransport` the same way:

```python
router = Router(transports=UnixTransport("/tmp/my_router.sock"))
router.start()
router.join()
```

Workers and Callers connect using the same path.

---

## Example

Full working example: `examples/service/08_unix_socket/`
