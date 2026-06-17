# Async Interface (`daffi.aio`)

`daffi.aio` is a first-class asyncio-native interface that mirrors every
synchronous concept in `daffi` — but replaces OS threads with coroutines,
`threading.Event` with `asyncio.Event`, and blocking calls with `await`.

All public methods (`connect`, `start`, `join`, `stop`) are `async def`.
Callbacks can be regular functions **or** `async def` coroutines.
The event loop is never blocked.

---

## Quick-start

=== "Service (direct)"

    ```python
    # 1_service.py
    import asyncio
    from daffi import callback
    from daffi.aio import AsyncService

    @callback
    async def multiply(a: int, b: int) -> int:
        return a * b

    async def main():
        svc = AsyncService(app_name="calc-service", host="127.0.0.1", port=6001)
        await svc.start()
        print("AsyncService running — press Ctrl+C to stop.")
        await svc.join()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

    ```python
    # 2_caller.py
    import asyncio
    from daffi.aio import AsyncClient

    async def main():
        client = AsyncClient(app_name="calc-caller", host="127.0.0.1", port=6001)
        conn = await client.connect()

        result = await conn.rpc(timeout=5).multiply(6, 7)
        print(f"multiply(6, 7) = {result}")   # → 42

        await client.stop()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

=== "Router + Worker"

    ```python
    # 1_router.py
    import asyncio
    from daffi.aio import AsyncRouter

    async def main():
        router = AsyncRouter(app_name="calc-router", host="127.0.0.1", port=6001)
        await router.start()
        print("AsyncRouter running — press Ctrl+C to stop.")
        await router.join()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

    ```python
    # 2_worker.py
    import asyncio
    from daffi import callback
    from daffi.aio import AsyncClient

    @callback
    async def multiply(a: int, b: int) -> int:
        return a * b

    async def main():
        worker = AsyncClient(app_name="calc-worker", host="127.0.0.1", port=6001)
        await worker.connect()
        print("AsyncWorker connected — press Ctrl+C to stop.")
        await worker.join()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

    ```python
    # 3_caller.py
    import asyncio
    from daffi.aio import AsyncClient

    async def main():
        caller = AsyncClient(app_name="calc-caller", host="127.0.0.1", port=6001)
        conn = await caller.connect()

        result = await conn.rpc(timeout=5).multiply(6, 7)
        print(f"multiply(6, 7) = {result}")   # → 42

        await caller.stop()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

---

## Classes

| Async class | Sync equivalent | Role |
|---|---|---|
| `AsyncClient` | `Client` | Connect to a Router or Service, call remote callbacks, optionally expose your own. |
| `AsyncService` | `Service` | Listen for incoming connections; own server (no Router needed). |
| `AsyncRouter` | `Router` | Pure message broker — forwards calls between Clients. |

---

## API reference

### `AsyncClient`

```python
from daffi.aio import AsyncClient

client = AsyncClient(
    app_name="my-client",   # unique name on the network
    host="127.0.0.1",
    port=6001,
    workers=1,              # asyncio task concurrency for *incoming* callbacks
)

conn   = await client.connect()   # returns an AsyncClientConnection
await client.join()               # suspend until stopped
await client.stop()               # graceful disconnect
```

#### `workers` — callback concurrency

`workers` controls how many *incoming* callbacks can execute concurrently on
this node.

| Value | Behaviour |
|---|---|
| `1` (default) | Inline: each callback is awaited before the next is dispatched. |
| `N > 1` | Pool of `N` asyncio tasks; up to `N` callbacks run concurrently. |

!!! tip
    Because the worker pool uses `asyncio.Task` (not OS threads), the
    `workers` parameter has **zero thread-creation overhead** — you can safely
    set `workers=200` or higher without the memory cost of 200 OS stacks.

---

### `AsyncService`

```python
from daffi.aio import AsyncService

svc = AsyncService(
    app_name="my-service",
    host="0.0.0.0",
    port=6001,
    workers=4,
)

await svc.start()   # begin listening
await svc.join()    # block until stopped (typically forever)
await svc.stop()    # graceful shutdown
```

---

### `AsyncRouter`

```python
from daffi.aio import AsyncRouter

