# Native Execution Model (threads vs evented)

daffi's native core, the part written in Zig that owns the sockets of every
`Router`, `Service` and `Client`, can run in one of two execution models:

| Model | How connections are served | Native threads |
|---|---|---|
| `threads` (default) | Every connection gets its own OS thread that blocks on reads. | One per connection, plus one per server. |
| `evented` | All connections are multiplexed over a few event-loop threads (kqueue on macOS, epoll on Linux). Incoming bytes are decoded as they arrive. | A fixed few (4 by default), however many connections there are. |

The model only changes how the native core waits for network data. Your
callbacks, call styles, serialization formats and the Python API are exactly
the same in both models.

!!! note "Not the same thing as `daffi.aio`"
    [`daffi.aio`](aio.md) is the Python **asyncio** interface: it decides how
    *your Python code* waits for results. The execution model decides how the
    *native core* waits for sockets. The two are independent. `daffi.aio`
    works with either model.

---

## Enabling it

The model is selected with an environment variable, read **once per process**
when the first `Router`, `Service` or `Client` starts:

```bash
DAFFI_EXECUTION_MODEL=evented python my_service.py
```

or from Python, before any daffi node is started:

```python
import os
os.environ["DAFFI_EXECUTION_MODEL"] = "evented"

from daffi import Service, callback

@callback
def echo(x):
    return x

svc = Service(app_name="echo", host="0.0.0.0", port=6000)
svc.start()
svc.join()
```

Check which model is active:

```python
from daffi import dfcore
print(dfcore.getExecutionModel())   # "threads" or "evented"
```

| Variable | Values | Default |
|---|---|---|
| `DAFFI_EXECUTION_MODEL` | `threads`, `evented` | `threads` |
| `DAFFI_EVENT_LOOPS` | number of event-loop threads, 1–64 | CPU count, capped at 4 |

An unknown value logs a warning and falls back to the default. Child
processes inherit the variable. Processes created with `fork` after daffi has
started get their own event loops.

---

## What changes in practice

The numbers below come from daffi's own benchmark suite
(`tests/perf/`, release builds, macOS on Apple Silicon, all traffic over
localhost). Absolute numbers depend on the machine; the comparison between the
two columns is what matters.

### Speed: the same

| Benchmark | threads | evented |
|---|---|---|
| One client → Service, sequential calls/s | 12,097 | 12,148 |
| One client → Router → worker, sequential calls/s | 9,331 | 9,326 |
| 200 clients → Service, calls/s | 14,559 | 15,272 |
| 200 clients → Router → worker, calls/s | 12,933 | 13,033 |
| Async API, 200 clients → Service, calls/s | 22,380 | 23,778 |
| Average latency of a small call | 0.088 ms | 0.082 ms |
| 28 MiB messages, MiB/s | 1,781 | 1,690 |

Differences are within run-to-run noise. A daffi call spends most of its time
in Python (serialization, the GIL, your callback), not waiting on the socket,
so the native execution model does not make individual calls faster or slower.

### Native threads: very different

A Service with 64 clients connected:

| | threads | evented |
|---|---|---|
| Threads, no clients connected | 3 | 7 |
| Threads, 64 clients connected | 67 | 7 |
| Threads, 64 clients under full load | 67 | 7 |

With `threads`, the thread count grows by one for every connection: 1,000
connected clients means about 1,000 native threads, each with its own stack.
With `evented` it stays flat. The event loops start along with the first
node, which is why an idle evented process has a few more threads than an
idle threaded one.

---

## When to use which

**Use `evented` when:**

- A `Router` or `Service` serves **many connections at once**: hundreds or
  thousands of clients or workers.
- Most connections are **idle most of the time**, e.g. many workers waiting
  for occasional tasks, or many long-lived clients that call rarely.
- The process runs under a **thread or memory limit**, e.g. containers with a
  low `pids` limit or small memory requests, where a thread per connection
  does not fit.
- One process opens **many `Client` connections** (e.g. to many services).

**Keep `threads` (the default) when:**

- There are only a **few connections**. Both models perform the same, and
  `threads` is the long-standing default.
- Peers may be **slow to read what they are sent**, e.g. large messages or
  streams to clients on slow or distant networks. In the evented model a
  Router forwards messages from its event-loop thread, and writes still block.
  A peer that stops reading can therefore hold up the other connections on
  the same loop until the write completes or times out (30 s). With `threads`
  only that one connection waits.
- Most clients are **browsers (WebSocket)**. WebSocket sessions keep a
  dedicated thread in both models, so `evented` saves nothing for them.

!!! tip
    If you are unsure, keep the default. Switch a `Router` or `Service` to
    `evented` when its thread count grows with the number of connected
    clients and that becomes a problem. Nothing else in your code needs to
    change.

---

## How it works

- **Event loops.** A small fixed set of loop threads waits for socket
  readiness with kqueue (macOS/BSD) or epoll (Linux). Each new connection is
  assigned to a loop round-robin.
- **Incremental decoding.** When a socket becomes readable, the loop reads
  whatever has arrived and feeds it to a frame decoder. Every complete
  message is dispatched exactly as in the threaded model: requests go to the
  task queue your callbacks consume, and routed messages are forwarded.
- **Blocking pool.** Work that can block for a long time never runs on a
  loop. This covers the TLS handshake, the protocol probe of a newly accepted
  socket, and WebSocket sessions. Such work runs on an elastic pool that
  starts a new thread whenever none is free, so a silent peer cannot delay
  other connections, and idle pool threads exit after 10 seconds.
- **Shutdown.** `stop()` behaves the same in both models. It returns once
  every connection is closed and all native resources are released, so the
  port can be rebound immediately.

The evented model is available on macOS and Linux.

## Measuring on your own machine

```bash
python tests/perf/execution_model_benchmark.py --clients 64 --seconds 5
```

The script runs the same scenarios once per model and prints the throughput,
latency and native thread counts side by side.
