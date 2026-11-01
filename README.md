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

Requires Python 3.10 or newer.

## Quick start — direct layout (Client → Service)

`service.py`:
```python
from daffi import Service, callback, TCPTransport

@callback
def add(a: float, b: float) -> float:
    return a + b

@callback
def greet(name: str) -> str:
    return f"Hello, {name}!"

svc = Service(app_name="my-service", transport=TCPTransport("127.0.0.1", 5000))
svc.start()
svc.join()          # block until svc.stop() is called
```

`client.py`:
```python
from daffi import Client, TCPTransport

client = Client(app_name="my-client", transport=TCPTransport("127.0.0.1", 5000))
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
from daffi import Router, TCPTransport

router = Router(transport=TCPTransport("127.0.0.1", 6000))
router.start()
router.join()
```

`worker.py`:
```python
from daffi import Client, callback, TCPTransport

@callback
def process(task: str) -> str:
    return f"done: {task}"

client = Client(app_name="worker-1", transport=TCPTransport("127.0.0.1", 6000))
client.connect()
client.join()   # block until Ctrl+C / SIGTERM
```

`caller.py`:
```python
from daffi import Client, TCPTransport

client = Client(app_name="caller", transport=TCPTransport("127.0.0.1", 6000))
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
| `MSGPACK` | `from daffi import SerdeFormat` | Default. Compact binary; language-agnostic.                              |
| `JSON` | same | Human-readable; requires JSON-serialisable values.                       |
| `OPAQUE` | same | Raw `bytes` or `string` — zero-copy, fastest for binary and string data. |
| `PICKLE` | same | Any Python object. Pass `serde=SerdeFormat.PICKLE` on the call.          |

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
from daffi import Service, callback, TCPTransport

@callback
def slow_task(n: int) -> int:
    time.sleep(1)        # simulates I/O-bound work
    return n * n

# workers=1 (default) — three concurrent callers would each wait ~1 s
svc = Service( workers=1,transport=TCPTransport("127.0.0.1", 5000))

# workers=4 — three concurrent callers all finish in ~1 s
svc = Service( workers=4,transport=TCPTransport("127.0.0.1", 5000))

svc.start()
svc.join()
```

The same parameter works on a `Client` acting as a worker in the Router topology:

```python
from daffi import Client, callback, TCPTransport

@callback
def process(task: str) -> str:
    time.sleep(0.5)
    return f"done: {task}"

# This single Client instance can now handle up to 8 concurrent incoming calls
client = Client(app_name="worker-1", workers=8, transport=TCPTransport("127.0.0.1", 6000))
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

## Native runtime (`threads` vs `evented`)

The native core can serve connections in two ways, chosen per process with
the `runtime` argument:

- `threads` (default): one OS thread per connection.
- `evented`: all connections are multiplexed over a few event-loop threads
  (kqueue on macOS, epoll on Linux).

The same split — blocking **threaded** I/O vs multiplexed **evented** I/O —
is described in Zig’s own documentation as `Io.Threaded` and `Io.Evented`;
see [I/O as an Interface](https://ziglang.org/download/0.16.0/release-notes.html#IO-as-an-Interface)
in the [Zig 0.16.0 release notes](https://ziglang.org/download/0.16.0/release-notes.html).
(daffi’s native core follows that idea with its own epoll/kqueue loops; it does
not use `std.Io.Evented` yet.)

```python
from daffi import Runtime, Router, TCPTransport

# threads is the default; pass runtime= only to force evented
router = Router(
    transport=TCPTransport("127.0.0.1", 6000),
    runtime=Runtime.EVENTED,
)
```

Omit `runtime` and that node selects `threads`. One process cannot mix the
two models: a later constructor that disagrees raises `InitializationError`.

`DAFFI_EVENT_LOOPS` sets the number of loop threads (default: one per CPU,
capped at 64). Nothing else in your code changes. This is independent of
`daffi.aio`, which is the Python asyncio API and works with both models.

Measured with daffi's benchmark suite (release build, localhost):

| | threads | evented |
|---|---|---|
| Sequential calls/s, Client → Service | 12,097 | 12,148 |
| 200 concurrent clients → Service, calls/s | 14,559 | 15,272 |
| Native threads with 64 clients connected | 67 | 7 |

`threads` is faster for one caller and for many clients calling one Service
together. With `threads` the Service uses about one native thread per client
(2003 threads for 2000 clients). With `evented` the Service stays at a handful
(7 in that run).

> **`threads` (default) fits when:**
> - You want the faster path, for one caller or for many clients at once.
> - Peers that may be **slow to read** large messages or streams. In the evented
>   model a stalled peer can briefly hold up other connections on the same loop.
> - Mostly **WebSocket (browser)** clients. They keep a thread each in both
>   models.
>
> **Prefer `evented` when:**
> - A Router or Service holds **many connections** and one thread per connection
>   does not fit, for example a container with a low thread limit.
> - Most connections are idle, such as workers waiting for tasks.

Compare both on your machine with `python tests/perf/runtime_benchmark.py`.
The `concurrent` rows are the many-clients → one Service case.

See the [runtime guide](https://600apples.github.io/daffi/usage/runtime/)
for details and full measurements, and the Zig docs linked above for the
`Io.Threaded` / `Io.Evented` background.

---

## Event handlers

Receive `connected` / `disconnected` notifications for nodes joining or
leaving the network.

```python
from daffi import Service, TCPTransport
def on_event(event: dict):
    # event["type"]   → "connected" or "disconnected"
    # event["member"] → app_name of the node that changed state
    print(f"[{event['type']}] {event['member']}")

svc = Service(transport=TCPTransport("127.0.0.1", 5000))
svc.add_event_handler(on_event)
svc.start()
```

Both `Service` and `Client` support `add_event_handler`.

---

## Unix sockets

Use a `UnixTransport` for inter-process communication on the same machine.

```python
from daffi import Service, Client, UnixTransport
svc = Service(transport=UnixTransport("/tmp/daffi.sock"))
svc.start()

client = Client(transport=UnixTransport("/tmp/daffi.sock"))
conn = client.connect()
```

---

## TLS

```python
from daffi import Router, Client, TCPTransport
# Server (Router or Service) — TLS is configured on the transport.
# cert/key/ca accept a filesystem path or PEM material.
router = Router(
    transport=TCPTransport(
        "127.0.0.1",
        6000,
        tls=True,
        cert="/path/to/server.crt",
        key="/path/to/server.key",
    ),
)
router.start()

# Client — supply ca to verify the server certificate,
# or leave it empty to skip verification
client = Client(
    transport=TCPTransport(
        "127.0.0.1",
        6000,
        tls=True,
        ca="/path/to/ca.crt",
    ),
)
conn = client.connect()
```
