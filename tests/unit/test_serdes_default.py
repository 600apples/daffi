"""
Default ``serdes=`` accepts every format, including PICKLE. A node refuses
PICKLE only when the customer sets ``serdes=SerdeFormat.SAFE`` (or any set
without PICKLE).
"""

from __future__ import annotations

import pytest

from daffi._serialization import SerdeFormat, Serializer
from daffi.exceptions import SerdeNotAllowed


class _Booby:
    """Unpickling this records that it happened."""

    unpickled: list = []

    def __reduce__(self):
        return (_Booby.unpickled.append, ("unpickled",))


def test_default_serdes_accepts_pickle():
    from daffi.app import _coerce_serdes

    assert _coerce_serdes(None) == SerdeFormat.ALL
    assert SerdeFormat.PICKLE in _coerce_serdes(None)
    assert _coerce_serdes(SerdeFormat.SAFE) == SerdeFormat.SAFE
    assert SerdeFormat.PICKLE not in _coerce_serdes(SerdeFormat.SAFE)


def test_a_node_without_serdes_accepts_pickle():
    from daffi._task_dispatcher import _accepted

    assert _accepted(object()) == SerdeFormat.ALL


def test_safe_serdes_refuses_pickle():
    from daffi._task_dispatcher import _check_serde

    with pytest.raises(SerdeNotAllowed, match="PICKLE") as info:
        _check_serde(SerdeFormat.PICKLE, SerdeFormat.SAFE)
    assert "serdes=" in str(info.value)
    _check_serde(SerdeFormat.PICKLE, SerdeFormat.ALL)


class _Cb:
    is_coroutine = False

    def __call__(self, *a, **k):
        return "ran"


def test_default_invoke_accepts_pickle(monkeypatch):
    from daffi import _task_dispatcher
    from daffi._bindings import MessageFlag

    monkeypatch.setattr(_task_dispatcher, "_lookup", lambda name, exposed: _Cb())
    data, _ = Serializer.serialize(SerdeFormat.PICKLE, "x")
    result, flag, serde = _task_dispatcher._invoke_callback(
        "f", SerdeFormat.PICKLE, data
    )
    assert flag == MessageFlag.RESPONSE
    assert result == "ran"
    assert serde == SerdeFormat.PICKLE


def test_safe_invoke_never_unpickles(monkeypatch):
    from daffi import _task_dispatcher
    from daffi._bindings import MessageFlag

    _Booby.unpickled.clear()
    monkeypatch.setattr(_task_dispatcher, "_lookup", lambda name, exposed: _Cb())
    data, _ = Serializer.serialize(SerdeFormat.PICKLE, _Booby())
    result, flag, serde = _task_dispatcher._invoke_callback(
        "f", SerdeFormat.PICKLE, data, accepted=SerdeFormat.SAFE
    )
    assert flag == MessageFlag.ERROR
    assert serde == SerdeFormat.JSON
    assert result[0] == "SerdeNotAllowed"
    assert _Booby.unpickled == []
