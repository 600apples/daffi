# Async interface (`daffi.aio`)

`daffi.aio` is an asyncio-native interface that mirrors the synchronous Daffi API. OS threads are replaced with coroutines, blocking calls with `await`, and the event loop is never blocked.

All public methods (`connect`, `start`, `join`, `stop`) are `async def`. Callbacks can be regular functions or `async def` coroutines.

The native runtime (`threads` / `evented`) is independent of `daffi.aio` — both models work with the async interface. See [Native runtime](runtime.md).

---

## Quick start

=== "Service (direct)"

    ```python
    # 1_service.py
    import asyncio
    from daffi import callback, TCPTransport
    from daffi.aio import AsyncService

    @callback
    async def multiply(a: int, b: int) -> int:
        return a * b

    async def main():
        svc = AsyncService(
            app_name="calc-service",
            transport=TCPTransport("127.0.0.1", 6001),
        )
        await svc.start()
        await svc.join()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

    ```python
    # 2_caller.py
    import asyncio
    from daffi import TCPTransport
    from daffi.aio import AsyncClient

    async def main():
        client = AsyncClient(
            app_name="calc-caller",
            transport=TCPTransport("127.0.0.1", 6001),
        )
        conn = await client.connect()

        result = await conn.rpc(timeout=5).multiply(6, 7)
        print(result)  # → 42

        await client.stop()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

=== "Router + Worker"

    ```python
    # 1_router.py
    import asyncio
    from daffi import TCPTransport
    from daffi.aio import AsyncRouter

    async def main():
        router = AsyncRouter(transport=TCPTransport("127.0.0.1", 6001))
        await router.start()
        await router.join()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

    ```python
    # 2_worker.py
    import asyncio
    from daffi import callback, TCPTransport
    from daffi.aio import AsyncClient

    @callback
    async def multiply(a: int, b: int) -> int:
        return a * b

    async def main():
        worker = AsyncClient(
            app_name="calc-worker",
            transport=TCPTransport("127.0.0.1", 6001),
        )
        await worker.connect()
        await worker.join()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

    ```python
    # 3_caller.py
    import asyncio
    from daffi import TCPTransport
    from daffi.aio import AsyncClient

    async def main():
        caller = AsyncClient(
            app_name="calc-caller",
            transport=TCPTransport("127.0.0.1", 6001),
        )
        conn = await caller.connect()

        result = await conn.rpc(timeout=5).multiply(6, 7)
        print(result)  # → 42

        await caller.stop()

    if __name__ == "__main__":
        asyncio.run(main())
    ```

---

## Classes

| Async class | Sync equivalent | Role |
|---|---|---|
| `AsyncClient` | `Client` | Connect to a Router or Service; call remote callbacks; optionally expose your own. |
| `AsyncService` | `Service` | Listen for incoming connections. |
| `AsyncRouter` | `Router` | Forward messages between Clients. |

---

## API overview

### `AsyncClient`

```python
from daffi import TCPTransport
from daffi.aio import AsyncClient

client = AsyncClient(
    app_name="my-client",
    workers=1,
    transport=TCPTransport("127.0.0.1", 6001),
)

conn = await client.connect()
await client.join()
await client.stop()
```

Calls still waiting when the client stops raise `Disconnected`, as in the sync interface.

#### Member events

`on_member_added` / `on_member_removed` handlers may be regular functions or `async def` coroutines. Coroutines run on the event loop; regular functions run on a worker thread, so they must not touch asyncio objects directly — use `loop.call_soon_threadsafe`.

```python
loop = asyncio.get_running_loop()
joined = asyncio.Event()

@conn.on_member_added
def _added(name: str):
    loop.call_soon_threadsafe(joined.set)
```

#### `workers`

| Value | Behaviour |
|---|---|
| `1` (default) | One incoming callback at a time. |
| `N` | Up to `N` callbacks run concurrently, each in its own `asyncio.Task`. |

Requests beyond the limit stay queued; once the queue is full, callers get `ServiceOverloaded`.

### `AsyncService` / `AsyncRouter`

