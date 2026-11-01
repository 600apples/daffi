"""
The browser client's wasm module (``js-client/app.wasm``), driven the way
``js-client/daffi.js`` drives it.

Each test fails on the behaviour that used to happen:

* a payload was measured by searching for a NUL byte, so binary data was
  cut at its first zero;
* ``free`` measured its buffer the same way, so it freed the wrong size;
  every sent message and returned receiver name leaked as well.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path

import pytest

wasmtime = pytest.importorskip("wasmtime")

WASM = Path(__file__).resolve().parents[2] / "js-client" / "app.wasm"
FLAG_HANDSHAKE, FLAG_RESPONSE = 0, 2
OPAQUE, JSON = 0, 1
SERVICE = "svc"


def _frame(uuid: int, flag: int, decoder: int, metadata: str, data: bytes) -> bytes:
    meta = metadata.encode()
    body = meta + data
    v = uuid | flag << 16 | decoder << 20 | len(body) << 24 | len(meta) << 49 | 1 << 64 | 1 << 71
    return v.to_bytes(9, "little") + body


def _parse(frame: bytes) -> tuple[int, int, bytes]:
    """``(uuid, flag, data)``"""
    v = int.from_bytes(frame[:9], "little")
    metadata_len = (v >> 49) & 0x7FFF
    return v & 0xFFFF, (v >> 16) & 0xF, frame[9 + metadata_len :]


class WasmClient:
    """The part of daffi.js that talks to the wasm module."""

    def __init__(self, name: str = "browser", auth_token: str = ""):
        engine = wasmtime.Engine()
        self.store = wasmtime.Store(engine)
        linker = wasmtime.Linker(engine)
        i32 = wasmtime.ValType.i32()
        self.sent: list[bytes] = []
        self.stored: list[tuple[int, bytes, int]] = []

        def throw(ptr, length):
            raise RuntimeError(self._read(ptr, length).decode(errors="replace"))

        def store_message(ptr, length, uuid, is_error, decoder):
            self.stored.append((uuid, self._read(ptr, length), is_error))

        linker.define_func("env", "_throwError", wasmtime.FuncType([i32, i32], []), throw)
        linker.define_func("env", "_consoleLog", wasmtime.FuncType([i32, i32], []), lambda p, n: None)
        linker.define_func(
            "window", "_sendToSocket", wasmtime.FuncType([i32, i32], []),
            lambda p, n: self.sent.append(self._read(p, n)),
        )
        linker.define_func(
            "window", "_storeMessage", wasmtime.FuncType([i32] * 5, []), store_message
        )
        linker.define_func("window", "_triggerEvent", wasmtime.FuncType([i32, i32], []), lambda p, n: None)
        module = wasmtime.Module.from_file(engine, str(WASM))
        self.exports = linker.instantiate(self.store, module).exports(self.store)
        self.memory = self.exports["memory"]
        self.name = name
        token_buf = self.buffer(auth_token.encode()) if auth_token else (0, 0)
        self.conn = self.call("initClient", *self.buffer(name.encode()), *token_buf)

    def call(self, name: str, *args):
        return self.exports[name](self.store, *args)

    def _read(self, ptr: int, length: int) -> bytes:
        return bytes(self.memory.read(self.store, ptr, ptr + length))

    def buffer(self, data: bytes) -> tuple[int, int]:
        ptr = self.call("allocUint8", len(data))
        self.memory.write(self.store, data, ptr)
        return ptr, len(data)

    def pages(self) -> int:
        return self.memory.size(self.store)

    def connect(self) -> None:
        uuid = self.call("sendHandshake", self.conn)
        members = {"meta": {"type": "router"}, "members": [{"name": SERVICE, "methods": ["echo"]}]}
        self.receive(_frame(uuid, FLAG_HANDSHAKE, JSON, f"{self.name}||", json.dumps(members).encode()))
        assert self.stored and self.stored[-1][0] == uuid

    def receive(self, frame: bytes) -> None:
        self.call("parseAndStoreMessage", *self.buffer(frame), self.conn)

    def send(self, payload: bytes, serde: int = OPAQUE, return_result: bool = True) -> tuple[int, str]:
        result = self.call(
            "sendMessage",
            *self.buffer(payload),
            *self.buffer(b""),
            *self.buffer(b"echo"),
            serde,
            int(return_result),
            self.conn,
        )
        uuid, receiver_len, receiver_ptr, _ = struct.unpack("<4I", self._read(result, 16))
        receiver = self._read(receiver_ptr, receiver_len).decode()
        self.call("freeSendResult", result)
        return uuid, receiver


@pytest.fixture
def client():
    if not WASM.exists():
        pytest.skip("js-client/app.wasm is not built")
    c = WasmClient()
    c.connect()
    return c


def test_binary_payload_is_sent_whole(client):
    payload = b"\x00before\x00\x00after\xff\x00"
    uuid, receiver = client.send(payload)
    assert receiver == SERVICE
    sent_uuid, _, data = _parse(client.sent[-1])
    assert sent_uuid == uuid
    assert data == payload


def test_names_are_taken_by_length():
    if not WASM.exists():
        pytest.skip("js-client/app.wasm is not built")
    c = WasmClient("browser-\u00e9")
    c.connect()
    uuid = c.call("sendHandshake", c.conn)
    assert uuid > 0


@pytest.mark.parametrize("token", ["", "s3cret"])
def test_handshake_carries_the_auth_token(token):
    if not WASM.exists():
        pytest.skip("js-client/app.wasm is not built")
    c = WasmClient(auth_token=token)
    c.call("sendHandshake", c.conn)
    _, _, data = _parse(c.sent[-1])
    assert json.loads(data)["meta"].get("token") == (token or None)


def test_sending_and_receiving_does_not_leak(client):
    payload = bytes(range(256)) * 256  # 64 KiB with NUL bytes in it
    for _ in range(50):  # let the allocator settle
        client.send(payload)
        client.send(payload, return_result=False)
    baseline = client.pages()
    for _ in range(1000):
        uuid, _ = client.send(payload)
        client.send(payload, return_result=False)
        client.receive(_frame(uuid, FLAG_RESPONSE, OPAQUE, f"{SERVICE}|{client.name}|echo", payload))
    # 1000 rounds of 192 KiB each would be ~3000 pages if anything leaked.
    assert client.pages() - baseline < 64
    assert client.stored[-1] == (uuid, payload, 0)
    members = client.call("getAvailableMembers", client.conn)
    length = client._read(members, 4096).index(0)
    assert SERVICE in json.loads(client._read(members, length))["members"][0]["name"]
    client.call("free", members, length + 1)
