"""Serializer accepts the buffer types CFFI now hands to OPAQUE."""

from daffi._serialization import SerdeFormat, Serializer


def test_opaque_accepts_memoryview_and_bytearray():
    view = memoryview(b"hello-view")
    data, is_bytes = Serializer.serialize(SerdeFormat.OPAQUE, view)
    assert is_bytes is True
    assert data == view

    arr = bytearray(b"hello-array")
    data, is_bytes = Serializer.serialize(SerdeFormat.OPAQUE, arr)
    assert is_bytes is True
    assert data == arr


def test_opaque_round_trip_memoryview():
    view = memoryview(b"abc")
    assert Serializer.unpack_result(SerdeFormat.OPAQUE, view) == view
    assert Serializer.invoke(SerdeFormat.OPAQUE, lambda x: bytes(x), view) == b"abc"
