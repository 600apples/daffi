# Router Examples

Each folder is a self-contained example for **Client → Router → Worker**
communication.  The Router forwards calls between callers and workers without
either side knowing the other's address.  Run the numbered files in order.

## Table of Contents

| # | Folder | What it shows |
|---|--------|---------------|
| 01 | `01_rpc/` | Basic RPC via Router, round-robin and pinned receiver |
| 02 | `02_cast/` | `cast()` and `cast_nowait()` fan-out via Router |
| 03 | `03_bidirectional/` | Two nodes calling each other through the Router |
| 04 | `04_serde_pickle/` | PICKLE — dataclasses between caller and worker |
| 05 | `05_serde_json/` | JSON — all four call styles |
| 06 | `06_serde_opaque/` | OPAQUE — raw bytes forwarded by the Router |
| 07 | `07_serde_msgpack/` | MSGPACK — compact binary, all four call styles |
| 08 | `08_events/` | `add_event_handler()` — membership events via Router |

## Quick Start

```bash
# Terminal 1 — start the router
python examples/router/01_rpc/1_router.py

# Terminal 2 — start the worker
python examples/router/01_rpc/2_worker.py

# Terminal 3 — run the caller
python examples/router/01_rpc/3_caller.py
```

## Topology

```
Caller ──┐
         ├──► Router ──► Worker-1
         │            ──► Worker-2   (optional, for cast examples)
Worker ──┘   (bidirectional: workers can also call each other)
```

## API Reference

```python
from daffi import Router, Client, callback
from daffi import SerdeFormat

# --- Router ---
router = Router(host="127.0.0.1", port=6000)
router.start()

# --- Worker (Client with @callback) ---
@callback
def my_func(x: int) -> int: ...

worker = Client(app_name="worker-1", host="127.0.0.1", port=6000)
worker.add_event_handler(lambda e: print(e))
conn = worker.connect()

# --- Caller ---
caller = Client(app_name="caller", host="127.0.0.1", port=6000)
conn = caller.connect()

rpc          = conn.rpc(timeout=5)                       # blocking, one worker
rpc_pinned   = conn.rpc(timeout=5, receiver="worker-1")  # pinned
rpc_nowait   = conn.rpc_nowait()                         # fire-and-forget
cast         = conn.cast(timeout=5)                      # blocking broadcast
cast_nowait  = conn.cast_nowait()                        # fire-and-forget broadcast

result  = rpc.my_func(42)
results = cast.my_func(42)   # {"worker-1": result, "worker-2": result, ...}
caller.stop()
```
