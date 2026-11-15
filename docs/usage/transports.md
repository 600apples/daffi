# Transports

Daffi supports multiple transport mechanisms for communication between processes.

`Client` accepts a single transport. `Router` and `Service` accept one transport or a sequence of them — every listener shares that node's membership, and `start()` brings all of them up together.

---

## TCP

Use `TCPTransport` to communicate between processes over a network or localhost.

```python
from daffi import Service, Client, TCPTransport

svc = Service(
    transport=TCPTransport("127.0.0.1", 5000),
)
svc.start()

client = Client(
    transport=TCPTransport("127.0.0.1", 5000),
)
conn = client.connect()
```

---

## Unix domain sockets

Use `UnixTransport` for inter-process communication on the same machine, without binding a TCP port.

!!! info "Platform support"
    Unix sockets are supported on **Linux** and **macOS** only.

```python
from daffi import Service, Client, UnixTransport

svc = Service(
    transport=UnixTransport("/tmp/daffi.sock"),
)
svc.start()

client = Client(
    transport=UnixTransport("/tmp/daffi.sock"),
)
conn = client.connect()
```

The API is identical to TCP — only the transport constructor changes.

### Existing socket files

`start()` removes a socket file left behind by a server that is gone. It refuses to start, and leaves the path alone, when the path is something other than a socket, or a socket another server is still accepting on.

---

## Multiple transports

A common pattern is to expose both TCP (for remote clients or workers) and a Unix socket (for processes on the same host):

```python
from daffi import Router, Client, TCPTransport, UnixTransport

tcp = TCPTransport("0.0.0.0", 6000)
unix = UnixTransport("/tmp/daffi.sock")

router = Router(
    transport=[tcp, unix],
)
router.start()

# Remote worker connects over TCP
remote = Client(
    app_name="worker-remote",
    transport=TCPTransport("127.0.0.1", 6000),
)
remote.connect()

# Co-located client connects over the Unix socket
local = Client(
    app_name="worker-local",
    transport=UnixTransport("/tmp/daffi.sock"),
)
local.connect()
```

Listeners may also use different TLS settings — for example TLS on TCP and plaintext on a Unix socket. See [Security](tls.md).

---

## Choosing a transport

| Transport | Use when |
|---|---|
| **TCP** | Communication between processes on the same or different machines |
| **Unix sockets** | Local inter-process communication |
| **Both** | TCP for remote peers, Unix for co-located clients or workers |

---

## Examples

| Example | Location |
|---|---|
| Unix socket | `examples/service/08_unix_socket/` |
| TCP and Unix on one Service | `examples/service/11_multitransport/` |
| TCP and Unix on one Router | `examples/router/10_multitransport/` |
