"""
service/08_unix_socket — Service side.

Unix domain sockets are faster than TCP for same-machine communication
because they bypass the network stack entirely.  Pass unix_sock_path
instead of host/port.

Linux / macOS only.

Run first, then run 2_client.py.
"""
from daffi import Service, callback

SOCK = "/tmp/daffi_example.sock"


@callback
def ping(msg: str) -> str:
    print(f"[service] ping({msg!r})")
    return f"pong: {msg}"


if __name__ == "__main__":
    svc = Service(app_name="unix-service", unix_sock_path=SOCK)
    svc.start()
    print(f"Service listening on unix://{SOCK} — press Ctrl+C to stop.")
    svc.join()
