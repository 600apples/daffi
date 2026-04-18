"""
Lightweight helper functions used throughout the daffi package.
"""

import types
from uuid import uuid4
from collections.abc import Iterable
from typing import Callable, Any


def uuid() -> int:
    """Return a random 32-bit unsigned integer UUID."""
    return uuid4().int & (1 << 32) - 1


def string_uuid() -> str:
    """Return a random UUID as a short hex string (e.g. ``'0x3f2a1c08'``)."""
    return hex(uuid())


def is_lambda_function(obj: Any) -> bool:
    """Return ``True`` if *obj* is an anonymous lambda function."""
    return isinstance(obj, types.LambdaType) and obj.__name__ == "<lambda>"


def iterable(obj: Any) -> bool:
    """Return ``True`` if *obj* is a non-string, non-bytes, non-dict iterable."""
    return isinstance(obj, Iterable) and not isinstance(obj, (str, bytes, dict))
