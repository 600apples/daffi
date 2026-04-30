"""
Async integration tests for RPC calls (await conn.rpc()).

Mirrors tests/integration/test_rpc.py using daffi.aio.

Layouts
-------
Direct  — AsyncClient → AsyncService         (one hop)
Router  — AsyncClient → AsyncRouter → AsyncWorker  (two hops)
"""
from __future__ import annotations

import json

import pytest

from .conftest import HOST, TIMEOUT


def _msgpack_available() -> bool:
    try:
        import msgpack  # noqa: F401
        return True
    except ImportError:
        return False


# ── async helper ──────────────────────────────────────────────────────────────

async def _rpc(port: int, name: str, *args, serde=None, **kwargs):
    """Connect a fresh AsyncClient, fire one RPC call, stop, return result."""
    from daffi.aio import AsyncClient
    from daffi import SerdeFormat

    serde = serde if serde is not None else SerdeFormat.PICKLE
    client = AsyncClient(app_name=name, host=HOST, port=port)
    conn = await client.connect()
    try:
        proxy = conn.rpc(timeout=TIMEOUT, serde=serde)
        method = getattr(proxy, kwargs.pop("_method", "echo"))
        return await method(*args, **kwargs)
    finally:
        await client.stop()


# ── Direct layout ──────────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestDirectRpcAsync:
    """AsyncClient → AsyncService RPC tests."""

    async def test_echo_string(self, direct_service):
        result = await _rpc(direct_service, "t-echo-str", "hello daffi")
        assert result == "hello daffi"

    async def test_echo_empty_string(self, direct_service):
        result = await _rpc(direct_service, "t-echo-empty", "")
        assert result == ""

    async def test_echo_int(self, direct_service):
        result = await _rpc(direct_service, "t-echo-int", 42)
        assert result == 42

    async def test_echo_float(self, direct_service):
        result = await _rpc(direct_service, "t-echo-float", 3.14159)
        assert abs(result - 3.14159) < 1e-9

    async def test_echo_none(self, direct_service):
        result = await _rpc(direct_service, "t-echo-none", None)
        assert result is None

    async def test_echo_list(self, direct_service):
        payload = [1, "two", 3.0, None, True]
        result = await _rpc(direct_service, "t-echo-list", payload)
        assert result == payload

    async def test_echo_large_list(self, direct_service):
        payload = list(range(50_000))
        result = await _rpc(direct_service, "t-echo-llist", payload)
        assert result == payload

    async def test_echo_dict(self, direct_service):
        payload = {"key": "value", "nested": {"a": 1, "b": [1, 2, 3]}}
        result = await _rpc(direct_service, "t-echo-dict", payload)
        assert result == payload

    async def test_echo_tuple_becomes_list(self, direct_service):
        payload = (1, 2, 3)
        result = await _rpc(direct_service, "t-echo-tuple", payload)
        assert list(result) == list(payload)

    async def test_add_positive(self, direct_service):
        result = await _rpc(direct_service, "t-add-pos", 3, 7, _method="add")
        assert result == 10

    async def test_add_negative(self, direct_service):
        result = await _rpc(direct_service, "t-add-neg", -5, 3, _method="add")
        assert result == -2

    async def test_add_large(self, direct_service):
        result = await _rpc(direct_service, "t-add-large", 10**9, 10**9, _method="add")
        assert result == 2 * 10**9

    @pytest.mark.parametrize("serde_name", ["PICKLE", "JSON"])
    async def test_echo_serde(self, direct_service, serde_name):
        from daffi import SerdeFormat

        serde = getattr(SerdeFormat, serde_name)
        payload = {"serde": serde_name, "data": [1, 2, 3], "flag": True}
        result = await _rpc(direct_service, f"t-serde-{serde_name.lower()}", payload, serde=serde)
        assert result == payload

    @pytest.mark.skipif(not _msgpack_available(), reason="msgpack not installed")
    async def test_echo_serde_msgpack(self, direct_service):
        from daffi import SerdeFormat

        payload = {"serde": "MSGPACK", "data": [1, 2, 3], "flag": True}
        result = await _rpc(direct_service, "t-serde-msgpack", payload, serde=SerdeFormat.MSGPACK)
        assert result == payload

    async def test_echo_serde_opaque(self, direct_service):
        from daffi import SerdeFormat

        payload = {"mode": "opaque", "values": [10, 20, 30]}
        wire = json.dumps(payload)
        result = await _rpc(direct_service, "t-serde-opaque", wire, serde=SerdeFormat.OPAQUE)
        assert result == wire

    async def test_repeated_calls_same_client(self, direct_service):
        """A single AsyncClient/connection can fire many sequential awaited calls."""
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="t-repeated", host=HOST, port=direct_service)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)
        try:
            for i in range(100):
                assert await proxy.echo(i) == i
        finally:
            await client.stop()


# ── Router layout ──────────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestRouterRpcAsync:
    """AsyncClient → AsyncRouter → AsyncWorker RPC tests."""

    async def test_echo_string(self, router_with_worker):
        result = await _rpc(router_with_worker, "r-echo-str", "routed hello")
        assert result == "routed hello"

    async def test_echo_dict(self, router_with_worker):
        payload = {"via": "async-router", "numbers": list(range(100))}
        result = await _rpc(router_with_worker, "r-echo-dict", payload)
        assert result == payload

    async def test_add(self, router_with_worker):
        result = await _rpc(router_with_worker, "r-add", 10, 32, _method="add")
        assert result == 42

    @pytest.mark.parametrize("serde_name", ["PICKLE", "JSON"])
    async def test_echo_serde(self, router_with_worker, serde_name):
        from daffi import SerdeFormat

        serde = getattr(SerdeFormat, serde_name)
        payload = {"serde": serde_name, "routed": True}
        result = await _rpc(router_with_worker, f"r-serde-{serde_name.lower()}", payload, serde=serde)
        assert result == payload

    @pytest.mark.skipif(not _msgpack_available(), reason="msgpack not installed")
    async def test_echo_serde_msgpack(self, router_with_worker):
        from daffi import SerdeFormat

        payload = {"serde": "MSGPACK", "routed": True, "data": [1, 2, 3]}
        result = await _rpc(router_with_worker, "r-serde-msgpack", payload, serde=SerdeFormat.MSGPACK)
        assert result == payload

    async def test_echo_serde_opaque(self, router_with_worker):
        from daffi import SerdeFormat

        payload = {"mode": "opaque", "routed": True}
        wire = json.dumps(payload)
        result = await _rpc(router_with_worker, "r-serde-opaque", wire, serde=SerdeFormat.OPAQUE)
        assert result == wire

    async def test_repeated_calls_same_client(self, router_with_worker):
        from daffi.aio import AsyncClient

        client = AsyncClient(app_name="r-repeated", host=HOST, port=router_with_worker)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)
        try:
            for i in range(100):
                assert await proxy.echo(i) == i
        finally:
            await client.stop()
