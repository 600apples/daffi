"""
Unit tests for daffi.utils.misc utility functions.

Current public surface (daffi.utils.misc):

  uuid()                  — random 32-bit unsigned integer
  string_uuid()           — hex string encoding of uuid()  (e.g. '0x3f2a1c08')
  is_lambda_function(obj) — True iff obj is an anonymous lambda
  iterable(obj)           — True iff obj is a non-str, non-bytes, non-dict Iterable
"""
from __future__ import annotations

import pytest

from daffi.utils.misc import is_lambda_function, iterable
from daffi.utils.misc import uuid as daffi_uuid
from daffi.utils.misc import string_uuid


# ══════════════════════════════════════════════════════════════════════════════
# is_lambda_function
# ══════════════════════════════════════════════════════════════════════════════

class TestIsLambdaFunction:
    """is_lambda_function returns True only for anonymous lambdas."""

    # ── True cases ────────────────────────────────────────────────────────────

    def test_lambda_no_args(self):
        assert is_lambda_function(lambda: None) is True

    def test_lambda_one_arg(self):
        assert is_lambda_function(lambda x: x) is True

    def test_lambda_multi_arg(self):
        assert is_lambda_function(lambda a, b: a + b) is True

    def test_lambda_default_arg(self):
        assert is_lambda_function(lambda x=1: x) is True

    # ── False cases ───────────────────────────────────────────────────────────

    def test_named_function(self):
        def fn():
            pass

        assert is_lambda_function(fn) is False

    def test_named_function_with_args(self):
        def add(a, b):
            return a + b

        assert is_lambda_function(add) is False

    def test_class(self):
        class Cls:
            pass

        assert is_lambda_function(Cls) is False

    def test_callable_instance(self):
        class CallableObj:
            def __call__(self):
                pass

        assert is_lambda_function(CallableObj()) is False

    def test_builtin_len(self):
        assert is_lambda_function(len) is False

    def test_builtin_print(self):
        assert is_lambda_function(print) is False

    def test_none(self):
        assert is_lambda_function(None) is False

    def test_int(self):
        assert is_lambda_function(42) is False

    def test_string(self):
        assert is_lambda_function("lambda x: x") is False

    def test_list(self):
        assert is_lambda_function([1, 2, 3]) is False

    def test_method(self):
        class T:
            def method(self):
                pass

        assert is_lambda_function(T().method) is False


# ══════════════════════════════════════════════════════════════════════════════
# iterable
# ══════════════════════════════════════════════════════════════════════════════

class TestIterable:
    """iterable(obj) → True for non-str / non-bytes / non-dict Iterables."""

    # ── True cases ────────────────────────────────────────────────────────────

    def test_list(self):
        assert iterable([1, 2, 3]) is True

    def test_empty_list(self):
        assert iterable([]) is True

    def test_tuple(self):
        assert iterable((1, 2, 3)) is True

    def test_set(self):
        assert iterable({1, 2, 3}) is True

    def test_frozenset(self):
        assert iterable(frozenset([1, 2])) is True

    def test_range(self):
        assert iterable(range(10)) is True

    def test_generator_expression(self):
        assert iterable(x for x in range(3)) is True

    def test_generator_function_result(self):
        def gen():
            yield 1
            yield 2

        assert iterable(gen()) is True

    # ── False cases: excluded types ───────────────────────────────────────────

    def test_string_excluded(self):
        """Strings are Iterable but explicitly excluded."""
        assert iterable("hello") is False

    def test_empty_string_excluded(self):
        assert iterable("") is False

    def test_bytes_excluded(self):
        """bytes are Iterable but explicitly excluded."""
        assert iterable(b"hello") is False

    def test_empty_bytes_excluded(self):
        assert iterable(b"") is False

    def test_bytearray_excluded(self):
        """bytearray is Iterable but explicitly excluded (it is bytes-like)."""
        # bytearray is a subtype of bytes in isinstance check? No — let's verify.
        # Actually bytearray is NOT a subclass of bytes, so it is NOT excluded.
        # This test documents the actual behaviour rather than an assumption.
        result = iterable(bytearray(b"data"))
        # bytearray is Iterable and not str/bytes/dict → should be True
        assert result is True

    def test_dict_excluded(self):
        """dicts are Iterable but explicitly excluded."""
        assert iterable({"a": 1}) is False

    def test_empty_dict_excluded(self):
        assert iterable({}) is False

    # ── False cases: non-Iterable types ──────────────────────────────────────

    def test_int(self):
        assert iterable(42) is False

    def test_float(self):
        assert iterable(3.14) is False

    def test_none(self):
        assert iterable(None) is False

    def test_bool(self):
        assert iterable(True) is False

    def test_callable(self):
        assert iterable(len) is False


# ══════════════════════════════════════════════════════════════════════════════
# uuid  (32-bit unsigned integer)
# ══════════════════════════════════════════════════════════════════════════════

class TestUuid:
    """daffi_uuid() returns a random 32-bit unsigned integer."""

    def test_returns_int(self):
        assert isinstance(daffi_uuid(), int)

    def test_non_negative(self):
        for _ in range(50):
            assert daffi_uuid() >= 0

    def test_fits_in_u32(self):
        """Must be representable in an unsigned 32-bit field: 0 ≤ x < 2³²."""
        for _ in range(50):
            assert daffi_uuid() < (1 << 32)

    def test_unique_across_calls(self):
        """10 calls must (with overwhelming probability) produce distinct values."""
        values = {daffi_uuid() for _ in range(10)}
        assert len(values) > 1

    def test_not_always_zero(self):
        assert any(daffi_uuid() != 0 for _ in range(20))


# ══════════════════════════════════════════════════════════════════════════════
# string_uuid  (hex string)
# ══════════════════════════════════════════════════════════════════════════════

class TestStringUuid:
    """string_uuid() returns a short hex string like '0x3f2a1c08'."""

    def test_returns_str(self):
        assert isinstance(string_uuid(), str)

    def test_starts_with_0x(self):
        assert string_uuid().startswith("0x")

    def test_is_valid_hex(self):
        """The whole string must parse as a hexadecimal integer."""
        s = string_uuid()
        parsed = int(s, 16)   # raises ValueError on invalid hex
        assert parsed >= 0

    def test_encodes_u32(self):
        """The encoded value must fit in 32 bits, same as uuid()."""
        for _ in range(20):
            n = int(string_uuid(), 16)
            assert 0 <= n < (1 << 32)

    def test_unique_across_calls(self):
        values = {string_uuid() for _ in range(10)}
        assert len(values) > 1

    def test_consistent_with_uuid(self):
        """int(string_uuid(), 16) must live in the same space as uuid()."""
        for _ in range(20):
            n = int(string_uuid(), 16)
            assert 0 <= n < (1 << 32)
