"""
Serialisation and deserialisation for the four supported wire formats.
"""

import json
import pickle
from typing import Union, Tuple, Dict, Callable


# Lazy import — msgpack is an optional extra (``pip install daffi[msgpack]``).
# We import on first use so users without the extra installed can still use
# OPAQUE / JSON / PICKLE without any import errors at module load time.
_msgpack = None


def _require_msgpack():
    """Return the imported ``msgpack`` module or raise a helpful ImportError.

    The first call performs the import and caches it; subsequent calls reuse
    the cached reference.
    """
    global _msgpack
    if _msgpack is not None:
        return _msgpack
    try:
        import msgpack as _m
    except ImportError as exc:
        raise ImportError(
            "SerdeFormat.MSGPACK requires the optional 'msgpack' dependency. "
            "Install it with:  pip install 'daffi[msgpack]'"
        ) from exc
    _msgpack = _m
    return _m


class SerdeFormat:
    """Wire serialisation format selector.

    Pass one of these constants to :meth:`~daffi.app.ClientConnection.rpc` or
    :meth:`~daffi.app.ClientConnection.stream` via the *serde* argument.
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
    tuple."""

    MSGPACK = 3
    """All positional and keyword arguments are msgpack-encoded as an
    ``[args, kwargs]`` array.  Smaller and language-agnostic compared to
    PICKLE, but supports a narrower set of types (no tuples, custom classes,
    or tracebacks).  Requires the optional ``msgpack`` package — install with
    ``pip install 'daffi[msgpack]'``."""


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
                       multiple values.
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
        msgpack = _require_msgpack()
        return msgpack.packb([args, kwargs], use_bin_type=True), True

    @staticmethod
    def _deserialize_msgpack(data: bytes) -> Tuple:
        """MSGPACK: unpack the ``[args, kwargs]`` array.

        ``raw=False`` decodes msgpack strings as ``str`` (not ``bytes``);
        ``strict_map_key=False`` allows non-string dict keys, matching
        Python's permissiveness.
        """
        msgpack = _require_msgpack()
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
