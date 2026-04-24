"""
Integration tests for all four wire serialisation formats.

Format summary
--------------
OPAQUE  (0) — Zero-copy pass-through.  Caller must supply exactly one argument
              (``bytes`` or ``str``); it arrives at the callback unchanged.
              Raises TypeError when more than one argument is provided.

JSON    (1) — ``{"args": [...], "kwargs": {...}}`` envelope via json.dumps/loads.
              Tuples become lists.  No bytes, sets, or non-string dict keys.
              Int and float values survive (JSON preserves numeric types).

PICKLE  (2) — pickle.dumps((args, kwargs)).  Full Python type fidelity:
              tuples, bytes, sets, complex numbers, custom objects.

MSGPACK (3) — msgpack.packb([args, kwargs], use_bin_type=True).
              Tuples become lists.  Bytes survive (use_bin_type keeps them
              distinct from str).  No sets or custom objects.  Integer dict
              keys survive (strict_map_key=False).
              Requires the optional ``msgpack`` package.

Each test class uses the shared ``direct_service`` fixture from conftest.py
(Client → Service in a subprocess), so the round-trip is real network I/O,
not just a unit-test of the serializer module.
"""
from __future__ import annotations

import json
import math
import pytest

from conftest import HOST, TIMEOUT

# ── skip marker for MSGPACK ───────────────────────────────────────────────────

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


# ── shared helper ─────────────────────────────────────────────────────────────

def _rpc(port: int, name: str, method: str, *args, serde, **kwargs):
    """Connect a fresh Client, fire one call, return the result."""
    from daffi import Client
    client = Client(app_name=name, host=HOST, port=port)
    conn   = client.connect()
    try:
        proxy = conn.rpc(timeout=TIMEOUT, serde=serde)
        return getattr(proxy, method)(*args, **kwargs)
    finally:
        client.stop()


# ══════════════════════════════════════════════════════════════════════════════
# PICKLE
# ══════════════════════════════════════════════════════════════════════════════

class TestPickle:
    """PICKLE preserves every Python type exactly."""

    def _echo(self, port, name, payload):
        from daffi import SerdeFormat
        return _rpc(port, name, "echo", payload, serde=SerdeFormat.PICKLE)

    def test_string(self, direct_service):
        assert self._echo(direct_service, "pk-str", "hello pickle") == "hello pickle"

    def test_bytes(self, direct_service):
        payload = b"\x00\x01\x02\xff"
        assert self._echo(direct_service, "pk-bytes", payload) == payload

    def test_bytearray(self, direct_service):
        payload = bytearray(b"daffi")
        result  = self._echo(direct_service, "pk-ba", payload)
        assert result == payload

    def test_tuple(self, direct_service):
        """PICKLE is the only format that preserves tuples as tuples."""
        payload = (1, "two", 3.0)
        result  = self._echo(direct_service, "pk-tup", payload)
        assert result == payload
        assert isinstance(result, tuple)

    def test_nested_tuple(self, direct_service):
        payload = ((1, 2), (3, 4))
        result  = self._echo(direct_service, "pk-ntup", payload)
        assert result == payload
        assert all(isinstance(r, tuple) for r in result)

    def test_set(self, direct_service):
        """PICKLE preserves sets; JSON and MSGPACK cannot."""
        payload = {1, 2, 3, "four"}
        result  = self._echo(direct_service, "pk-set", payload)
        assert result == payload
        assert isinstance(result, (set, frozenset))

    def test_none(self, direct_service):
        assert self._echo(direct_service, "pk-none", None) is None

    def test_bool(self, direct_service):
        assert self._echo(direct_service, "pk-true", True) is True
        assert self._echo(direct_service, "pk-false", False) is False

    def test_int(self, direct_service):
        assert self._echo(direct_service, "pk-int", 10**18) == 10**18

    def test_float_special(self, direct_service):
        """PICKLE can transport NaN and ±Inf; JSON cannot."""
        assert math.isnan(self._echo(direct_service, "pk-nan", float("nan")))
        assert math.isinf(self._echo(direct_service, "pk-inf", float("inf")))

    def test_nested_dict(self, direct_service):
        payload = {"a": {"b": {"c": [1, 2, 3]}}, "t": (4, 5)}
        result  = self._echo(direct_service, "pk-nest", payload)
        assert result == payload

    def test_large_bytes(self, direct_service):
        payload = bytes(range(256)) * 1024   # 256 KiB
        assert self._echo(direct_service, "pk-lbytes", payload) == payload

    def test_multi_arg_kwargs(self, direct_service):
        """PICKLE handles multiple positional args and keyword args."""
        from daffi import Client, SerdeFormat
        client = Client(app_name="pk-multi", host=HOST, port=direct_service)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.PICKLE)
        result = proxy.add(100, 200)
        client.stop()
        assert result == 300


