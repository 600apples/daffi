"""
Serialisation and deserialisation for the four supported wire formats.
"""

from __future__ import annotations

import json
import pickle
from enum import IntEnum
from typing import Union, Tuple, Dict, Callable

import msgpack


class SerdeFormat(IntEnum):
    """Wire serialisation format selector.

    Pass one of these members to :meth:`~daffi.app.ClientConnection.rpc` or
    :meth:`~daffi.app.ClientConnection.stream` via the *serde* argument.
    Values are integers on the wire (``IntEnum``).
    """

    OPAQUE = 0
    """Zero-copy pass-through.  daffi does not interpret the payload and
    ships it on the wire unchanged.  The single argument must already be
    ``bytes`` or ``str`` — both are accepted and the wire layer preserves the
    original type for the receiver."""

    JSON = 1
    """All positional and keyword arguments are encoded as a JSON object
    ``{"args": [...], "kwargs": {...}}``."""

    PICKLE = 2
    """All positional and keyword arguments are pickled as a ``(args, kwargs)``
    tuple.  Callers pass ``serde=SerdeFormat.PICKLE``.  Accepted by default
    (see :attr:`ALL`); pass ``serdes=SerdeFormat.SAFE`` to refuse it.
    Unpickling runs code the sender chooses.  Always refused from WebSocket
    peers."""

    MSGPACK = 3
    """All positional and keyword arguments are msgpack-encoded as an
    ``[args, kwargs]`` array.  Default for ``rpc()`` / ``cast()``.  Language
    agnostic; supports a narrower set of types than PICKLE (no tuples,
    custom classes, or tracebacks)."""

    @classmethod
    def name_of(cls, serde: int) -> str:
        """``"PICKLE"`` for ``SerdeFormat.PICKLE``; the number itself if unknown."""
        try:
            return cls(serde).name
        except ValueError:
            return str(serde)


# Non-member class attributes (not IntEnum values).
SerdeFormat.DEFAULT = SerdeFormat.MSGPACK  # type: ignore[misc]
"""Default ``serde=`` for ``rpc()`` / ``cast()`` / ``rpc_nowait()`` /
``cast_nowait()``."""

SerdeFormat.ALL = frozenset(  # type: ignore[misc]
    (SerdeFormat.OPAQUE, SerdeFormat.JSON, SerdeFormat.PICKLE, SerdeFormat.MSGPACK)
)
"""Every format, including PICKLE.  Default for ``serdes=`` when omitted."""

SerdeFormat.SAFE = frozenset(  # type: ignore[misc]
    (SerdeFormat.OPAQUE, SerdeFormat.JSON, SerdeFormat.MSGPACK)
)
"""JSON, MSGPACK, and OPAQUE only.  Pass as ``serdes=`` to refuse PICKLE."""


