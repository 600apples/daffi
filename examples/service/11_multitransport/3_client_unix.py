"""
service/11_multitransport — Unix client.

Same service as 2_client_tcp.py, reached through the Unix socket.

Run 1_service.py first.  Linux / macOS only.
"""

from daffi import Client, UnixTransport

SOCK = "/tmp/daffi_service.sock"


if __name__ == "__main__":
    client = Client(app_name="unix-client", transport=UnixTransport(SOCK))
    conn = client.connect()

    result = conn.rpc(timeout=5).add(10, 20)
    print(f"add(10, 20) over unix socket = {result}")

    client.stop()
    print("Done.")
