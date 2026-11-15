# Callbacks and concurrency

Callbacks are Python functions or bound methods that can be invoked remotely by other nodes.

## Defining callbacks

Use the `@callback` decorator to register a remotely callable function.

```python
from daffi import callback


@callback
def echo(payload):
    return payload


@callback
def compute(x: int, y: int) -> int:
    return x * y
```

Callback registration happens at import time.

Both `Service` and `Client` instances can expose callbacks.

### Class callbacks

Apply `@callback` to an entire class. Daffi instantiates it (no-argument constructor) and registers every public method as a remote callback.

**Rules:**

- Methods whose names start with `_` are skipped.
- Methods decorated with `@local` are excluded — they remain local only.
- All other public methods become remotely callable.

```python
from daffi import callback
from daffi.registry import local


@callback
class TextProcessor:
    def __init__(self):
        self._call_count = 0

    def upper(self, text: str) -> str:
        self._call_count += 1
        return text.upper()

    def reverse(self, text: str) -> str:
        return text[::-1]

    @local
    def reset(self):
        """Not exported — only callable within this process."""
        self._call_count = 0
```

The class must be constructable with no arguments when decorated at class level. If you need constructor arguments, initialise the object first and decorate its methods individually.

---

## Concurrent callback execution

By default, each node executes incoming callbacks sequentially using a single execution thread:

```python
workers=1
```

To execute multiple callbacks concurrently, configure the `workers` parameter.

```python
import time

from daffi import Service, callback, TCPTransport


@callback
def slow_task(n: int) -> int:
    time.sleep(1)
    return n * n


svc = Service(
    workers=4,
    transport=TCPTransport("127.0.0.1", 5000),
)

svc.start()
svc.join()
```

With `workers=4`, up to four callbacks can execute concurrently.

The same parameter is available on a `Client` acting as a worker:

```python
client = Client(
    app_name="worker-1",
    workers=8,
    transport=TCPTransport("127.0.0.1", 6000),
)
```

---

## Choosing the right worker count

- **I/O-bound callbacks:** Increasing `workers` can improve concurrency when callbacks perform network requests, database queries, or file operations.
- **Lightweight callbacks:** Keep `workers=1` when sequential execution is sufficient.
- **CPU-bound callbacks:** Python's GIL limits parallel execution of Python bytecode within a single process. Prefer multiple worker processes behind a Router for CPU-intensive workloads.

See [Direct topology](service.md) and [Router and workers](router.md) for how `workers` fits each topology.
