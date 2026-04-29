"""
service/10_stream — Service side.

Demonstrates receiving a stream of binary chunks from a client.
Each chunk arrives as a separate callback invocation.

Run first, then run 2_client.py.
"""
from daffi import Service, callback

_chunks: list[bytes] = []


@callback
def receive_chunk(data: bytes) -> None:
    _chunks.append(data)
    total = sum(len(c) for c in _chunks)
    print(f"[service] chunk {len(_chunks):>3}: {len(data)} bytes  {data!r}  (total so far: {total} bytes)")


if __name__ == "__main__":
    svc = Service(app_name="stream-service", host="0.0.0.0", port=5010)
    svc.start()
    print("Service running on 0.0.0.0:5010 — press Ctrl+C to stop.")
    svc.join()
