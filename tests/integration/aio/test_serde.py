"""
Async integration tests for all four wire serialisation formats.

Mirrors tests/integration/test_serde.py using daffi.aio.
All RPC calls use ``await conn.rpc()``.
"""
from __future__ import annotations

import json
import math
import pytest

from .conftest import HOST, TIMEOUT


def _msgpack_available() -> bool:
    try:
        import msgpack  # noqa: F401
        return True
    except ImportError:
        return False


skip_no_msgpack = pytest.mark.skipif(
    not _msgpack_available(),
    reason="msgpack not installed — run: pip install 'daffi[msgpack]'",
)


async def _rpc(port: int, name: str, method: str, *args, serde, **kwargs):
    from daffi.aio import AsyncClient
    client = AsyncClient(app_name=name, host=HOST, port=port)
    conn = await client.connect()
    try:
        proxy = conn.rpc(timeout=TIMEOUT, serde=serde)
        return await getattr(proxy, method)(*args, **kwargs)
    finally:
        await client.stop()


# ══════════════════════════════════════════════════════════════════════════════
# PICKLE
# ══════════════════════════════════════════════════════════════════════════════

@pytest.mark.asyncio
class TestPickleAsync:

    async def _echo(self, port, name, payload):
        from daffi import SerdeFormat
        return await _rpc(port, name, "echo", payload, serde=SerdeFormat.PICKLE)

    async def test_string(self, direct_service):
        assert await self._echo(direct_service, "pk-str", "hello pickle") == "hello pickle"

    async def test_bytes(self, direct_service):
        payload = b"\x00\x01\x02\xff"
        assert await self._echo(direct_service, "pk-bytes", payload) == payload

    async def test_bytearray(self, direct_service):
        payload = bytearray(b"daffi")
        assert await self._echo(direct_service, "pk-ba", payload) == payload

    async def test_tuple(self, direct_service):
        payload = (1, "two", 3.0)
        result = await self._echo(direct_service, "pk-tup", payload)
        assert result == payload
        assert isinstance(result, tuple)

    async def test_nested_tuple(self, direct_service):
        payload = ((1, 2), (3, 4))
        result = await self._echo(direct_service, "pk-ntup", payload)
        assert result == payload
        assert all(isinstance(r, tuple) for r in result)

    async def test_set(self, direct_service):
        payload = {1, 2, 3, "four"}
        result = await self._echo(direct_service, "pk-set", payload)
        assert result == payload
        assert isinstance(result, (set, frozenset))

    async def test_none(self, direct_service):
        assert await self._echo(direct_service, "pk-none", None) is None

    async def test_bool(self, direct_service):
        assert await self._echo(direct_service, "pk-true", True) is True
        assert await self._echo(direct_service, "pk-false", False) is False

    async def test_int(self, direct_service):
        assert await self._echo(direct_service, "pk-int", 10**18) == 10**18

    async def test_float_special(self, direct_service):
        assert math.isnan(await self._echo(direct_service, "pk-nan", float("nan")))
        assert math.isinf(await self._echo(direct_service, "pk-inf", float("inf")))

    async def test_nested_dict(self, direct_service):
        payload = {"a": {"b": {"c": [1, 2, 3]}}, "t": (4, 5)}
        result = await self._echo(direct_service, "pk-nest", payload)
        assert result == payload

    async def test_large_bytes(self, direct_service):
        payload = bytes(range(256)) * 1024
        assert await self._echo(direct_service, "pk-lbytes", payload) == payload

    async def test_multi_arg_kwargs(self, direct_service):
        from daffi.aio import AsyncClient
        from daffi import SerdeFormat
        client = AsyncClient(app_name="pk-multi", host=HOST, port=direct_service)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.PICKLE)
        result = await proxy.add(100, 200)
        await client.stop()
        assert result == 300


# ══════════════════════════════════════════════════════════════════════════════
# JSON
# ══════════════════════════════════════════════════════════════════════════════

