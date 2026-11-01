"""
Unit tests for daffi.exceptions.
"""

from __future__ import annotations

import builtins

from daffi import exceptions


def test_star_import_keeps_the_builtin_base_exception():
    namespace: dict = {}
    exec("from daffi.exceptions import *", namespace)
    assert "BaseException" not in namespace
    assert namespace["DaffiError"] is exceptions.DaffiError


def test_every_daffi_error_shares_one_base():
    for name in exceptions.__all__:
        assert issubclass(getattr(exceptions, name), exceptions.DaffiError)
    assert exceptions.DaffiError is not builtins.BaseException
    assert exceptions.BaseException is exceptions.DaffiError
