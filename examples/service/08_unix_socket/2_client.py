"""
service/08_unix_socket — Client side.

Connects to the service via a Unix domain socket.  The same API is used
as for TCP — only the connection parameter changes.

Linux / macOS only.

Run 1_service.py first.
"""
from daffi import Client

SOCK = "/tmp/daffi_example.sock"


if __name__ == "__main__":
    client = Client(app_name="unix-client", unix_sock_path=SOCK)
    conn = client.connect()

    rpc = conn.rpc(timeout=5)

    for msg in ["hello", "world", "unix sockets are fast"]:
        result = rpc.ping(msg)
        print(f"ping({msg!r}) → {result!r}")

    client.stop()
    print("Done.")