class Serializer:
    """Dispatch-table based serializer/deserializer.

    Each format has its own private handler; :meth:`serialize` and
    :meth:`deserialize` look up the handler in ``_SERIALIZE`` /
    ``_DESERIALIZE`` and delegate immediately — no ``if/elif`` chains.
    """

    @staticmethod
    def _serialize_opaque(*args, **kwargs) -> Tuple[Union[bytes, str], bool]:
        """OPAQUE: enforce a single argument, pass it through unchanged.

        Raises:
            TypeError: If more than one argument (positional or keyword) is
                       supplied, since OPAQUE has no framing to separate
                       multiple values.  Also if the value is not ``bytes``
                       or ``str``.
        """
        n_args, n_kwargs = len(args), len(kwargs)
        if n_args + n_kwargs > 1:
            raise TypeError(
                f"SerdeFormat.OPAQUE accepts exactly one argument "
                f"(got {n_args} positional, {n_kwargs} keyword). "
                f"Use JSON, PICKLE, or MSGPACK to pass multiple arguments."
            )
        if args:
            data = args[0]
        elif kwargs:
            data = next(iter(kwargs.values()))
        else:
            data = b""
        # Void callbacks (``return`` / ``return None``) reply with empty bytes
        # so stream acks and similar OPAQUE round-trips stay usable.
        if data is None:
            data = b""
        elif not isinstance(data, (bytes, str)):
            raise TypeError(
                f"SerdeFormat.OPAQUE accepts bytes or str, got {type(data).__name__}."
            )
        return data, isinstance(data, bytes)

    @staticmethod
    def _serialize_json(*args, **kwargs) -> Tuple[str, bool]:
        """JSON: encode all args and kwargs into a single JSON object."""
        return json.dumps({"args": args, "kwargs": kwargs}), False

    @staticmethod
    def _serialize_pickle(*args, **kwargs) -> Tuple[bytes, bool]:
        """PICKLE: pickle the (args, kwargs) tuple."""
        return pickle.dumps((args, kwargs)), True

    @staticmethod
    def _deserialize_opaque(data: Union[bytes, str]) -> Tuple:
        """OPAQUE: wrap the payload in a one-element tuple to match the
        ``(args, kwargs)`` contract expected by callers."""
        return (data,), {}

    @staticmethod
    def _deserialize_json(data: Union[bytes, str]) -> Tuple:
        """JSON: decode the ``{"args": ..., "kwargs": ...}`` envelope."""
        parsed = json.loads(data)
        return parsed["args"], parsed["kwargs"]

    @staticmethod
    def _deserialize_pickle(data: bytes) -> Tuple:
        """PICKLE: unpickle and return the ``(args, kwargs)`` tuple."""
        return pickle.loads(data)

    @staticmethod
    def _serialize_msgpack(*args, **kwargs) -> Tuple[bytes, bool]:
        """MSGPACK: pack ``[args, kwargs]`` as a single msgpack array.

        ``use_bin_type=True`` keeps ``bytes`` and ``str`` distinguishable on
        the wire (msgpack's default since 1.0, but we set it explicitly).
        """
        return msgpack.packb([args, kwargs], use_bin_type=True), True

    @staticmethod
    def _deserialize_msgpack(data: bytes) -> Tuple:
        """MSGPACK: unpack the ``[args, kwargs]`` array.

        ``raw=False`` decodes msgpack strings as ``str`` (not ``bytes``);
        ``strict_map_key=False`` allows non-string dict keys, matching
        Python's permissiveness.
        """
        args, kwargs = msgpack.unpackb(data, raw=False, strict_map_key=False)
        return args, kwargs

    @classmethod
    def serialize(
        cls, serde: SerdeFormat, *args, **kwargs
    ) -> Tuple[Union[bytes, str], bool]:
        """Serialise *args* / *kwargs* using the format chosen by *serde*.

        Returns:
            ``(data, is_bytes)`` — the serialised payload and a flag telling
            the native layer whether it is binary (``True``) or a UTF-8 string
            (``False``).

        Raises:
            TypeError:  For ``OPAQUE`` when more than one argument is supplied.
            ValueError: When *serde* is not a recognised :class:`SerdeFormat`.
        """
        try:
            return cls._SERIALIZE[serde](*args, **kwargs)
        except KeyError:
            raise ValueError(f"Unknown serde format: {serde!r}")

    @classmethod
    def deserialize(cls, serde: SerdeFormat, data: Union[bytes, str]) -> Tuple:
        """Deserialise *data* using the format chosen by *serde*.

        Returns:
            ``(args, kwargs)`` ready to be unpacked into a callback call.

        Raises:
            ValueError: When *serde* is not a recognised :class:`SerdeFormat`.
        """
        try:
            return cls._DESERIALIZE[serde](data)
        except KeyError:
            raise ValueError(f"Unknown serde format: {serde!r}")

    # Dispatch tables — populated after the class body so the static methods
    # are already defined when referenced here.
    _SERIALIZE: Dict[int, Callable] = {}
    _DESERIALIZE: Dict[int, Callable] = {}


Serializer._SERIALIZE = {
    SerdeFormat.OPAQUE: Serializer._serialize_opaque,
    SerdeFormat.JSON: Serializer._serialize_json,
    SerdeFormat.PICKLE: Serializer._serialize_pickle,
    SerdeFormat.MSGPACK: Serializer._serialize_msgpack,
}

Serializer._DESERIALIZE = {
    SerdeFormat.OPAQUE: Serializer._deserialize_opaque,
    SerdeFormat.JSON: Serializer._deserialize_json,
    SerdeFormat.PICKLE: Serializer._deserialize_pickle,
    SerdeFormat.MSGPACK: Serializer._deserialize_msgpack,
}