router = AsyncRouter(app_name="my-router", host="0.0.0.0", port=6001)

await router.start()
await router.join()
await router.stop()
```

---

### `AsyncClientConnection`

`await client.connect()` returns an `AsyncClientConnection`.  Its proxy
methods return **awaitables** — you must `await` each call.

```python
conn = await client.connect()

# RPC — await the result
result = await conn.rpc(timeout=10).my_function(arg1, arg2)

# Cast — broadcast to all workers; await the dict of results
results = await conn.cast(timeout=10).my_function(arg1)

# Fire-and-forget variants — return immediately
conn.rpc_nowait().my_function(arg1)
conn.cast_nowait().my_function(arg1)

# Stream a sequence (OPAQUE serde; each chunk sent as a separate message)
await conn.stream(serde=SerdeFormat.OPAQUE).my_callback(chunk)

# Wait until named peers are online
await conn.wait_for_members("worker-1", "worker-2", timeout=30)
```

---

## Async callbacks

Callbacks can be either regular functions or `async def` coroutines.
The dispatcher handles both automatically.

```python
from daffi import callback

# Sync callback — run in a thread-pool executor (non-blocking to the loop)
@callback
def compute(n: int) -> int:
    return sum(range(n))


# Async callback — awaited directly on the event loop (no thread overhead)
@callback
async def fetch(url: str) -> str:
    import aiohttp
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as resp:
            return await resp.text()
```

!!! warning
    The `@callback` decorator is shared between the sync and async interfaces.
    An `async def` callback **cannot** be used with the synchronous `Client` /
    `Service` / `Router` — it will raise a `TypeError` at call time.  Use
    `daffi.aio` components when you need async callbacks.

---

## Call styles

All four call styles work identically to the sync interface, with `await`
added in front of the blocking ones:

| Style | Async usage | Returns |
|---|---|---|
| `rpc()` | `await conn.rpc(timeout=N).fn(args)` | Single result |
| `cast()` | `await conn.cast(timeout=N).fn(args)` | `{name: result}` dict |
| `rpc_nowait()` | `conn.rpc_nowait().fn(args)` | `None` immediately |
| `cast_nowait()` | `conn.cast_nowait().fn(args)` | `None` immediately |
| `stream()` | `await conn.stream(serde=…).fn(chunk)` | Single result |
| `stream_nowait()` | `conn.stream_nowait(serde=…).fn(chunk)` | `None` immediately |

---

## Serialization

All four wire formats are available and work identically to the sync interface.
Pass `serde=SerdeFormat.<FORMAT>` to `conn.rpc()`, `conn.cast()`, or
`conn.stream()`.

```python
from daffi import SerdeFormat

result = await conn.rpc(timeout=10, serde=SerdeFormat.MSGPACK).echo(payload)
```

See [Serialization](serialization.md) for format details.

---

## Concurrent I/O-bound tasks with `asyncio.gather`

The biggest advantage of `daffi.aio` over the sync interface is firing many
RPCs concurrently **without OS threads**:

```python
import asyncio
from daffi.aio import AsyncClient

async def main():
    # Connect 100 independent callers
    clients = [
        AsyncClient(app_name=f"caller-{i}", host="127.0.0.1", port=6001)
        for i in range(100)
    ]
    conns = await asyncio.gather(*[c.connect() for c in clients])

    # Fire all 100 RPCs simultaneously — one event loop, no OS threads
    results = await asyncio.gather(*[
        conn.rpc(timeout=10).process(i)
        for i, conn in enumerate(conns)
    ])

    print(results)

    await asyncio.gather(*[c.stop() for c in clients])
```

---

## Long-running async callbacks

`async def` callbacks that perform I/O (database queries, HTTP calls, file
reads) yield the event loop while waiting, so other tasks — including
processing new incoming calls — continue uninterrupted:

```python
from daffi import callback
from daffi.aio import AsyncClient
import asyncio

@callback
async def db_query(user_id: int) -> dict:
    # Yields the event loop during the DB round-trip —
    # other RPC calls can be dispatched while this awaits.
    await asyncio.sleep(0)          # placeholder for real DB call
    return {"user_id": user_id, "name": "Alice"}

