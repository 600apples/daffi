# Client → Router → Worker

![Router topology](../images/router-topology.png)

The Router topology decouples callers from workers. The **Router** is a pure message forwarder; **Workers** register their callbacks with it; **Callers** invoke those callbacks through it.

---

## 1. Start the Router

The Router has no callbacks of its own — it only forwards messages.

```python
from daffi import Router

if __name__ == "__main__":
    router = Router(host="127.0.0.1", port=6001)
    router.start()
    print("Router running on 127.0.0.1:6001 — press Ctrl+C to stop.")
    router.join()
```

### `Router` parameters

| Parameter | Type | Description |
|---|---|---|
| `host` | `str` | TCP host to listen on. |
| `port` | `int` | TCP port to listen on. |
| `tls` | `bool` | Enable TLS (requires `cert_file` / `key_file`). |

---

## 2. Connect Workers

Workers are **Clients** that expose `@callback` functions.  
Start as many instances as you need — the Router load-balances across them.

```python
from daffi import Client, callback

@callback
def multiply(a: int, b: int) -> int:
    print(f"[worker] multiply({a}, {b})")
    return a * b

if __name__ == "__main__":
    worker = Client(app_name="calc-worker", host="127.0.0.1", port=6001)
    worker.connect()
    print("Worker connected — press Ctrl+C to stop.")
    worker.join()
```

!!! tip
    Run two instances of this script in separate terminals.  
    `rpc()` will round-robin between them; `cast()` will call both.

---

## 3. Connect a Caller

Callers are also **Clients** — they just don't expose any `@callback` functions.

```python
from daffi import Client

if __name__ == "__main__":
    caller = Client(app_name="calc-caller", host="127.0.0.1", port=6001)
    conn = caller.connect()

    # Round-robin — any available worker handles this call.
    result = conn.rpc(timeout=5).multiply(6, 7)
    print(f"multiply(6, 7) = {result}")   # → 42

    # Pin to a specific worker by name.
    result = conn.rpc(timeout=5, receiver="calc-worker").multiply(3, 3)
    print(f"multiply(3, 3) [pinned] = {result}")   # → 9

    caller.stop()
```

---

## Bidirectional communication

Because every Client can *both* expose callbacks and call remote ones,
bidirectional communication is natural: two nodes connect to the same Router
and call each other.

```python
# node_a.py
from daffi import Client, callback

@callback
def hello_from_a(msg: str) -> str:
    return f"A received: {msg}"

node_a = Client(app_name="node-A", host="127.0.0.1", port=6003)
conn = node_a.connect()

# Call node-B's callback
reply = conn.rpc(timeout=5, receiver="node-B").hello_from_b("hi from A")
print(reply)
```

```python
# node_b.py
from daffi import Client, callback

@callback
def hello_from_b(msg: str) -> str:
    return f"B received: {msg}"

node_b = Client(app_name="node-B", host="127.0.0.1", port=6003)
conn = node_b.connect()
node_b.join()
```

---

## Automatic reconnection

If the Router is restarted, connected clients lose their link.  Pass
`autoreconnect=True` to have `connect()` return an **`AutoReconnect`**
adapter instead of a plain `ClientConnection`.  Every call made through
the adapter (`rpc`, `cast`, `stream`, …) checks the connection liveness
first: if the link is down it **blocks with exponential back-off** until
the Router comes back, then sends the request on the fresh connection.

```python
from daffi import Client, callback

@callback
def multiply(a: int, b: int) -> int:
    return a * b

if __name__ == "__main__":
    client = Client(
        app_name="calc-caller",
        host="127.0.0.1",
        port=6001,
        autoreconnect=True,   # connect() returns AutoReconnect adapter
        reconnect_delay=2.0,  # first retry after 2 s; then 4 s, 8 s … up to 60 s
    )
    conn = client.connect()   # conn is AutoReconnect, same API as ClientConnection

    while True:
        # If the router is down, this call blocks here until reconnected.
        result = conn.rpc(timeout=5).multiply(6, 7)
        print(f"multiply(6, 7) = {result}")
```

For workers (no outgoing RPC calls, only incoming callbacks), the adapter is
still returned and the task-dispatcher is restarted automatically after each
reconnect — callbacks are re-announced to the new Router:

```python
if __name__ == "__main__":
    worker = Client(
        app_name="calc-worker",
        host="127.0.0.1",
        port=6001,
        autoreconnect=True,
        reconnect_delay=2.0,
    )
    conn = worker.connect()  # AutoReconnect; callbacks re-registered on reconnect
    worker.join()
```

When the Router restarts the worker logs the reconnect cycle:

```
WARNING  … Connection lost — reconnecting in 2.0 s…
WARNING  … Connection lost — reconnecting in 4.0 s…
INFO     … has been connected successfully. connection info: tcp: […]
INFO     … 'multiply' registered.
```

`reconnect_delay` controls the *base* retry interval; it doubles after each
failed attempt, capped at 60 seconds.

---

## cast() via Router

`cast()` fans out to **every** worker that exposes the requested function and collects all results.

```python
conn = caller.connect()

# Call all workers — returns {"worker-1": result, "worker-2": result, ...}
results = conn.cast(timeout=5).process("task-A")
print(results)

# Restrict broadcast to a subset of workers.
results = conn.cast(timeout=5, receiver=["worker-1"]).process("task-B")

# Fire-and-forget broadcast.
conn.cast_nowait().process("task-C")
```

---

## Waiting for members

In a multi-worker environment the caller often starts before all workers are
online.  Instead of adding `time.sleep()` calls or wrapping every RPC in a
try/except retry loop, use `conn.wait_for_members()` to **block until the
required peers appear** in the Router's member registry:

```python
from daffi import Client

if __name__ == "__main__":
    caller = Client(app_name="calc-caller", host="127.0.0.1", port=6001)
    conn = caller.connect()

    # Block until both workers have registered — start order doesn't matter.
    conn.wait_for_members("worker-1", "worker-2")

    # Safe to call now — both peers are guaranteed to be online.
    results = conn.cast(timeout=10).process("task")
    print(results)

    caller.stop()
```

The method polls the native ChannelsMapper every `interval` seconds (default
`1.0 s`) and returns as soon as all listed names appear.  An optional
`timeout` parameter raises `TimeoutError` if the deadline is exceeded:

```python
from daffi import Client

conn = Client(app_name="caller", host="127.0.0.1", port=6001).connect()

# Raise TimeoutError after 30 s if the worker hasn't joined yet.
conn.wait_for_members("slow-worker", timeout=30)

# Change the poll interval.
conn.wait_for_members("worker-1", "worker-2", interval=0.5)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `*members` | `str` | — | One or more peer names to wait for. |
| `timeout` | `float \| None` | `None` | Max seconds to wait. `None` = wait forever. |
| `interval` | `float` | `1.0` | Poll interval in seconds. |

`wait_for_members()` is also available on the `AutoReconnect` adapter returned
when `autoreconnect=True`.

---

## Examples

| Example | Location |
|---|---|
| Basic rpc via router | `examples/router/01_rpc/` |
| cast / cast_nowait via router | `examples/router/02_cast/` |
| Bidirectional communication | `examples/router/03_bidirectional/` |
| Pickle serde | `examples/router/04_serde_pickle/` |
| JSON serde | `examples/router/05_serde_json/` |
| OPAQUE serde | `examples/router/06_serde_opaque/` |
| MSGPACK serde | `examples/router/07_serde_msgpack/` |
| Events via router | `examples/router/08_events/` |
| Waiting for members | `examples/router/09_wait_for_members/` |
