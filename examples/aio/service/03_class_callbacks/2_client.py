"""
aio/service/03_class_callbacks — Client side (async).

Calls the three public async methods of the remote TextProcessor class.
asyncio.gather() pipelines all three calls per sentence concurrently.

Run 1_service.py first.
"""
import asyncio
from daffi.aio import AsyncClient

SENTENCES = [
    "the quick brown fox",
    "jumps over the lazy dog",
    "daffi makes remote calls simple",
]


async def main():
    client = AsyncClient(app_name="text-client", host="0.0.0.0", port=5003)
    conn = await client.connect()

    rpc = conn.rpc(timeout=5)

    for sentence in SENTENCES:
        upper, reverse, count = await asyncio.gather(
            rpc.upper(sentence),
            rpc.reverse(sentence),
            rpc.word_count(sentence),
        )
        print(f"\noriginal   : {sentence!r}")
        print(f"upper      : {upper!r}")
        print(f"reverse    : {reverse!r}")
        print(f"word_count : {count}")

    await client.stop()
    print("\nDone.")


if __name__ == "__main__":
    asyncio.run(main())