async def main():
    worker = AsyncClient(
        app_name="db-worker",
        host="127.0.0.1",
        port=6001,
        workers=50,   # 50 concurrent async DB queries — zero OS threads
    )
    await worker.connect()
    await worker.join()

asyncio.run(main())
```

Compare this to the sync interface where `workers=50` creates **50 OS
threads**, each consuming ~8 MB of stack space.

---

## Performance comparison

Measurements on loopback (`127.0.0.1`), Python 3.14, Linux.

### Sequential latency (100k calls, 2 KB payload)

| Format | Sync Direct | Async Direct | Sync Router | Async Router |
|---|---|---|---|---|
| PICKLE  | **15,414** calls/s | 10,969 | **12,448** | 8,826 |
| JSON    | **11,710** | 8,313  | **9,557**  | 7,682 |
| MSGPACK | **15,215** | 11,554 | **12,375** | 9,484 |
| OPAQUE  | **24,870** | 17,400 | **18,462** | 13,068 |

The sync interface wins by **~30–40%** for tight sequential loops.
The overhead comes from the event-loop round-trip per `await`: each call
must suspend the coroutine, signal a `asyncio.Event` on the loop thread,
and reschedule — vs the sync path which just unblocks a semaphore on the
same thread.

This gap disappears completely once you introduce concurrency (see below).

### Concurrent throughput (200 callers × 1,000 calls)

| Scenario | Sync (OS threads) | Async (asyncio tasks) |
|---|---|---|
| 200 callers → Service (workers=10) | 11,423 calls/s | **28,143** (+147%) |
| 200 callers → Router → 1 Worker (200 workers) | 8,490 | **24,358** (+187%) |
| 200 callers → Service (workers=200) | 11,027 | **27,275** (+147%) |

The async interface wins by **2.5–3×** under concurrent load.
200 OS threads compete for the GIL and fight the OS scheduler; 200 asyncio
tasks share one OS thread and switch cooperatively — zero contention.

### Large message throughput (loopback)

Both interfaces hit **~1 GiB/s** for large payloads (≥ 1 MiB) regardless
of serde format — the bottleneck is TCP/loopback bandwidth, not Python
overhead.  Below ~64 KiB the async interface has a slightly higher latency
floor (~0.3 ms vs ~0.1 ms) due to the event-loop scheduling overhead.

### When to use each

| Workload | Recommendation |
|---|---|
| Sequential scripts, one call at a time | **Sync** — lower per-call overhead |
| Many concurrent callers (web servers, event-driven apps) | **Async** — 2–3× higher throughput |
| I/O-bound callbacks (DB, HTTP, file I/O) | **Async** — `async def` callbacks yield the loop |
| CPU-bound callbacks | Either — GIL limits both; use multiple worker processes |
| Mixed async codebase (FastAPI, aiohttp, …) | **Async** — no `run_in_executor` needed |

---

## Mixing sync and async

The `@callback` decorator is shared — a callback registered in one context
is visible to all connected peers.  However, the dispatcher that *executes*
it is interface-specific:

- An `async def` callback used with a sync `Client` raises `TypeError`.
- A `def` (sync) callback used with `AsyncClient` is automatically offloaded
  to a `ThreadPoolExecutor`, keeping the event loop unblocked.

If you need both sync and async nodes in the same process, run the async
components inside `asyncio.run()` in a dedicated thread.

---

## Examples

| Example | Location |
|---|---|
| Basic RPC (router topology) | `examples/aio/router/01_rpc/` |
| Cast / cast_nowait | `examples/aio/router/02_cast/` |
| Bidirectional | `examples/aio/router/03_bidirectional/` |
| Pickle serde | `examples/aio/router/04_serde_pickle/` |
| JSON serde | `examples/aio/router/05_serde_json/` |
| OPAQUE serde | `examples/aio/router/06_serde_opaque/` |
| MSGPACK serde | `examples/aio/router/07_serde_msgpack/` |
| Events | `examples/aio/router/08_events/` |
| Service (direct) | `examples/aio/service/` |
