# Getting Started

## Installation

```bash
pip install daffi
```

Requires Python 3.10 or newer. Linux and macOS are supported.

---

## Quick start — direct communication

1. Create a `Service` instance.

`service.py`:

```python
from daffi import Service, callback, TCPTransport

@callback
def add(a: float, b: float) -> float:
    return a + b

@callback
def greet(name: str) -> str:
    return f"Hello, {name}!"

svc = Service(app_name="my-service", transport=TCPTransport("127.0.0.1", 5000))
svc.start()
svc.join()  # block until svc.stop() is called
```

2. Connect a `Client` to the Service.

`client.py`:

```python
from daffi import Client, TCPTransport

client = Client(app_name="my-client", transport=TCPTransport("127.0.0.1", 5000))
conn = client.connect()

result = conn.rpc().add(1, 2)         # → 3.0
greeting = conn.rpc().greet("Alice")  # → "Hello, Alice!"

client.stop()
```

3. Run the example.

Start the Service first:

```bash
python service.py
```

Then, in another terminal:

```bash
python client.py
```

---

## Distributed architecture — Router and Workers

1. Start a `Router` instance.

`router.py`:

```python
from daffi import Router, TCPTransport

router = Router(transport=TCPTransport("127.0.0.1", 6000))
router.start()
router.join()
```

2. Register a worker.

`worker.py`:

```python
from daffi import Client, callback, TCPTransport

@callback
def process(task: str) -> str:
    return f"done: {task}"

client = Client(app_name="worker-1", transport=TCPTransport("127.0.0.1", 6000))
client.connect()
client.join()  # block until Ctrl+C / SIGTERM
```

3. Create a caller.

`caller.py`:

```python
from daffi import Client, TCPTransport

client = Client(app_name="caller", transport=TCPTransport("127.0.0.1", 6000))
conn = client.connect()

# RPC — routed to one worker (round-robin if many workers expose the same function)
result = conn.rpc().process("job-42")

# Cast — sent to all workers, returns {worker_name: result}
all_results = conn.cast().process("broadcast-job")

client.stop()
```

---

## What just happened?

1. The listener (`Service` or `Router`) starts accepting connections on the transport.
2. `@callback` registers functions at import time; they are advertised during the handshake.
3. `Client.connect()` completes the handshake and returns a connection handle.
4. `conn.rpc()` / `conn.cast()` return proxies — attribute access invokes the remote function.
