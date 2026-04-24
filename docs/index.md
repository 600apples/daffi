# daffi

**daffi** is a high-performance Python RPC framework with a native compiled core.  
It lets processes call each other's functions over TCP or Unix sockets — with minimal boilerplate and near-zero overhead.

---

## Key features

| Feature | Details                                                                                                                                       |
|---|-----------------------------------------------------------------------------------------------------------------------------------------------|
| **Native core** | The message framing, connection management and routing logic is implemented in a native compiled extension (`dfcore`) for maximum throughput. |
| **Multiple transports** | TCP, Unix domain sockets, TLS — same API.                                                                                                     |
| **Four call styles** | `rpc`, `rpc_nowait`, `cast`, `cast_nowait` — blocking/non-blocking, single target/broadcast.                                                  |
| **Four serialisation formats** | PICKLE (Python-only, default), JSON, MSGPACK, OPAQUE (raw bytes or string).                                                                   |
| **Event subscriptions** | React to nodes joining and leaving the network.                                                                                               |

---

## Install

```bash
pip install daffi

# optional: MessagePack support
pip install "daffi[msgpack]"
```

---

## 30-second example

**Service** — expose a function:

```python
from daffi import Service, callback

@callback
def add(a: int, b: int) -> int:
    return a + b

svc = Service(app_name="calc", host="127.0.0.1", port=5000)
svc.start()
svc.join()
```

**Client** — call it:

```python
from daffi import Client

client = Client(app_name="my-client", host="127.0.0.1", port=5000)
conn = client.connect()

result = conn.rpc(timeout=5).add(3, 4)   # → 7
client.stop()
```

---

## Two topologies

daffi supports two network topologies:

- **Client → Service** — the Service hosts callbacks; Clients call them directly.  
  Best for simple request/response scenarios.

- **Client → Router → Worker** — a Router forwards calls between Callers and Workers.  
  Workers can be added or removed at runtime without restarting anything.  
  Best for scalable, distributed workloads.

See [Architecture](architecture.md) for diagrams and a deeper explanation.
