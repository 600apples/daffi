# TLS

daffi supports TLS encryption for TCP connections. Enable it per
`TCPTransport` to protect traffic between nodes on untrusted networks.
Unix-domain sockets stay plaintext (they are local to the machine).

`cert`, `key`, and `ca` accept either a **filesystem path** or the **PEM
material** itself. The native layer treats a value that starts with
`-----BEGIN ` as PEM and loads it from memory; anything else is a path.

---

## Server (Service / Router)

```python
from daffi import Service, callback, TCPTransport

@callback
def secret(data: str) -> str:
    return f"secure: {data}"

svc = Service(
    app_name="tls-service",
    transport=TCPTransport(
        "0.0.0.0",
        5443,
        tls=True,
        cert="/path/to/server.crt",
        key="/path/to/server.key",
    ),
)
svc.start()
svc.join()
```

Inline PEM works the same way:

```python
TCPTransport(
    "0.0.0.0",
    5443,
    tls=True,
    cert=open("server.crt").read(),
    key=open("server.key").read(),
)
```

Different listeners may use different TLS settings — for example TLS on TCP
and plaintext on a Unix socket:

```python
from daffi import Router, TCPTransport, UnixTransport

router = Router(
    transport=[
        TCPTransport(
            "0.0.0.0",
            5443,
            tls=True,
            cert="/path/to/server.crt",
            key="/path/to/server.key",
        ),
        UnixTransport("/tmp/daffi.sock"),
    ],
)
```

---

## Client

```python
from daffi import Client, TCPTransport

client = Client(
    app_name="tls-client",
    transport=TCPTransport(
        "127.0.0.1",
        5443,
        tls=True,
        # Optional: CA path or PEM. Empty = verify against the system trust store.
        ca="/path/to/ca.crt",
    ),
)
conn = client.connect()
result = conn.rpc(timeout=5).secret("hello")
print(result)
client.stop()
```

---

## Parameter reference

| Parameter | Role | Description |
|---|---|---|
| `tls=True` | Both | Enable TLS on this transport. |
| `cert` | Server / client | Path or PEM for the local certificate (server identity, or client identity for mTLS). |
| `key` | Server / client | Path or PEM for the local private key. |
| `ca` | Server / client | Path or PEM for the peer trust store. On a **listener**, non-empty `ca` enables **mutual TLS** (clients must present a cert). On a **client**, the trust store the server's certificate and host name are verified against. Empty on the client = the system trust store. |
| `verify` | Client | `True` (default) verifies the server. `False` accepts any certificate: the traffic is encrypted, but anyone on the path can impersonate the server. |

These options live on `TCPTransport` / `UnixTransport`, not on `Router` / `Service` / `Client`.

---

## Mutual TLS

Set `ca` on the listening transport and give the client matching `cert` /
`key` (and usually the same `ca` to verify the server):

```python
# Server — require client certificates
Service(
    transport=TCPTransport(
        "0.0.0.0", 5443,
        tls=True,
        cert=server_cert, key=server_key,
        ca=client_ca,  # trust store for clients
    ),
)

# Client — present an identity the server trusts
Client(
    transport=TCPTransport(
        "127.0.0.1", 5443,
        tls=True,
        ca=server_ca,
        cert=client_cert, key=client_key,
    ),
)
```

A self-signed setup can use one certificate as server identity, client
identity, and CA on both sides.

---

## Generating self-signed certificates (for development)

```bash
# Generate CA key + cert
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/CN=daffi-ca"

# Generate server key + cert signed by the CA
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=127.0.0.1"
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt
```

Use `ca.crt` as the `ca` on the client side. A self-signed certificate is not
in the system trust store, so a client without `ca` refuses it; pass
`verify=False` only for throwaway local testing.
