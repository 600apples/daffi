# Serialization

daffi supports four wire formats. Pass `serde=SerdeFormat.X` to any call proxy, or use the string shorthand where supported.

```python
from daffi import SerdeFormat
```

---

## PICKLE (default)

Python-native binary serialisation. Supports arbitrary Python objects — dataclasses, Enums, custom classes — as long as both sides share the same class definitions.

```python
# models.py — shared between service and client
from dataclasses import dataclass
from enum import Enum

class Status(Enum):
    PENDING = "pending"
    DONE    = "done"

@dataclass
class Order:
    order_id: str
    amount:   float
    status:   Status = Status.PENDING
```

```python
# 1_service.py
from daffi import Service, callback
from models import Order, Status

@callback
def process_order(order: Order) -> Order:
    order.status = Status.DONE
    return order

svc = Service(app_name="order-service", host="127.0.0.1", port=5004)
svc.start(); svc.join()
```

```python
# 2_client.py
from daffi import Client
from daffi import SerdeFormat
from models import Order

client = Client(app_name="order-client", host="127.0.0.1", port=5004)
conn = client.connect()

order = Order(order_id="ORD-001", amount=99.95)
result = conn.rpc(timeout=5, serde=SerdeFormat.PICKLE).process_order(order)
print(result.status)   # Status.DONE
```

!!! warning
    PICKLE is Python-only. Use JSON or MSGPACK when interoperating with non-Python processes.

---

## JSON

Language-agnostic. Works with plain Python types: `dict`, `list`, `str`, `int`, `float`, `bool`, `None`. Use when interoperating with non-Python processes.

```python
# 1_service.py
from daffi import Service, callback

@callback
def summarise(data: dict) -> dict:
    items = data.get("items", [])
    total = sum(i["price"] * i["qty"] for i in items)
    return {"item_count": len(items), "total": round(total, 2)}

svc = Service(app_name="json-service", host="127.0.0.1", port=5005)
svc.start(); svc.join()
```

```python
# 2_client.py
from daffi import Client
from daffi import SerdeFormat

client = Client(app_name="json-client", host="127.0.0.1", port=5005)
conn = client.connect()

payload = {"items": [{"price": 9.99, "qty": 2}, {"price": 4.99, "qty": 5}]}
result = conn.rpc(timeout=5, serde=SerdeFormat.JSON).summarise(payload)
print(result)   # {"item_count": 2, "total": 44.93}
```

---

## MSGPACK

Binary MessagePack encoding — more compact than JSON, same type support. Ideal for high-throughput pipelines or when bandwidth matters.

Requires: `pip install "daffi[msgpack]"`

```python
# 1_service.py
from daffi import Service, callback

@callback
def transform(record: dict) -> dict:
    result = {k.lower(): v for k, v in record.items()}
    if "first_name" in result and "last_name" in result:
        result["full_name"] = f"{result['first_name']} {result['last_name']}"
    return result

svc = Service(app_name="msgpack-service", host="127.0.0.1", port=5007)
svc.start(); svc.join()
```

```python
# 2_client.py
from daffi import Client
from daffi import SerdeFormat

client = Client(app_name="msgpack-client", host="127.0.0.1", port=5007)
conn = client.connect()

result = conn.rpc(timeout=5, serde=SerdeFormat.MSGPACK).transform(
    {"First_Name": "Alice", "Last_Name": "Smith"}
)
print(result)   # {"first_name": "Alice", "last_name": "Smith", "full_name": "Alice Smith"}
```

---

## OPAQUE (raw bytes or string)

Passes raw bytes through with no serialisation. The callback receives a `bytes` object. Use for custom binary protocols or when you want total control over encoding.

!!! tip "Fastest option"
    OPAQUE skips the serialisation/deserialisation step entirely, making it **10–20% faster than PICKLE or MSGPACK** in throughput-sensitive workloads. If you can handle encoding yourself (e.g. struct pack, protobuf, custom binary format) this is the best choice for raw performance.

```python
# 1_service.py
from daffi import Service, callback

@callback
def echo_raw(data: bytes) -> bytes:
    print(f"[service] received {len(data)} bytes")
    return data   # echo back

svc = Service(app_name="raw-service", host="127.0.0.1", port=5006)
svc.start(); svc.join()
```

```python
# 2_client.py
from daffi import Client
from daffi import SerdeFormat

client = Client(app_name="raw-client", host="127.0.0.1", port=5006)
conn = client.connect()

payload = b"\x01\x02\x03\x04"
result = conn.rpc(timeout=5, serde=SerdeFormat.OPAQUE).echo_raw(payload)
print(result)   # b'\x01\x02\x03\x04'
```

---

## Format comparison

| Format | Constant | Cross-language | Python objects | Binary |
|---|---|---|---|---|
| PICKLE | `SerdeFormat.PICKLE` | No | Yes | Yes |
| JSON | `SerdeFormat.JSON` | Yes | No | No |
| MSGPACK | `SerdeFormat.MSGPACK` | Yes | No | Yes |
| OPAQUE | `SerdeFormat.OPAQUE` | Yes | No | Yes |

---

## Examples

| Example | Location |
|---|---|
| PICKLE | `examples/service/04_serde_pickle/` |
| JSON | `examples/service/05_serde_json/` |
| OPAQUE | `examples/service/06_serde_opaque/` |
| MSGPACK | `examples/service/07_serde_msgpack/` |
