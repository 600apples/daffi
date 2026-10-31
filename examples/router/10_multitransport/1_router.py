"""
router/10_multitransport — Router.

One Router listens on TCP and a Unix socket at the same time.  Both
listeners belong to the same node, so a worker that connects over TCP can
be called by a client that connects over the Unix socket.

Start first, then run 2_worker.py, then 3_caller.py.

Linux / macOS only (the Unix listener).
"""

from daffi import Router, TCPTransport, UnixTransport

PORT = 6010
SOCK = "/tmp/daffi_router.sock"


if __name__ == "__main__":
    router = Router(
        transport=[
            TCPTransport("127.0.0.1", PORT),
            UnixTransport(SOCK),
        ]
    )
    router.start()
    print(f"Router listening on tcp://127.0.0.1:{PORT} and unix://{SOCK}")
    print("Press Ctrl+C to stop.")
    router.join()
