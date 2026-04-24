#  Daffi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**📖 Full documentation: [https://600apples.github.io/daffi/](https://600apples.github.io/daffi/)**

---

Daffi is a lightweight inter-process RPC framework with a compiled core.
It lets Python processes (and browser JavaScript clients) call each other's
functions over TCP, Unix sockets, or WebSocket — with no serialisation
boilerplate, no extra broker process required for direct connections, and
throughput up to **~1.2 GiB/s** for large binary payloads.

---

## Three building blocks

| Class | Role |
|---|---|
| `Service` | Listens on a TCP port. Exposes `@callback` functions; Clients call them. |
| `Router` | Pure message forwarder. Needed for the multi-worker layout. Has no callbacks of its own. |
| `Client` | Connects to a `Router` or `Service`. Can issue calls **and/or** expose its own `@callback` functions. |

> **Both `Service` and `Client` can expose `@callback` functions.**
> The topology determines the role:
> - **Client → Service**: only the `Service` exposes callbacks; Clients are pure callers.
> - **Client → Router → Worker**: any `Client` can expose callbacks (acting as a worker),
>   issue calls (acting as a caller), or do both at the same time — all through the Router.

---

## Installation

```bash
pip install daffi
```

## Quick start — direct layout (Client → Service)

`service.py`:
```python
from daffi import Service, callback

@callback
def add(a: float, b: float) -> float:
    return a + b

@callback
def greet(name: str) -> str:
    return f"Hello, {name}!"

svc = Service(app_name="my-service", host="127.0.0.1", port=5000)
svc.start()
svc.join()          # block until svc.stop() is called
```

`client.py`:
```python
from daffi import Client

client = Client(app_name="my-client", host="127.0.0.1", port=5000)
conn = client.connect()

result = conn.rpc(timeout=5).add(1, 2)     # → 3.0
greeting = conn.rpc(timeout=5).greet("Alice")  # → "Hello, Alice!"

client.stop()
```

Run `service.py` first, then `client.py` in a second terminal.

---

## Router layout (Client → Router → Worker)

Use a `Router` when you need many workers behind a single address, or want
load-balanced / broadcast calls.

`router.py`:
```python
from daffi import Router

router = Router(host="127.0.0.1", port=6000)
router.start()
router.join()
```

`worker.py`:
```python
from daffi import Client, callback

@callback
def process(task: str) -> str:
    return f"done: {task}"

client = Client(app_name="worker-1", host="127.0.0.1", port=6000)
client.connect()
client.join()   # block until Ctrl+C / SIGTERM
```

`caller.py`:
```python
from daffi import Client

client = Client(app_name="caller", host="127.0.0.1", port=6000)
conn = client.connect()

# RPC — routed to one worker (round-robin)
result = conn.rpc(timeout=5).process("job-42")

# Cast — sent to *all* workers, returns {worker_name: result}
all_results = conn.cast(timeout=5).process("broadcast-job")

client.stop()
```

---

## Call styles

All styles are accessed through the connection handle returned by
`client.connect()`.  Every call method returns a proxy; call the desired
remote function by attribute access.

```python
conn = client.connect()
```

### `rpc` — blocking, one worker (round-robin)

When multiple workers expose the same function, `rpc()` picks one using a
**round-robin** strategy — each call goes to the next worker in rotation, spreading
load evenly.  Pin to a specific worker with `receiver=` when you need affinity.

> **Round-robin only applies in the Router topology** (many workers behind one Router).
> In the Client → Service topology there is always exactly one receiver — the Service
> itself — so omitting `receiver=` is the norm and specifying it is redundant.

```python
result = conn.rpc(timeout=5).echo("hello")
result = conn.rpc(timeout=5, serde=SerdeFormat.JSON).add(1, 2)

# Router topology only: pin to a specific worker by name (bypasses round-robin)
result = conn.rpc(timeout=5, receiver="worker-1").process("task")
```

### `rpc_nowait` — fire-and-forget

```python
conn.rpc_nowait().notify("event happened")
```

### `cast` — broadcast to all workers, collect results

Most useful in the **Router topology** where multiple workers expose the same
function.  The call fans out to every matching worker simultaneously and returns
a `{worker_name: result}` dict once all have responded.

```python
# Returns {worker_name: result, ...}
results = conn.cast(timeout=5).echo("ping")
# e.g. {"worker-01": "ping", "worker-02": "ping", ...}
```

### `cast_nowait` — broadcast, fire-and-forget

```python
conn.cast_nowait().notify("broadcast event")
```

### `stream` — chunked send with backpressure