# ══════════════════════════════════════════════════════════════════════════════
# JSON
# ══════════════════════════════════════════════════════════════════════════════

class TestJson:
    """JSON supports the standard JSON type set; tuples become lists."""

    def _echo(self, port, name, payload):
        from daffi import SerdeFormat
        return _rpc(port, name, "echo", payload, serde=SerdeFormat.JSON)

    def test_string(self, direct_service):
        assert self._echo(direct_service, "js-str", "hello json") == "hello json"

    def test_empty_string(self, direct_service):
        assert self._echo(direct_service, "js-empty", "") == ""

    def test_int(self, direct_service):
        assert self._echo(direct_service, "js-int", 12345) == 12345

    def test_float(self, direct_service):
        result = self._echo(direct_service, "js-float", 3.14)
        assert abs(result - 3.14) < 1e-9

    def test_bool(self, direct_service):
        assert self._echo(direct_service, "js-bool-t", True) is True
        assert self._echo(direct_service, "js-bool-f", False) is False

    def test_none(self, direct_service):
        assert self._echo(direct_service, "js-none", None) is None

    def test_list(self, direct_service):
        payload = [1, "two", 3.0, None, True]
        assert self._echo(direct_service, "js-list", payload) == payload

    def test_dict_string_keys(self, direct_service):
        payload = {"alpha": 1, "beta": [2, 3], "gamma": {"nested": True}}
        assert self._echo(direct_service, "js-dict", payload) == payload

    def test_tuple_becomes_list(self, direct_service):
        """JSON has no tuple type — tuples are decoded as lists."""
        payload = (1, 2, 3)
        result  = self._echo(direct_service, "js-tup", payload)
        assert result == list(payload)
        assert isinstance(result, list)

    def test_nested_tuple_becomes_nested_list(self, direct_service):
        payload = ((1, 2), (3, 4))
        result  = self._echo(direct_service, "js-ntup", payload)
        assert result == [[1, 2], [3, 4]]

    def test_large_list(self, direct_service):
        payload = list(range(10_000))
        assert self._echo(direct_service, "js-large", payload) == payload

    def test_multi_arg(self, direct_service):
        from daffi import Client, SerdeFormat
        client = Client(app_name="js-multi", host=HOST, port=direct_service)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.JSON)
        result = proxy.add(7, 8)
        client.stop()
        assert result == 15

    def test_kwargs(self, direct_service):
        from daffi import Client, SerdeFormat
        client = Client(app_name="js-kwargs", host=HOST, port=direct_service)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.JSON)
        result = proxy.add(a=3, b=4)
        client.stop()
        assert result == 7


# ══════════════════════════════════════════════════════════════════════════════
# OPAQUE
# ══════════════════════════════════════════════════════════════════════════════

