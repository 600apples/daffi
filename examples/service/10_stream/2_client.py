"""
service/10_stream — Client side.

Demonstrates two streaming modes:

  conn.stream()         — blocking per chunk; waits for service ack before
                          sending the next chunk.  Natural backpressure.

  conn.stream_nowait()  — fire-and-forget per chunk; no ack waited for.
                          Producer can outpace consumer.

Run 1_service.py first.
"""
import time
from daffi import Client

CHUNKS = [
    b"The quick brown fox",
    b"jumps over the lazy dog.",
    b"Pack my box with five",
    b"dozen liquor jugs.",
    b"How vexingly quick",
    b"daft zebras jump!",
]


def data_source():
    for chunk in CHUNKS:
        print(f"[client] -> {chunk!r}")
        yield chunk

if __name__ == "__main__":
    client = Client(app_name="stream-client", host="0.0.0.0", port=5010)
    conn = client.connect()

    print("\n── stream() — blocking, backpressure ──")
    conn.stream().receive_chunk(data_source())
    print("[client] all chunks acknowledged.\n")

    time.sleep(1)

    print("── stream_nowait() — fire-and-forget ──")
    conn.stream_nowait().receive_chunk(data_source())
    print("[client] all chunks dispatched (no ack waited).")

    client.stop()
