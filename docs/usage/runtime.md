# Native runtime

Daffi's compiled core supports two connection-handling models, configurable through the `runtime` argument.

The model only changes how the native core waits for network data. Callbacks, call styles, serialization formats, and the Python API are the same in both models.

!!! note "Not the same as `daffi.aio`"
    [`daffi.aio`](aio.md) is the Python asyncio API. The native runtime decides how the compiled core waits for sockets. The two are independent — `daffi.aio` works with either model.

---

## Runtime modes

| Runtime | Description |
|---|---|
| `threads` | Creates an operating-system thread for each connection. Default runtime. |
| `evented` | Multiplexes connections across a small number of event-loop threads. Uses `epoll` on Linux and `kqueue` on macOS. |

---

## Selecting a runtime

The runtime is selected once per process by the `runtime` argument of any `Router`, `Service`, or `Client`. Omitting `runtime` selects `threads`. A process cannot mix the two models; conflicting initialization raises `InitializationError`.

```python
from daffi import Runtime, Router, TCPTransport

router = Router(
    transport=TCPTransport("127.0.0.1", 6000),
    runtime=Runtime.EVENTED,
)
```

`"threads"` / `"evented"` are also accepted in place of the enum. Check which runtime is active:

```python
from daffi import dfcore

print(dfcore.getRuntime())  # "evented" or "threads"
```

| Argument | Values | Default |
|---|---|---|
| `runtime` | `Runtime.THREADS`, `Runtime.EVENTED` (or `"threads"`, `"evented"`) | `threads` |

A process started with `spawn` does not inherit the parent's lock — pass `runtime` into that process too. A child created with `fork` after Daffi has started keeps the runtime the parent already chose.

---

## Event-loop configuration

Use the `DAFFI_EVENT_LOOPS` environment variable to configure the number of event-loop threads.

The default is one loop per CPU, capped at 64.

```bash
DAFFI_EVENT_LOOPS=4 python router.py
```

---

## Choosing a runtime

Use `threads` when:

- Connections may be slow to read large messages or streams. In the evented model a stalled peer can briefly hold up other connections on the same loop.
- Your application primarily uses connections that benefit from independent thread handling.
- Most clients are browsers (WebSocket). WebSocket sessions keep a dedicated thread in both models.

Use `evented` when:

- A Router or Service needs to maintain many simultaneous connections.
- Native thread count is a limiting resource (containers with a low `pids` limit, small memory requests).
- Most connections are idle, such as workers waiting for tasks.
- One process opens many `Client` connections.

If you are unsure, keep the default. Switch a Router or Service to `evented` when thread count grows with the number of connections and that becomes a problem. Nothing else in your code needs to change.

---

## How it works

- **Event loops.** A small fixed set of loop threads waits for socket readiness with kqueue (macOS/BSD) or epoll (Linux). Each new connection is assigned to a loop round-robin.
- **Incremental decoding.** When a socket becomes readable, the loop reads available data and feeds it to a frame decoder. Complete messages are dispatched the same way as in the threaded model.
- **Blocking pool.** Work that can block for a long time (TLS handshake, protocol probe, WebSocket sessions) never runs on a loop thread. It runs on an elastic pool so a silent peer cannot delay other connections.
- **Shutdown.** `stop()` behaves the same in both models. It returns once every connection is closed and native resources are released.

The evented model is available on macOS and Linux.
