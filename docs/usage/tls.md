# Security

Daffi supports TLS encryption for TCP connections.

TLS allows clients to verify the server's identity and protects communication against network interception.

`cert`, `key`, and `ca` accept either a **filesystem path** or the **PEM material** itself. The native layer treats a value that starts with `-----BEGIN ` as PEM and loads it from memory; anything else is a path.

---

## TLS configuration

Configure TLS on the server-side transport:

```python
from daffi import Router, TCPTransport

router = Router(
    transport=TCPTransport(
        "127.0.0.1",
        6000,
        tls=True,
        cert="/path/to/server.crt",
        key="/path/to/server.key",
    ),
)

router.start()
```

Configure the Client with the trusted CA certificate:

```python
from daffi import Client, TCPTransport

client = Client(
    transport=TCPTransport(
        "127.0.0.1",
        6000,
        tls=True,
        ca="/path/to/ca.crt",
    ),
)

conn = client.connect()
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

Different listeners may use different TLS settings — for example TLS on TCP and plaintext on a Unix socket. See [Transports](transports.md).

---

## Certificate configuration

| Parameter | Role | Description |
|---|---|---|
| `tls=True` | Both | Enable TLS on this transport. |
| `cert` | Server / client | Path or PEM for the local certificate (server identity, or client identity for mTLS). |
| `key` | Server / client | Path or PEM for the local private key. |
| `ca` | Server / client | Path or PEM for the peer trust store. On a **listener**, non-empty `ca` enables **mutual TLS**. On a **client**, the trust store used to verify the server. Empty on the client = the system trust store. |
| `verify` | Client | `True` (default) verifies the server. `False` accepts any certificate: traffic is encrypted, but anyone on the path can impersonate the server. |

These options live on `TCPTransport` / `UnixTransport`, not on `Router` / `Service` / `Client`.

**Security recommendation:** Configure certificate verification in production. Disabling server certificate verification exposes connections to man-in-the-middle attacks.

---

## Mutual TLS

Set `ca` on the listening transport and give the client matching `cert` / `key` (and usually the same `ca` to verify the server):

```python
# Server — require client certificates
Service(
    transport=TCPTransport(
        "0.0.0.0", 5443,
        tls=True,
        cert=server_cert, key=server_key,
        ca=client_ca,
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

A self-signed setup can use one certificate as server identity, client identity, and CA on both sides.

---

## Generating self-signed certificates (development)

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

Use `ca.crt` as the `ca` on the client side. A self-signed certificate is not in the system trust store, so a client without `ca` refuses it; pass `verify=False` only for throwaway local testing.

---

## Related security controls

- **`auth_token=`** — shared secret checked during the handshake. On TCP, using `auth_token` requires `tls=True`.
- **`serdes=SerdeFormat.SAFE`** — refuse pickle deserialization on the receiver. See [Serialization](serialization.md).
