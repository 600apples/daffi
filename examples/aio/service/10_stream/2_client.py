"""
aio/service/10_stream — Client side (async).

Demonstrates two async streaming modes:

  await conn.stream()         — awaits service ack before sending next chunk.
                                Natural backpressure; producer never outruns
                                the consumer.

  await conn.stream_nowait()  — fire-and-forget per chunk; no ack awaited.
                                All chunks dispatched immediately.

The data source is an async generator, composing naturally with asyncio I/O.

Run 1_service.py first.
"""
import asyncio
from daffi.aio import AsyncClient

CHUNKS = [
    b"The quick brown fox",
    b"jumps over the lazy dog.",
    b"Pack my box with five",
    b"dozen liquor jugs.",
    b"How vexingly quick",
    b"daft zebras jump!",
]


async def data_source():
    """Async generator — simulates reading from a file or network stream."""
    for chunk in CHUNKS:
        print(f"[client] -> {chunk!r}")
        await asyncio.sleep(0)
        yield chunk


async def main():
    client = AsyncClient(app_name="stream-client", host="0.0.0.0", port=5010)
    conn = await client.connect()

    print("\n── stream() — backpressure ──")
    await conn.stream().receive_chunk(data_source())
    print("[client] all chunks acknowledged.\n")

    await asyncio.sleep(1)

    print("── stream_nowait() — fire-and-forget ──")
    await conn.stream_nowait().receive_chunk(data_source())
    print("[client] all chunks dispatched (no ack waited).")

    await client.stop()


if __name__ == "__main__":
    asyncio.run(main())
