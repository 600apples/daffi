# TLS

daffi supports TLS encryption for TCP connections. Enable it to protect traffic between nodes on untrusted networks.

---

## Server (Service / Router)

Provide a PEM certificate and private key:

```python
from daffi import Service, callback

@callback
def secret(data: str) -> str:
    return f"secure: {data}"

svc = Service(
    app_name="tls-service",
    host="0.0.0.0",
    port=5443,
    tls=True,
    cert_file="/path/to/server.crt",
    key_file="/path/to/server.key",
)
svc.start()
svc.join()
```

Same parameters apply to `Router`.

---

## Client

```python
from daffi import Client

client = Client(
    app_name="tls-client",
    host="127.0.0.1",
    port=5443,
    tls=True,
    # Optional: provide a CA bundle to verify the server certificate.
    # Leave empty to connect without verifying the server cert (not recommended).
    ca_file="/path/to/ca.crt",
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
| `tls=True` | Both | Enable TLS for the connection. |
| `cert_file` | Server | Path to PEM server certificate. |
| `key_file` | Server | Path to PEM server private key. |
| `ca_file` | Client | Path to PEM CA bundle for server certificate verification. Empty = skip verification. |

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

Use `ca.crt` as the `ca_file` on the client side.
