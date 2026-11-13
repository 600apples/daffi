# Communication patterns

Daffi provides several communication patterns through the connection handle returned by `client.connect()`.

```python
conn = client.connect()
```

Each method returns a proxy that allows remote functions to be invoked through attribute access.

---

## RPC — `rpc()`

Execute a remote function and wait for its result.

In a Router topology, calls are distributed across matching workers using round-robin selection.

```python
result = conn.rpc(timeout=5).echo("hello")

result = conn.rpc(
    timeout=5,
    serde=SerdeFormat.JSON,
).add(1, 2)
```

To target a specific worker, use `receiver`:

```python
result = conn.rpc(
    timeout=5,
    receiver="worker-1",
).process("task")
```

`receiver` is only relevant when connecting through a Router with multiple workers. In the Service topology there is always exactly one receiver — the Service itself.

| Option | Type | Default | Description |
|---|---|---|---|
| `timeout` | `float \| None` | `None` | Seconds to wait. `None` waits forever. |
| `receiver` | `str \| list[str] \| None` | `None` | Pin to a specific node, or rotate among the listed names. |
| `serde` | `SerdeFormat` | `MSGPACK` | Serialization format. |

---

## Fire-and-forget — `rpc_nowait()`

Invoke a remote function without waiting for its result.

```python
conn.rpc_nowait().notify("event happened")
```

| Option | Type | Default | Description |
|---|---|---|---|
| `receiver` | `str \| list[str] \| None` | `None` | Pin to a specific node. |
| `serde` | `SerdeFormat` | `MSGPACK` | Serialization format. |

---

## Broadcast — `cast()`

Execute a remote function on all matching workers and collect their results.

The returned dictionary maps worker names to their respective results.

```python
results = conn.cast(timeout=5).echo("ping")

# Example:
# {
#     "worker-01": "ping",
#     "worker-02": "ping",
# }
```

Restrict the broadcast with `receiver`:

```python
results = conn.cast(
    timeout=5,
    receiver=["worker-A", "worker-C"],
).process("payload")
```

When using `cast()` against a single Service, the dict has exactly one entry.

| Option | Type | Default | Description |
|---|---|---|---|
| `timeout` | `float \| None` | `None` | Per-worker timeout. |
| `receiver` | `str \| list[str] \| None` | `None` | Restrict to these worker names. `None` = all. |
| `serde` | `SerdeFormat` | `MSGPACK` | Serialization format. |

---

## Broadcast without waiting — `cast_nowait()`

Broadcast a function call without collecting results.

```python
conn.cast_nowait().notify("broadcast event")
```

| Option | Type | Default | Description |
|---|---|---|---|
| `receiver` | `str \| list[str] \| None` | `None` | Restrict to these worker names. `None` = all. |
| `serde` | `SerdeFormat` | `MSGPACK` | Serialization format. |

---

## Streaming — `stream()`

Send data in chunks with backpressure.

The sender waits for acknowledgement before sending the next chunk. The callback's return value is discarded; only the acknowledgement matters. Defaults to `SerdeFormat.OPAQUE`.

```python
@callback
def process_stream(data: bytes) -> None:
    ...


# Split a large payload into fixed-size chunks (e.g. 64 KiB)
payload = open("large.bin", "rb").read()
chunks = [payload[i:i + 65536] for i in range(0, len(payload), 65536)]

sender = conn.stream(serde=SerdeFormat.OPAQUE)

for chunk in chunks:
    sender.process_stream(chunk)
```

Or pass an iterator / generator directly — `stream()` consumes it and sends each yielded value:

```python
def chunk_source(path: str, size: int = 65536):
    with open(path, "rb") as f:
        while chunk := f.read(size):
            yield chunk


conn.stream(serde=SerdeFormat.OPAQUE).process_stream(
    chunk_source("large.bin"),
)
```

| Option | Type | Default | Description |
|---|---|---|---|
| `receiver` | `str \| None` | `None` | Pin to a specific worker. `None` picks one round-robin. |
| `serde` | `SerdeFormat` | `OPAQUE` | Serialization format for each chunk. |
| `timeout` | `float \| None` | `None` | Seconds to wait per chunk ack. |

---

## Streaming without waiting — `stream_nowait()`

Send streaming data without waiting for acknowledgements.

```python
conn.stream_nowait(serde=SerdeFormat.OPAQUE).process_stream(
    chunk_source("large.bin"),
)
```

!!! warning "No backpressure"
    The service queues incoming chunks as fast as the network delivers them. If the producer outpaces the consumer, messages accumulate until OS-level TCP flow control stalls the sender.

| Option | Type | Default | Description |
|---|---|---|---|
| `receiver` | `str \| None` | `None` | Pin to a specific worker. `None` picks one round-robin. |
| `serde` | `SerdeFormat` | `OPAQUE` | Serialization format for each chunk. |

---

## Summary

| Method | Target | Returns | Blocks? |
|---|---|---|---|
| `rpc()` | One worker (RR or pinned) | Single result | Yes |
| `rpc_nowait()` | One worker (RR or pinned) | `None` | No |
| `cast()` | All matching workers | `{name: result}` dict | Yes |
| `cast_nowait()` | All matching workers | `None` | No |
| `stream()` | One worker (RR or pinned) | `None` | Yes per chunk (backpressure) |
| `stream_nowait()` | One worker (RR or pinned) | `None` | No (no backpressure) |

---

## Examples

| Example | Location |
|---|---|
| Basic rpc via router | `examples/router/01_rpc/` |
| cast / cast_nowait | `examples/router/02_cast/` |
| Generator streaming | `examples/service/10_stream/` |
