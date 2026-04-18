# Via-Dispatcher Examples

These examples demonstrate **brokered** communication: every participant
(worker or caller) connects to a central `Router`.  The router maintains a
registry of which node has registered which function and routes each call
accordingly.

```
          ┌─────────────────────────────┐
          │           Router            │
          │      127.0.0.1:600X         │
          └──────┬──────────┬───────────┘
                 │          │
          connect│          │connect
                 │          │
         ┌───────┴──┐   ┌───┴──────┐
         │  Worker  │   │  Caller  │
         │@callback │   │ rpc/     │
         │functions │   │ stream   │
         └──────────┘   └──────────┘
```

**Key insight**: every participant is a `Client` instance.  Workers register
`@callback` functions; the framework automatically starts a task-dispatcher
when a `Client` connects to a `Router`, so any node can both *make* and
*receive* calls.

| # | Folder | What it shows |
|---|--------|---------------|
| 1 | `01_basic` | One worker + one caller sharing a router |
| 2 | `02_multi_worker` | Two specialised workers (math + text), one caller |
| 3 | `03_broadcast` | Caller sends to all workers at once (receiver=None) |
| 4 | `04_bidirectional` | Two nodes that both call each other through the router |

## Quick-start (example 01_basic)

```bash
# terminal 1
python examples/via_dispatcher/01_basic/router.py

# terminal 2
python examples/via_dispatcher/01_basic/worker.py

# terminal 3
python examples/via_dispatcher/01_basic/caller.py
```

## API summary

```python
from daffi import Router, Client, callback
from daffi.registry import local, alias

# ── Router ────────────────────────────────────────────────────────────────

router = Router(app_name="router", host="127.0.0.1", port=6000)
router.start()
router.join()                      # blocks until Ctrl+C / router.stop()

# ── Worker (Client with callbacks) ────────────────────────────────────────

@callback                          # exposes function to the whole network
def my_func(x: int) -> int:
    return x * 2

client = Client(app_name="my-worker", host="127.0.0.1", port=6000)
client.connect()                   # connects to router; task-dispatcher starts

# keep alive so calls can arrive
import time
while True:
    time.sleep(1)

# ── Caller ────────────────────────────────────────────────────────────────

client = Client(app_name="caller", host="127.0.0.1", port=6000)
conn   = client.connect()

# Target a specific worker by name
rpc = conn.rpc(timeout=5, receiver="my-worker")
result = rpc.my_func(21)

# Broadcast to ALL nodes that registered my_func (no specific receiver)
stream = conn.stream(receiver=None)
stream.my_func(42)                 # fire-and-forget to every matching node

client.stop()
```

### Choosing a receiver

| `receiver=` | Behaviour |
|-------------|-----------|
| `"worker-name"` | Calls only that named node |
| `["a", "b"]` | Calls each node in the list |
| `None` (default) | Router picks any available node with the function |
| `None` + `stream()` | Broadcast: all matching nodes receive the call |
