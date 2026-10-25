"""
service/11_multitransport — Service.

One Service listens on TCP and a Unix socket.  Clients on either transport
call the same callbacks.

Start first, then run 2_client_tcp.py and 3_client_unix.py.

Linux / macOS only (the Unix listener).
"""

from daffi import Service, TCPTransport, UnixTransport, callback

PORT = 5011
SOCK = "/tmp/daffi_service.sock"


@callback
def add(a: int, b: int) -> int:
    print(f"[service] add({a}, {b})")
    return a + b


if __name__ == "__main__":
    svc = Service(
        app_name="calc-service",
        transports=[
            TCPTransport("127.0.0.1", PORT),
            UnixTransport(SOCK),
        ],
    )
    svc.start()
    print(f"Service listening on tcp://127.0.0.1:{PORT} and unix://{SOCK}")
    print("Press Ctrl+C to stop.")
    svc.join()