class TestOpaque:
    """OPAQUE zero-copy pass-through: exactly one str or bytes argument."""

    def _rpc_opaque(self, port, name, payload):
        from daffi import SerdeFormat
        return _rpc(port, name, "echo", payload, serde=SerdeFormat.OPAQUE)

    # ── str payloads ──────────────────────────────────────────────────────────

    def test_str_passthrough(self, direct_service):
        wire = '{"hello": "opaque"}'
        assert self._rpc_opaque(direct_service, "op-str", wire) == wire

    def test_str_empty(self, direct_service):
        assert self._rpc_opaque(direct_service, "op-empty-str", "") == ""

    def test_str_json_roundtrip(self, direct_service):
        """Pre-serialise a dict, pass as JSON string, get back the same string."""
        payload = {"key": "value", "numbers": [1, 2, 3]}
        wire    = json.dumps(payload)
        result  = self._rpc_opaque(direct_service, "op-json-str", wire)
        assert result == wire
        # Caller is responsible for deserialising on receipt.
        assert json.loads(result) == payload

    def test_str_unicode(self, direct_service):
        wire = "日本語テスト 🐍"
        assert self._rpc_opaque(direct_service, "op-unicode", wire) == wire

    def test_str_large(self, direct_service):
        wire = "x" * (64 * 1024)   # 64 KiB string
        assert self._rpc_opaque(direct_service, "op-large-str", wire) == wire

    # ── bytes payloads ────────────────────────────────────────────────────────

    def test_bytes_passthrough(self, direct_service):
        wire = b"\x00\x01\x02\x03\xff"
        assert self._rpc_opaque(direct_service, "op-bytes", wire) == wire

    def test_bytes_empty(self, direct_service):
        assert self._rpc_opaque(direct_service, "op-empty-bytes", b"") == b""

    def test_bytes_large(self, direct_service):
        wire = bytes(range(256)) * 256   # 64 KiB
        assert self._rpc_opaque(direct_service, "op-large-bytes", wire) == wire

    def test_bytes_preserves_type(self, direct_service):
        """bytes sent → bytes received; not silently promoted to str."""
        wire   = b"binary payload"
        result = self._rpc_opaque(direct_service, "op-bytes-type", wire)
        assert isinstance(result, bytes)

    def test_str_preserves_type(self, direct_service):
        """str sent → str received; not demoted to bytes."""
        wire   = "string payload"
        result = self._rpc_opaque(direct_service, "op-str-type", wire)
        assert isinstance(result, str)

    # ── error case ────────────────────────────────────────────────────────────

    def test_multiple_args_raises(self, direct_service):
        """OPAQUE must reject more than one argument."""
        from daffi import Client, SerdeFormat
        client = Client(app_name="op-multi-err", host=HOST, port=direct_service)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.OPAQUE)
        try:
            with pytest.raises(TypeError):
                proxy.echo("one", "two")   # two args → TypeError at serialise time
        finally:
            client.stop()

    def test_keyword_arg_also_works(self, direct_service):
        """A single keyword argument is allowed by OPAQUE."""
        from daffi import Client, SerdeFormat
        client = Client(app_name="op-kwarg", host=HOST, port=direct_service)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.OPAQUE)
        wire   = '{"via": "kwarg"}'
        result = proxy.echo(payload=wire)
        client.stop()
        assert result == wire


# ══════════════════════════════════════════════════════════════════════════════
# MSGPACK
# ══════════════════════════════════════════════════════════════════════════════

@skip_no_msgpack
class TestMsgpack:
    """MSGPACK: binary msgpack encoding; tuples→lists; bytes preserved."""

    def _echo(self, port, name, payload):
        from daffi import SerdeFormat
        return _rpc(port, name, "echo", payload, serde=SerdeFormat.MSGPACK)

    def test_string(self, direct_service):
        assert self._echo(direct_service, "mp-str", "hello msgpack") == "hello msgpack"

    def test_int(self, direct_service):
        assert self._echo(direct_service, "mp-int", 999) == 999

    def test_float(self, direct_service):
        result = self._echo(direct_service, "mp-float", 2.718)
        assert abs(result - 2.718) < 1e-9

    def test_none(self, direct_service):
        assert self._echo(direct_service, "mp-none", None) is None

    def test_bool(self, direct_service):
        assert self._echo(direct_service, "mp-bool-t", True) is True
        assert self._echo(direct_service, "mp-bool-f", False) is False

    def test_list(self, direct_service):
        payload = [1, "two", 3.0]
        assert self._echo(direct_service, "mp-list", payload) == payload

    def test_dict_string_keys(self, direct_service):
        payload = {"alpha": 1, "beta": [2, 3]}
        assert self._echo(direct_service, "mp-dict", payload) == payload

    def test_bytes_preserved(self, direct_service):
        """use_bin_type=True keeps bytes as bytes (not decoded as str)."""
        payload = b"\x00\xde\xad\xbe\xef"
        result  = self._echo(direct_service, "mp-bytes", payload)
        assert result == payload
        assert isinstance(result, bytes)

    def test_tuple_becomes_list(self, direct_service):
        """msgpack has no tuple type — tuples arrive as lists."""
        payload = (10, 20, 30)
        result  = self._echo(direct_service, "mp-tup", payload)
        assert result == list(payload)
        assert isinstance(result, list)

    def test_nested_tuple_becomes_list(self, direct_service):
        payload = ((1, 2), (3, 4))
        result  = self._echo(direct_service, "mp-ntup", payload)
        assert result == [[1, 2], [3, 4]]

    def test_integer_dict_keys(self, direct_service):
        """strict_map_key=False allows integer keys."""
        payload = {1: "one", 2: "two"}
        result  = self._echo(direct_service, "mp-intkeys", payload)
        assert result == payload

    def test_nested_bytes_in_dict(self, direct_service):
        payload = {"data": b"\xff\xfe", "name": "test"}
        result  = self._echo(direct_service, "mp-nested-bytes", payload)
        assert result == payload
        assert isinstance(result["data"], bytes)

    def test_large_payload(self, direct_service):
        payload = list(range(10_000))
        assert self._echo(direct_service, "mp-large", payload) == payload

    def test_multi_arg(self, direct_service):
        from daffi import Client, SerdeFormat
        client = Client(app_name="mp-multi", host=HOST, port=direct_service)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.MSGPACK)
        result = proxy.add(21, 21)
        client.stop()
        assert result == 42

    def test_via_router(self, router_with_worker):
        """MSGPACK works across the two-hop Router layout too."""
        from daffi import Client, SerdeFormat
        client = Client(app_name="mp-router", host=HOST, port=router_with_worker)
        conn   = client.connect()
        proxy  = conn.rpc(timeout=TIMEOUT, serde=SerdeFormat.MSGPACK)
        payload = {"via": "router", "data": b"\xca\xfe"}
        result  = proxy.echo(payload)
        client.stop()
        assert result == payload
        assert isinstance(result["data"], bytes)


