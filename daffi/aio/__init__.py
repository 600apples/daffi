"""
``daffi.aio`` — asyncio interface for daffi.

Import async node classes from here::

    from daffi.aio import Client, Service, Router

All classes share the same constructor signature as their sync counterparts
in :mod:`daffi`.  The difference is that lifecycle methods (``connect``,
``join``, ``stop``) and all RPC call styles are coroutines::

    async def main():
        client = Client(app_name="caller", host="127.0.0.1", port=6000)
        conn = await client.connect()

        result = await conn.rpc(timeout=5).multiply(6, 7)
        results = await conn.cast().multiply(6, 7)  # {worker: result}

        await client.join()

The Zig native layer is **unchanged** — it still communicates via OS
file-descriptors that asyncio monitors with ``loop.add_reader()``.
"""

from daffi.aio.app import (
    AsyncClient,
    AsyncService,
    AsyncRouter,
)

__all__ = ["AsyncClient", "AsyncService", "AsyncRouter"]
