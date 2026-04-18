"""
TLS client — verifies the server certificate against the local CA bundle.

The CA bundle (certs/ca.crt) was used to sign the server's certificate, so
the handshake succeeds and the connection is both encrypted and authenticated.

Run after service.py is started:
    python client_verified.py
"""
import pathlib
from daffi import Client

HERE = pathlib.Path(__file__).parent


if __name__ == "__main__":
    client = Client(
        app_name="tls-client-verified",
        host="127.0.0.1",
        port=5005,
        tls=True,
        # Supply the CA that signed the server certificate so the client can
        # verify the server's identity during the TLS handshake.
        ca_file=str(HERE / "certs" / "ca.crt"),
    )
    conn = client.connect()
    c = conn.rpc(timeout=5)

    result = c.add(10, 20)
    print(f"add(10, 20)      = {result}")

    result = c.multiply(6, 7)
    print(f"multiply(6, 7)   = {result}")

    result = c.greet("World")
    print(f"greet('World')   = {result!r}")

    client.stop()
    print("Done (verified TLS).")