# ══════════════════════════════════════════════════════════════════════════════
# Cross-format comparison
# ══════════════════════════════════════════════════════════════════════════════

class TestCrossFormat:
    """Same payload sent with every compatible format; results compared."""

    JSON_SAFE_PAYLOAD = {"x": 1, "y": [2, 3, 4], "flag": True, "nothing": None}

    @pytest.mark.parametrize("serde_name", ["PICKLE", "JSON"])
    def test_json_safe_payload(self, direct_service, serde_name):
        """JSON-safe dict echoes correctly through both PICKLE and JSON."""
        from daffi import SerdeFormat
        serde  = getattr(SerdeFormat, serde_name)
        result = _rpc(
            direct_service, f"cross-{serde_name.lower()}", "echo",
            self.JSON_SAFE_PAYLOAD, serde=serde,
        )
        assert result == self.JSON_SAFE_PAYLOAD

    @skip_no_msgpack
    def test_json_safe_payload_msgpack(self, direct_service):
        from daffi import SerdeFormat
        result = _rpc(
            direct_service, "cross-msgpack", "echo",
            self.JSON_SAFE_PAYLOAD, serde=SerdeFormat.MSGPACK,
        )
        assert result == self.JSON_SAFE_PAYLOAD

    def test_opaque_str_is_independent_of_other_formats(self, direct_service):
        """OPAQUE is distinct: it transports a pre-encoded string, not a dict."""
        from daffi import SerdeFormat
        payload = self.JSON_SAFE_PAYLOAD
        wire    = json.dumps(payload)

        # OPAQUE echoes the string as-is
        opaque_result = _rpc(
            direct_service, "cross-opaque", "echo", wire, serde=SerdeFormat.OPAQUE,
        )
        assert opaque_result == wire          # string, not dict
        assert json.loads(opaque_result) == payload   # caller decodes

    def test_pickle_preserves_what_json_loses(self, direct_service):
        """Demonstrate PICKLE's broader type support vs JSON."""
        from daffi import SerdeFormat

        # These types survive PICKLE but not JSON
        for payload, description in [
            (b"raw bytes", "bytes"),
            ((1, 2, 3), "tuple"),
            ({1, 2, 3}, "set"),
        ]:
            result = _rpc(
                direct_service, f"cross-pk-{description}", "echo",
                payload, serde=SerdeFormat.PICKLE,
            )
            assert result == payload, f"{description} not preserved by PICKLE"

    @skip_no_msgpack
    def test_msgpack_preserves_bytes_unlike_json(self, direct_service):
        """MSGPACK handles bytes; JSON would raise TypeError on serialisation."""
        from daffi import SerdeFormat
        payload = b"\xca\xfe\xba\xbe"
        result  = _rpc(
            direct_service, "cross-mp-bytes", "echo", payload, serde=SerdeFormat.MSGPACK,
        )
        assert result == payload
        assert isinstance(result, bytes)
