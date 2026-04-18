# Service-to-Service Examples

These examples demonstrate **direct** communication between a `Client` and a
`Service` with no broker in between.

```
Client ──────────────────► Service
         TCP / unix socket
```

| # | Folder | What it shows |
|---|--------|---------------|
| 1 | `01_basic_rpc` | Simple blocking RPC calls with PICKLE serialization |
| 2 | `02_class_callbacks` | Registering a whole class of callbacks with `@callback` |
| 3 | `03_no_return_stream` | Fire-and-forget streaming (client does not wait for results) |
| 4 | `04_error_handling` | How remote exceptions propagate back to the caller |

## Quick-start (any example)

```bash
# terminal 1 – start the service
python examples/service_to_service/<folder>/service.py

# terminal 2 – run the client
python examples/service_to_service/<folder>/client.py
```

## API summary

```python
from daffi import Service, Client, callback
from daffi.registry import local, alias

# ── Service side ──────────────────────────────────────────────────────────

@callback                          # exposes the function remotely
def my_func(x: int) -> int:
    return x * 2

@callback                          # exposes every public method of the class
class MyGroup:
    def method_a(self): ...
    def method_b(self): ...

    @local                         # excluded from remote exposure
    def _helper(self): ...

svc = Service(app_name="my-svc", host="127.0.0.1", port=5000)
svc.start()
svc.join()                         # blocks until Ctrl+C / svc.stop()

# ── Client side ───────────────────────────────────────────────────────────

client = Client(app_name="my-client", host="127.0.0.1", port=5000)
conn   = client.connect()          # returns a ClientConnection

# Blocking RPC (waits for result)
rpc    = conn.rpc(timeout=5)       # timeout in seconds, 0 = infinite
result = rpc.my_func(21)           # calls the remote function by name

# Fire-and-forget stream
stream = conn.stream()
stream.my_func(42)                 # sends without waiting for result

client.stop()
```

### Serialization formats

Pass `serde=` to `conn.rpc()` or `conn.stream()`:

| Format | Import | Notes |
|--------|--------|-------|
| `SerdeFormat.PICKLE` | `from daffi import SerdeFormat` | Default; supports arbitrary Python objects |
| `SerdeFormat.JSON` | same | Arguments must be JSON-serializable |
| `SerdeFormat.RAW` | same | Single `bytes` or `str` argument, no wrapping |