```python
@callback
def receive_chunk(data: bytes) -> None: ...

# Sends each chunk and waits for acknowledgement before sending the next
await_result = conn.stream(serde=SerdeFormat.OPAQUE)
for chunk in my_large_object_chunks:
    await_result.receive_chunk(chunk)
```

### `stream_nowait` — chunked send, fire-and-forget

```python
conn.stream_nowait(serde=SerdeFormat.OPAQUE).receive_chunk(chunk)
```

---

## Serialisation formats

Pass `serde=SerdeFormat.X` to any call method.

| Format | Import | Notes                                                                    |
|---|---|--------------------------------------------------------------------------|
| `PICKLE` | `from daffi import SerdeFormat` | Default. Any Python object.                                              |
| `JSON` | same | Human-readable; requires JSON-serialisable values.                       |
| `OPAQUE` | same | Raw `bytes` or `string` — zero-copy, fastest for binary and string data. |
| `MSGPACK` | same | Compact binary; requires `pip install daffi[msgpack]`.                   |

```python
from daffi import Client, SerdeFormat

conn = client.connect()
result = conn.rpc(serde=SerdeFormat.JSON, timeout=5).add(1, 2)
```

---

## `@callback` decorator

Decorate any top-level function or bound method to make it callable remotely.
Registration is global and happens at import time.

```python
from daffi import callback

@callback
def echo(payload):
    return payload

@callback
def compute(x: int, y: int) -> int:
    return x * y
```
---

## Concurrent callback execution (`workers`)

By default every node processes incoming callbacks **inline on a single thread**
(`workers=1`).  Callbacks are executed one at a time — a slow callback blocks
the next one.

Pass `workers=N` (N ≥ 2) to spin up a thread pool so that up to N callbacks
run in parallel:

```python
import time
from daffi import Service, callback

@callback
def slow_task(n: int) -> int:
    time.sleep(1)        # simulates I/O-bound work
    return n * n

# workers=1 (default) — three concurrent callers would each wait ~1 s
svc = Service(host="127.0.0.1", port=5000, workers=1)

# workers=4 — three concurrent callers all finish in ~1 s
svc = Service(host="127.0.0.1", port=5000, workers=4)

svc.start()
svc.join()
```

The same parameter works on a `Client` acting as a worker in the Router topology:

```python
from daffi import Client, callback

@callback
def process(task: str) -> str:
    time.sleep(0.5)
    return f"done: {task}"

# This single Client instance can now handle up to 8 concurrent incoming calls
client = Client(app_name="worker-1", host="127.0.0.1", port=6000, workers=8)
client.connect()
client.join()
```

> **When to increase `workers`:**
> - Callbacks do **I/O** (network calls, file reads, database queries).
> - Callbacks are **fast and pure** — keep `workers=1` (no threading overhead).
>
> For **CPU-bound** callbacks, Python's GIL limits true parallelism within one
> process.  Run multiple worker nodes behind a Router instead of increasing
> `workers` on a single node.

---

## Auto-reconnect

```python
client = Client(
    app_name="resilient-caller",
    host="127.0.0.1", port=6000,
    autoreconnect=True,
    reconnect_delay=2.0,   # seconds; doubles after each failure, capped at 60 s
)
conn = client.connect()   # returns AutoReconnect adapter

# If the router restarts, this blocks transparently until reconnected
result = conn.rpc(timeout=30).process("task")
```

---

## Event handlers

Receive `connected` / `disconnected` notifications for nodes joining or
leaving the network.

```python
def on_event(event: dict):
    # event["type"]   → "connected" or "disconnected"
    # event["member"] → app_name of the node that changed state
    print(f"[{event['type']}] {event['member']}")

svc = Service(host="127.0.0.1", port=5000)
svc.add_event_handler(on_event)
svc.start()
```

Both `Service` and `Client` support `add_event_handler`.

---

## Unix sockets

Use `unix_sock_path` instead of `host`/`port` for inter-process communication
on the same machine.

```python
svc = Service(unix_sock_path="/tmp/daffi.sock")
svc.start()

client = Client(unix_sock_path="/tmp/daffi.sock")
conn = client.connect()
```

---

## TLS

```python
# Server (Router or Service)
router = Router(
    host="127.0.0.1", port=6000,
    tls=True,
    cert_file="/path/to/server.crt",
    key_file="/path/to/server.key",
)
router.start()

# Client — supply ca_file to verify the server certificate,
# or leave it empty to skip verification
client = Client(
    host="127.0.0.1", port=6000,
    tls=True,
    ca_file="/path/to/ca.crt",
)
conn = client.connect()
```