```python
from daffi.aio import AsyncService, AsyncRouter

svc = AsyncService(app_name="my-service", workers=4, transport=TCPTransport("0.0.0.0", 6001))
await svc.start()
await svc.join()
await svc.stop()

router = AsyncRouter(transport=TCPTransport("0.0.0.0", 6001))
await router.start()
await router.join()
```

### `AsyncClientConnection`

Proxy methods return awaitables — you must `await` each call.

```python
from daffi import SerdeFormat

conn = await client.connect()

result = await conn.rpc(timeout=10).my_function(arg1, arg2)
results = await conn.cast(timeout=10).my_function(arg1)

await conn.rpc_nowait().my_function(arg1)
await conn.cast_nowait().my_function(arg1)

await conn.stream(serde=SerdeFormat.OPAQUE).process_stream(chunk_source("large.bin"))
await conn.stream_nowait(serde=SerdeFormat.OPAQUE).process_stream(chunk_source("large.bin"))

await conn.wait_for_members("worker-1", "worker-2", timeout=30)
```

---

## Async callbacks

```python
from daffi import callback

@callback
def compute(n: int) -> int:
    return sum(range(n))

@callback
async def fetch(url: str) -> str:
    import aiohttp
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as resp:
            return await resp.text()
```

!!! warning
    An `async def` callback cannot be used with the synchronous `Client` / `Service` / `Router` — it raises `TypeError` at call time. Use `daffi.aio` components for async callbacks.

---

## Communication patterns

All six call styles work like the sync interface, with `await` added:

| Style | Async usage | Returns |
|---|---|---|
| `rpc()` | `await conn.rpc(timeout=N).fn(args)` | Single result |
| `rpc_nowait()` | `await conn.rpc_nowait().fn(args)` | `None` once sent |
| `cast()` | `await conn.cast(timeout=N).fn(args)` | `{name: result}` dict |
| `cast_nowait()` | `await conn.cast_nowait().fn(args)` | `None` once sent |
| `stream()` | `await conn.stream(serde=…).fn(iterator)` | `None` |
| `stream_nowait()` | `await conn.stream_nowait(serde=…).fn(iterator)` | `None` once sent |

See [Communication patterns](call-styles.md) and [Serialization](serialization.md).

---

## Concurrent I/O with `asyncio.gather`

Fire many RPCs concurrently without OS threads:

```python
import asyncio
from daffi import TCPTransport
from daffi.aio import AsyncClient

async def main():
    clients = [
        AsyncClient(app_name=f"caller-{i}", transport=TCPTransport("127.0.0.1", 6001))
        for i in range(100)
    ]
    conns = await asyncio.gather(*[c.connect() for c in clients])

    results = await asyncio.gather(*[
        conn.rpc(timeout=10).process(i)
        for i, conn in enumerate(conns)
    ])

    await asyncio.gather(*[c.stop() for c in clients])
```

`async def` callbacks that perform I/O yield the event loop while waiting, so other tasks continue uninterrupted.

---

## When to use sync vs async

| Workload | Recommendation |
|---|---|
| Sequential scripts, one call at a time | Sync — simpler, lower per-call overhead |
| Many concurrent callers | Async — cooperative scheduling without OS threads |
| I/O-bound callbacks (DB, HTTP, file I/O) | Async — `async def` callbacks yield the loop |
| CPU-bound callbacks | Either — GIL limits both; use multiple worker processes |
| Mixed async codebase (FastAPI, aiohttp, …) | Async — no `run_in_executor` needed for the Daffi surface |

### Mixing sync and async

- An `async def` callback used with a sync `Client` raises `TypeError`.
- A sync `def` callback used with `AsyncClient` is offloaded to a `ThreadPoolExecutor`.

If you need both sync and async nodes in the same process, run the async components inside `asyncio.run()` in a dedicated thread.

---

## Examples

| Example | Location |
|---|---|
| Basic RPC (router topology) | `examples/aio/router/01_rpc/` |
| Cast / cast_nowait | `examples/aio/router/02_cast/` |
| Bidirectional | `examples/aio/router/03_bidirectional/` |
| Serialization formats | `examples/aio/router/04_serde_pickle/` … `07_serde_msgpack/` |
| Events | `examples/aio/router/08_events/` |
| Service (direct) | `examples/aio/service/` |
