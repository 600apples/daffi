import os

from daffi import Router, TCPTransport
from daffi.exceptions import InitializationError

if __name__ == "__main__":
    raw_port = os.getenv("DAFFI_PORT")
    if not raw_port:
        raise InitializationError("'DAFFI_PORT' environment variable not found!")
    try:
        port = int(raw_port)
    except ValueError:
        raise InitializationError(
            f"'DAFFI_PORT' must be an integer, got {raw_port!r}"
        ) from None

    router = Router(
        app_name="daffi-controller",
        transport=TCPTransport("0.0.0.0", port),
    )
    router.start()
    print(f"Router running on 0.0.0.0:{port} — press Ctrl+C to stop.")
    router.join()