@pytest.mark.asyncio
class TestJsonAsync:

    async def _echo(self, port, name, payload):
        from daffi import SerdeFormat
        return await _rpc(port, name, "echo", payload, serde=SerdeFormat.JSON)

    async def test_string(self, direct_service):
        assert await self._echo(direct_service, "js-str", "hello json") == "hello json"

    async def test_empty_string(self, direct_service):
        assert await self._echo(direct_service, "js-empty", "") == ""

    async def test_int(self, direct_service):
        assert await self._echo(direct_service, "js-int", 12345) == 12345

    async def test_float(self, direct_service):
        result = await self._echo(direct_service, "js-float", 3.14)
        assert abs(result - 3.14) < 1e-9

    async def test_bool(self, direct_service):
        assert await self._echo(direct_service, "js-bool-t", True) is True
        assert await self._echo(direct_service, "js-bool-f", False) is False

    async def test_none(self, direct_service):
        assert await self._echo(direct_service, "js-none", None) is None

    async def test_list(self, direct_service):
        payload = [1, "two", 3.0, None, True]
        assert await self._echo(direct_service, "js-list", payload) == payload

    async def test_dict_string_keys(self, direct_service):
        payload = {"alpha": 1, "beta": [2, 3], "gamma": {"nested": True}}
        assert await self._echo(direct_service, "js-dict", payload) == payload

    async def test_tuple_becomes_list(self, direct_service):
        payload = (1, 2, 3)
        result = await self._echo(direct_service, "js-tup", payload)
        assert result == list(payload)
        assert isinstance(result, list)

    async def test_nested_tuple_becomes_nested_list(self, direct_service):
        payload = ((1, 2), (3, 4))
        result = await self._echo(direct_service, "js-ntup", payload)
        assert result == [[1, 2], [3, 4]]

    async def test_large_list(self, direct_service):
        payload = list(range(10_000))
        assert await self._echo(direct_service, "js-large", payload) == payload

    async def test_multi_arg(self, direct_service):
        from daffi.aio import AsyncClient
        from daffi import SerdeFormat
        client = AsyncClient(app_name="js-multi", host=HOST, port=direct_service)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.JSON)
        result = await proxy.add(7, 8)
        await client.stop()
        assert result == 15

    async def test_kwargs(self, direct_service):
        from daffi.aio import AsyncClient
        from daffi import SerdeFormat
        client = AsyncClient(app_name="js-kwargs", host=HOST, port=direct_service)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.JSON)
        result = await proxy.add(a=3, b=4)
        await client.stop()
        assert result == 7


# ══════════════════════════════════════════════════════════════════════════════
# OPAQUE
# ══════════════════════════════════════════════════════════════════════════════

@pytest.mark.asyncio
class TestOpaqueAsync:

    async def _rpc_opaque(self, port, name, payload):
        from daffi import SerdeFormat
        return await _rpc(port, name, "echo", payload, serde=SerdeFormat.OPAQUE)

    async def test_str_passthrough(self, direct_service):
        wire = '{"hello": "opaque"}'
        assert await self._rpc_opaque(direct_service, "op-str", wire) == wire

    async def test_str_empty(self, direct_service):
        assert await self._rpc_opaque(direct_service, "op-empty-str", "") == ""

    async def test_str_json_roundtrip(self, direct_service):
        payload = {"key": "value", "numbers": [1, 2, 3]}
        wire = json.dumps(payload)
        result = await self._rpc_opaque(direct_service, "op-json-str", wire)
        assert result == wire
        assert json.loads(result) == payload

    async def test_str_unicode(self, direct_service):
        wire = "日本語テスト 🐍"
        assert await self._rpc_opaque(direct_service, "op-unicode", wire) == wire

    async def test_str_large(self, direct_service):
        wire = "x" * (64 * 1024)
        assert await self._rpc_opaque(direct_service, "op-large-str", wire) == wire

    async def test_bytes_passthrough(self, direct_service):
        wire = b"\x00\x01\x02\x03\xff"
        assert await self._rpc_opaque(direct_service, "op-bytes", wire) == wire

    async def test_bytes_empty(self, direct_service):
        assert await self._rpc_opaque(direct_service, "op-empty-bytes", b"") == b""

    async def test_bytes_large(self, direct_service):
        wire = bytes(range(256)) * 256
        assert await self._rpc_opaque(direct_service, "op-large-bytes", wire) == wire

    async def test_bytes_preserves_type(self, direct_service):
        wire = b"binary payload"
        result = await self._rpc_opaque(direct_service, "op-bytes-type", wire)
        assert isinstance(result, bytes)

    async def test_str_preserves_type(self, direct_service):
        wire = "string payload"
        result = await self._rpc_opaque(direct_service, "op-str-type", wire)
        assert isinstance(result, str)

    async def test_multiple_args_raises(self, direct_service):
        from daffi.aio import AsyncClient
        from daffi import SerdeFormat
        client = AsyncClient(app_name="op-multi-err", host=HOST, port=direct_service)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.OPAQUE)
        try:
            with pytest.raises(TypeError):
                await proxy.echo("one", "two")
        finally:
            await client.stop()

    async def test_keyword_arg_also_works(self, direct_service):
        from daffi.aio import AsyncClient
        from daffi import SerdeFormat
        client = AsyncClient(app_name="op-kwarg", host=HOST, port=direct_service)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.OPAQUE)
        wire = '{"via": "kwarg"}'
        result = await proxy.echo(payload=wire)
        await client.stop()
        assert result == wire


# ══════════════════════════════════════════════════════════════════════════════
# MSGPACK
# ══════════════════════════════════════════════════════════════════════════════

