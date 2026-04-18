"""
TLS client — encrypted connection WITHOUT certificate verification.

Passing tls=True with no ca_file encrypts the traffic but skips verification
of the server certificate.  This is equivalent to curl's --insecure flag: the
data is encrypted in transit but the client cannot confirm it is talking to the
correct server (vulnerable to man-in-the-middle attacks in untrusted networks).

Use verified connections (client_verified.py) in production.

Run after service.py is started:
    python client_no_verify.py
"""
from daffi import Client


if __name__ == "__main__":
    client = Client(
        app_name="tls-client-no-verify",
        host="127.0.0.1",
        port=5005,
        tls=True,
        # ca_file is intentionally omitted — disables peer verification.
    )
    conn = client.connect()
    c = conn.rpc(timeout=5)

    result = c.add(3, 4)
    print(f"add(3, 4)        = {result}")

    result = c.greet("TLS")
    print(f"greet('TLS')     = {result!r}")

    client.stop()
    print("Done (unverified TLS — encrypted but not authenticated).")
