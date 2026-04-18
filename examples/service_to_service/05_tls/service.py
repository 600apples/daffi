"""
TLS-secured service process.

The service binds with a TLS certificate so all traffic between itself and
any client is encrypted in transit.  Clients that want to verify the server's
identity must pass ca_file="certs/ca.crt" when connecting.

Start this process first:
    python service.py

Then run either of the two clients:
    python client_verified.py    # verifies the server certificate
    python client_no_verify.py   # skips verification (still encrypted)
"""
import pathlib
from daffi import Service, callback

HERE = pathlib.Path(__file__).parent


@callback
def add(a: int, b: int) -> int:
    print(f"[service] add({a}, {b})")
    return a + b


@callback
def multiply(a: int, b: int) -> int:
    print(f"[service] multiply({a}, {b})")
    return a * b


@callback
def greet(name: str) -> str:
    print(f"[service] greet({name!r})")
    return f"Hello (over TLS), {name}!"


if __name__ == "__main__":
    svc = Service(
        app_name="tls-service",
        host="127.0.0.1",
        port=5005,
        tls=True,
        cert_file=str(HERE / "certs" / "server.crt"),
        key_file=str(HERE / "certs" / "server.key"),
    )
    svc.start()
    print("TLS service running on 127.0.0.1:5005 – press Ctrl+C to stop.")
    svc.join()