@skip_no_msgpack
@pytest.mark.asyncio
class TestMsgpackAsync:

    async def _echo(self, port, name, payload):
        from daffi import SerdeFormat
        return await _rpc(port, name, "echo", payload, serde=SerdeFormat.MSGPACK)

    async def test_string(self, direct_service):
        assert await self._echo(direct_service, "mp-str", "hello msgpack") == "hello msgpack"

    async def test_int(self, direct_service):
        assert await self._echo(direct_service, "mp-int", 999) == 999

    async def test_float(self, direct_service):
        result = await self._echo(direct_service, "mp-float", 2.718)
        assert abs(result - 2.718) < 1e-9

    async def test_none(self, direct_service):
        assert await self._echo(direct_service, "mp-none", None) is None

    async def test_bool(self, direct_service):
        assert await self._echo(direct_service, "mp-bool-t", True) is True
        assert await self._echo(direct_service, "mp-bool-f", False) is False

    async def test_list(self, direct_service):
        payload = [1, "two", 3.0]
        assert await self._echo(direct_service, "mp-list", payload) == payload

    async def test_dict_string_keys(self, direct_service):
        payload = {"alpha": 1, "beta": [2, 3]}
        assert await self._echo(direct_service, "mp-dict", payload) == payload

    async def test_bytes_preserved(self, direct_service):
        payload = b"\x00\xde\xad\xbe\xef"
        result = await self._echo(direct_service, "mp-bytes", payload)
        assert result == payload
        assert isinstance(result, bytes)

    async def test_tuple_becomes_list(self, direct_service):
        payload = (10, 20, 30)
        result = await self._echo(direct_service, "mp-tup", payload)
        assert result == list(payload)
        assert isinstance(result, list)

    async def test_nested_tuple_becomes_list(self, direct_service):
        payload = ((1, 2), (3, 4))
        result = await self._echo(direct_service, "mp-ntup", payload)
        assert result == [[1, 2], [3, 4]]

    async def test_integer_dict_keys(self, direct_service):
        payload = {1: "one", 2: "two"}
        result = await self._echo(direct_service, "mp-intkeys", payload)
        assert result == payload

    async def test_nested_bytes_in_dict(self, direct_service):
        payload = {"data": b"\xff\xfe", "name": "test"}
        result = await self._echo(direct_service, "mp-nested-bytes", payload)
        assert result == payload
        assert isinstance(result["data"], bytes)

    async def test_large_payload(self, direct_service):
        payload = list(range(10_000))
        assert await self._echo(direct_service, "mp-large", payload) == payload

    async def test_multi_arg(self, direct_service):
        from daffi.aio import AsyncClient
        from daffi import SerdeFormat
        client = AsyncClient(app_name="mp-multi", host=HOST, port=direct_service)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.MSGPACK)
        result = await proxy.add(21, 21)
        await client.stop()
        assert result == 42

    async def test_via_router(self, router_with_worker):
        from daffi.aio import AsyncClient
        from daffi import SerdeFormat
        client = AsyncClient(app_name="mp-router", host=HOST, port=router_with_worker)
        conn = await client.connect()
        proxy = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.MSGPACK)
        payload = {"via": "async-router", "data": b"\xca\xfe"}
        result = await proxy.echo(payload)
        await client.stop()
        assert result == payload
        assert isinstance(result["data"], bytes)


# ══════════════════════════════════════════════════════════════════════════════
# Cross-format comparison
# ══════════════════════════════════════════════════════════════════════════════

@pytest.mark.asyncio
class TestCrossFormatAsync:

    JSON_SAFE_PAYLOAD = {"x": 1, "y": [2, 3, 4], "flag": True, "nothing": None}

    @pytest.mark.parametrize("serde_name", ["PICKLE", "JSON"])
    async def test_json_safe_payload(self, direct_service, serde_name):
        from daffi import SerdeFormat
        serde = getattr(SerdeFormat, serde_name)
        result = await _rpc(
            direct_service, f"cross-{serde_name.lower()}", "echo",
            self.JSON_SAFE_PAYLOAD, serde=serde,
        )
        assert result == self.JSON_SAFE_PAYLOAD

    @skip_no_msgpack
    async def test_json_safe_payload_msgpack(self, direct_service):
        from daffi import SerdeFormat
        result = await _rpc(
            direct_service, "cross-msgpack", "echo",
            self.JSON_SAFE_PAYLOAD, serde=SerdeFormat.MSGPACK,
        )
        assert result == self.JSON_SAFE_PAYLOAD

    async def test_opaque_str_is_independent_of_other_formats(self, direct_service):
        from daffi import SerdeFormat
        payload = self.JSON_SAFE_PAYLOAD
        wire = json.dumps(payload)
        opaque_result = await _rpc(
            direct_service, "cross-opaque", "echo", wire, serde=SerdeFormat.OPAQUE,
        )
        assert opaque_result == wire
        assert json.loads(opaque_result) == payload

    async def test_pickle_preserves_what_json_loses(self, direct_service):
        from daffi import SerdeFormat
        for payload, description in [
            (b"raw bytes", "bytes"),
            ((1, 2, 3), "tuple"),
            ({1, 2, 3}, "set"),
        ]:
            result = await _rpc(
                direct_service, f"cross-pk-{description}", "echo",
                payload, serde=SerdeFormat.PICKLE,
            )
            assert result == payload, f"{description} not preserved by PICKLE"
