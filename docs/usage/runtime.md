# Native Runtime (threads vs evented)

daffi's native core, the part written in Zig that owns the sockets of every
`Router`, `Service` and `Client`, can run in one of two runtimes:

| Model | How connections are served | Native threads |
|---|---|---|
| `threads` (default) | Every connection gets its own OS thread that blocks on reads. | One per connection, plus one per server. |
| `evented` | All connections are multiplexed over a few event-loop threads (kqueue on macOS, epoll on Linux). Incoming bytes are decoded as they arrive. | One per CPU by default (capped at 64), however many connections there are. |

Zig documents the same kind of split as **`Io.Threaded`** (blocking I/O on OS
threads) vs **`Io.Evented`** (multiplexed / userspace scheduling) in
[I/O as an Interface](https://ziglang.org/download/0.16.0/release-notes.html#IO-as-an-Interface)
([Zig 0.16.0 release notes](https://ziglang.org/download/0.16.0/release-notes.html)).
daffi’s `threads` / `evented` models follow that idea for the native networking
core (custom epoll/kqueue loops). They are selected with the `runtime`
argument and are **not** the same as plugging in `std.Io.Evented`
(Zig’s evented backend is still experimental and does not implement networking
yet).

The model only changes how the native core waits for network data. Your
callbacks, call styles, serialization formats and the Python API are exactly
the same in both models.

!!! note "Not the same thing as `daffi.aio`"
    [`daffi.aio`](aio.md) is the Python **asyncio** interface: it decides how
    *your Python code* waits for results. The runtime decides how the
    *native core* waits for sockets. The two are independent. `daffi.aio`
    works with either model.

---

## Enabling it

The runtime is selected **once per process**, by the `runtime` argument of
any `Router`, `Service`, or `Client`. A client uses the same runtime as a
server. Omit it, or pass `None`, and that node selects `threads`. A later
node that asks for the other runtime raises `InitializationError`.

```python
from daffi import Runtime, Service, callback, TCPTransport

@callback
def echo(x):
    return x

# threads is the default — pass runtime= only to force evented
svc = Service(
    app_name="echo",
    transport=TCPTransport("0.0.0.0", 6000),
)
svc.start()
svc.join()
```

`"threads"` / `"evented"` are accepted in place of the enum. Check which
runtime is active:

```python
from daffi import dfcore
print(dfcore.getRuntime())   # "evented" or "threads"
```

| Argument | Values | Default |
|---|---|---|
| `runtime` | `Runtime.THREADS`, `Runtime.EVENTED` (or `"threads"`, `"evented"`) | `threads` |
| `DAFFI_EVENT_LOOPS` | number of event-loop threads, 1–64 | CPU count (capped at 64) |

A value other than those two strings raises `InitializationError`. A process
started with `spawn` does not inherit the parent's lock, so pass `runtime`
into that process too. A child created with `fork` after daffi has started
keeps the runtime the parent already chose and builds its own event loops.

### Running the test suite against both models

The model is fixed for the life of a process, so pytest cannot flip mid-session.
The root conftest therefore supports::

    pytest --runtime=both      # default: threads pass, then evented pass
    pytest --runtime=threads   # faster local loop
    pytest --runtime=evented

`both` starts two fresh interpreters. Perf scripts that already loop over both
models (`tests/perf/runtime_*.py`) need no flag.

### Long soak / memory-leak run

For a multi-hour load with periodic RSS and CPU sampling (same idea as
vast-csi's `ResourceSampler`), use::

    python tests/perf/soak_leak_test.py                     # 3 h, both models, random order
    python tests/perf/soak_leak_test.py --model evented
    python tests/perf/soak_leak_test.py --hours 0.25 --clients 64   # shorter smoke

See [`tests/perf/soak_leak_test.py`](https://github.com/600apples/daffi/blob/main/tests/perf/soak_leak_test.py)
and [`tests/_resource_sampler.py`](https://github.com/600apples/daffi/blob/main/tests/_resource_sampler.py).

---

## What changes in practice

The numbers below come from daffi's own benchmark suite
(`tests/perf/`, release builds, macOS on Apple Silicon, all traffic over
localhost). Absolute numbers depend on the machine; the comparison between the
two columns is what matters.

### Speed

`threads` is faster for one caller and for many clients calling **one Service
at the same time**. The single-caller rows are Client → Service and Client →
Router → one worker. The concurrent rows have no Router: every client connects
straight to the Service.

`python tests/perf/runtime_benchmark.py` prints this split. Its `direct` and
`via router` rows are the single sequential caller. Its `concurrent` rows are
N clients → one Service.

| Benchmark | threads | evented |
|---|---|---|
| One client → Service, sequential calls/s | 12,097 | 12,148 |
| One client → Router → worker, sequential calls/s | 9,331 | 9,326 |
| 200 clients → Service, calls/s | 14,559 | 15,272 |
| 200 clients → Router → worker, calls/s | 12,933 | 13,033 |
| Async API, 200 clients → Service, calls/s | 22,380 | 23,778 |
| Average latency of a small call | 0.088 ms | 0.082 ms |
| 28 MiB messages, MiB/s | 1,781 | 1,690 |

Absolute numbers move from machine to machine. A daffi call still spends most
of its time in Python (serialization, the GIL, your callback). The runtime
shows up when many connections are active together, and in how many native
threads that takes.

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

**`threads` (the default) fits when:**

- You want the faster path. One caller and many clients calling one Service
  are both faster with `threads`.
- There are only a **few connections**.
- Peers may be **slow to read what they are sent**, e.g. large messages or
  streams to clients on slow or distant networks. In the evented model a
  Router forwards messages from its event-loop thread, and writes still block.
  A peer that stops reading can therefore hold up the other connections on
  the same loop until the write completes or times out (30 s). With `threads`
  only that one connection waits.
- Most clients are **browsers (WebSocket)**. WebSocket sessions keep a
  dedicated thread in both models, so `evented` saves nothing for them.

**Prefer `evented` when:**

- A `Router` or `Service` serves **many connections at once** and one thread
  per connection does not fit: hundreds or thousands of clients or workers.
- Most connections are **idle most of the time**, e.g. many workers waiting
  for occasional tasks, or many long-lived clients that call rarely.
- The process runs under a **thread or memory limit**, e.g. containers with a
  low `pids` limit or small memory requests.
- One process opens **many `Client` connections** (e.g. to many services).

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
python tests/perf/runtime_benchmark.py --clients 64 --seconds 5
```

The script runs the same scenarios once per model and prints the throughput,
latency and native thread counts side by side.
