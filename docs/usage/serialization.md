# Serialization

Daffi supports multiple serialization formats, allowing applications to choose between interoperability, readability, flexibility, and performance.

Specify the desired format using `serde=SerdeFormat.X` on a communication method.

| Format | Description | Typical use case |
|---|---|---|
| `MSGPACK` | Compact binary serialization. Default format. | General-purpose communication |
| `JSON` | Human-readable, JSON-compatible data. | Interoperability and debugging |
| `OPAQUE` | Raw bytes or strings without structured serialization. | High-throughput data transfer |
| `PICKLE` | Python object serialization. | Python-specific object exchange |

---

## Examples

```python
from daffi import Client, SerdeFormat

conn = client.connect()

# MessagePack (default)
result = conn.rpc(timeout=5).add(1, 2)

# JSON
result = conn.rpc(
    timeout=5,
    serde=SerdeFormat.JSON,
).add(1, 2)

# Opaque binary data
result = conn.rpc(
    timeout=5,
    serde=SerdeFormat.OPAQUE,
).receive_data(binary_payload)
```

---

## Format details

### MSGPACK (default)

Binary MessagePack encoding — more compact than JSON, with the same basic type support (`dict`, `list`, `str`, `int`, `float`, `bool`, `None`). Cross-language. Required dependency of Daffi.

### JSON

Language-agnostic. Works with plain Python types that are JSON-compatible. Prefer JSON when interoperating with non-Python processes or when human-readable payloads help debugging.

### OPAQUE

Passes raw `bytes` or strings through without structured serialization. Use for custom binary protocols, pre-encoded payloads, or streaming large binary chunks. Both `stream()` and `stream_nowait()` default to `OPAQUE`.

### PICKLE

Python-native serialization. Supports arbitrary Python objects — dataclasses, Enums, custom classes — as long as both sides share the same class definitions. Not cross-language.

```python
from dataclasses import dataclass
from daffi import Client, SerdeFormat, TCPTransport

@dataclass
class Order:
    order_id: str
    amount: float

client = Client(transport=TCPTransport("127.0.0.1", 5004))
conn = client.connect()

order = Order(order_id="ORD-001", amount=99.95)
result = conn.rpc(timeout=5, serde=SerdeFormat.PICKLE).process_order(order)
```

---

## Pickle serialization and security

Deserializing untrusted pickle data can execute arbitrary code. Only use it when the sender and transmitted data are trusted.

Daffi provides a receiver-side deserialization policy. The default `serdes=` is `SerdeFormat.ALL` (includes PICKLE). Pass `serdes=SerdeFormat.SAFE` to refuse pickle:

```python
from daffi import Service, SerdeFormat, TCPTransport

svc = Service(
    app_name="public-service",
    serdes=SerdeFormat.SAFE,  # refuses PICKLE
    transport=TCPTransport("127.0.0.1", 5004),
)
```

A request in a format outside `serdes=` is answered with `SerdeNotAllowed` and never decoded.

PICKLE from a WebSocket peer is always refused: any web page can open a WebSocket to a server on the user's machine.

!!! warning
    Do not treat serialization format selection as a substitute for authentication or trust validation. Prefer `serdes=SerdeFormat.SAFE` together with `auth_token=` and [TLS](tls.md) when peers are not fully trusted.

---

## Format comparison

| Format | Cross-language | Arbitrary Python objects | Binary |
|---|---|---|---|
| `MSGPACK` | Yes | No | Yes |
| `JSON` | Yes | No | No |
| `OPAQUE` | Yes | No | Yes |
| `PICKLE` | No | Yes | Yes |

---

## Examples

| Example | Location |
|---|---|
| PICKLE | `examples/service/04_serde_pickle/` |
| JSON | `examples/service/05_serde_json/` |
| OPAQUE | `examples/service/06_serde_opaque/` |
| MSGPACK | `examples/service/07_serde_msgpack/` |
