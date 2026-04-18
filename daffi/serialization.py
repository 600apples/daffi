"""
Serialisation and deserialisation for the three supported wire formats.
"""
import json
import pickle
from typing import Union, Tuple, Dict, Callable


class SerdeFormat:
    """Wire serialisation format selector.

    Pass one of these constants to :meth:`~daffi.app.ClientConnection.rpc` or
    :meth:`~daffi.app.ClientConnection.stream` via the *serde* argument.
    """

    RAW = 0
    """Zero-copy pass-through.  The single argument must already be ``bytes``
    or ``str``; it is placed on the wire as-is."""

    JSON = 1
    """All positional and keyword arguments are encoded as a JSON object
    ``{"args": [...], "kwargs": {...}}``."""

    PICKLE = 2
    """All positional and keyword arguments are pickled as a ``(args, kwargs)``
    tuple."""


class Serializer:
    """Dispatch-table based serializer/deserializer.

    Each format has its own private handler; :meth:`serialize` and
    :meth:`deserialize` look up the handler in ``_SERIALIZE`` /
    ``_DESERIALIZE`` and delegate immediately — no ``if/elif`` chains.
    """

    @staticmethod
    def _serialize_raw(*args, **kwargs) -> Tuple[Union[bytes, str], bool]:
        """RAW: enforce a single argument, pass it through unchanged.

        Raises:
            TypeError: If more than one argument (positional or keyword) is
                       supplied, since RAW has no framing to separate multiple
                       values.
        """
        n_args, n_kwargs = len(args), len(kwargs)
        if n_args + n_kwargs > 1:
            raise TypeError(
                f"SerdeFormat.RAW accepts exactly one argument "
                f"(got {n_args} positional, {n_kwargs} keyword). "
                f"Use JSON or PICKLE to pass multiple arguments."
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
    def _deserialize_raw(data: Union[bytes, str]) -> Tuple:
        """RAW: wrap the payload in a one-element tuple to match the
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
            TypeError:  For ``RAW`` when more than one argument is supplied.
            ValueError: When *serde* is not a recognised :class:`SerdeFormat`.
        """
        try:
            return cls._SERIALIZE[serde](*args, **kwargs)
        except KeyError:
            raise ValueError(f"Unknown serde format: {serde!r}")

    @classmethod
    def deserialize(
        cls, serde: SerdeFormat, data: Union[bytes, str]
    ) -> Tuple:
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
    SerdeFormat.RAW:    Serializer._serialize_raw,
    SerdeFormat.JSON:   Serializer._serialize_json,
    SerdeFormat.PICKLE: Serializer._serialize_pickle,
}

Serializer._DESERIALIZE = {
    SerdeFormat.RAW:    Serializer._deserialize_raw,
    SerdeFormat.JSON:   Serializer._deserialize_json,
    SerdeFormat.PICKLE: Serializer._deserialize_pickle,
}
