# Service Examples

Each folder is a self-contained example demonstrating a specific daffi feature
for direct **Client → Service** communication.  Run the numbered files in order.

## Table of Contents

| # | Folder | What it shows |
|---|--------|---------------|
| 01 | `01_rpc/` | Basic blocking RPC call |
| 03 | `03_class_callbacks/` | Class-based callbacks and `@local` |
| 04 | `04_serde_pickle/` | PICKLE — Python dataclasses and Enums |
| 05 | `05_serde_json/` | JSON — language-agnostic plain dicts |
| 06 | `06_serde_opaque/` | OPAQUE — raw bytes, zero-copy |
| 07 | `07_serde_msgpack/` | MSGPACK — compact binary encoding |
| 08 | `08_unix_socket/` | Unix domain socket transport |
| 09 | `09_events/` | `add_event_handler()` — connect/disconnect events |
| 10 | `10_stream/` | Generator streaming with `stream()` / `stream_nowait()` |

## Quick Start

```bash
# Terminal 1 — start the service
python examples/service/01_rpc/1_service.py

# Terminal 2 — run the client
python examples/service/01_rpc/2_client.py
```

## Serialisation Format Comparison

| Format | Types supported | Cross-language | Requires extra |
|--------|----------------|----------------|----------------|
| `PICKLE` | Any Python object | No | — |
| `JSON` | dict, list, str, int, float, bool, None | Yes | — |
| `OPAQUE` | `bytes` or `str` (pass-through) | Yes | — |
| `MSGPACK` | Same as JSON (binary) | Yes | `pip install 'daffi[msgpack]'` |

## API Reference

```python
from daffi import Service, Client, callback
from daffi.registry import local
from daffi import SerdeFormat

# --- Service side ---
@callback
def my_func(x: int) -> int: ...

@callback
class MyClass:
    def method(self, x): ...
    @local
    def internal(self): ...   # not exported

svc = Service(app_name="my-svc", host="127.0.0.1", port=5000)
svc.add_event_handler(lambda e: print(e))
svc.start()
svc.join()

# --- Client side ---
client = Client(app_name="my-client", host="127.0.0.1", port=5000)
conn = client.connect()

rpc          = conn.rpc(timeout=5)                       # blocking, one worker
rpc_nowait   = conn.rpc_nowait()                         # fire-and-forget
cast         = conn.cast(timeout=5)                      # blocking broadcast
cast_nowait  = conn.cast_nowait()                        # fire-and-forget broadcast

result  = rpc.my_func(42)
results = cast.my_func(42)   # {service_name: result}
client.stop()
```
