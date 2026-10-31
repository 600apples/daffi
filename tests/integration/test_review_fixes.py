"""
End-to-end regression tests for the second review round.

Each test fails on the behaviour that used to happen:

* any peer could make a service unpickle its payload, and so run its code;
  a browser page could do it over a WebSocket;
* one request whose text payload was not valid UTF-8 stopped the
  dispatcher, so the service never answered anything again;
* two clients in one process deadlocked when a callback of one called the
  other: the callback held the only poller thread;
* after ``start(); stop(); start()`` the second ``stop()`` did nothing and
  the port kept accepting;
* ``rpc_nowait`` split a list argument into one call per item and dropped
  keyword arguments.
"""

from __future__ import annotations
from tests.conftest import active_runtime

import json
import multiprocessing as mp
import os
import socket
import struct
import subprocess
import sys
import threading
import time
from contextlib import contextmanager
from pathlib import Path

import pytest

from .conftest import (
    HOST,
    proc_router,
    proc_service,
    quiet_kill,
    silence_subprocess,
    wait_for_members,
    wait_for_port,
)
from .test_hardening import pack_header, ws_upgrade_request

ROOT = Path(__file__).resolve().parents[2]
TARGET = "fix-target"


# ── subprocess targets ────────────────────────────────────────────────────────


def _proc_target_service(runtime: str, port: int, workers: int, serdes) -> None:
    silence_subprocess(runtime)
    from daffi import Service, callback, TCPTransport

    seen: list = []

    @callback
    def lookup(key):
        return key

    @callback
    def remember(*args, **kwargs):
        seen.append((args, kwargs))

    @callback
    def recall():
        return list(seen)

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    transport = TCPTransport(HOST, port)
    transport.websocket_allowed_origins = ["http://localhost"]
    svc = Service(
        app_name=TARGET,
        workers=workers,
        serdes=serdes,
        transport=transport,
        runtime=runtime,
    )
    svc.start()
    svc.join()


class _Booby:
    """Unpickling this creates *path*: proof that a payload was unpickled."""

    def __init__(self, path: str) -> None:
        self.path = path

    def __reduce__(self):
        return (open, (self.path, "w"))


# ── helpers ───────────────────────────────────────────────────────────────────


def _start_target(port: int, workers: int = 1, serdes=None) -> mp.Process:
    proc = mp.Process(
        target=_proc_target_service,
        args=(active_runtime(), port, workers, serdes),
        daemon=True,
    )
    proc.start()
    wait_for_port(port)
    wait_for_members(port, {TARGET})
    return proc


@contextmanager
def _client(port: int, name: str, *members: str):
    from daffi import Client, TCPTransport

    client = Client(app_name=name, transport=TCPTransport(HOST, port), runtime=active_runtime())
    conn = client.connect()
    try:
        if members:
            conn.wait_for_members(*members, timeout=10)
        yield client, conn
    finally:
        client.stop()


def _wait_until(predicate, timeout: float, what: str) -> None:
    deadline = time.monotonic() + timeout
    while not predicate():
        if time.monotonic() > deadline:
            pytest.fail(f"timed out waiting for {what}")
        time.sleep(0.05)


def _accepts(port: int) -> bool:
    try:
        socket.create_connection((HOST, port), timeout=0.5).close()
        return True
    except OSError:
        return False


def _run_script(source: str, timeout: float = 60) -> tuple[int, str]:
    env = dict(os.environ, PYTHONPATH=str(ROOT))
    proc = subprocess.Popen(
        [sys.executable, "-c", source],
        cwd=str(ROOT),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        out, err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
        pytest.fail(f"script did not exit within {timeout}s\n{out}\n{err}")
    return proc.returncode, out + err


# ── WebSocket wire helpers ────────────────────────────────────────────────────

FLAG_REQUEST, FLAG_RESPONSE, FLAG_ERROR = 1, 2, 3


def _request(
    uuid: int, serde: int, func_name: str, data: bytes, is_bytes: bool, return_result: bool = True
) -> bytes:
    metadata = f"ws-peer||{func_name}".encode()
    body = metadata + data
    return pack_header(
        uuid=uuid,
        flag=FLAG_REQUEST,
        decoder=serde,
        is_bytes=int(is_bytes),
        return_result=int(return_result),
        msg_len=len(body),
        metadata_len=len(metadata),
    ) + body


def _handshake() -> bytes:
    body = json.dumps({"meta": {"type": "client"}, "members": [{"name": "ws-peer", "methods": None}]}).encode()
    metadata = b"ws-peer||"
    return pack_header(
        uuid=1,
        flag=0,
        decoder=1,
        return_result=1,
        msg_len=len(metadata) + len(body),
        metadata_len=len(metadata),
    ) + metadata + body


def _masked_binary_frame(payload: bytes) -> bytes:
    mask = os.urandom(4)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    if len(payload) < 126:
        length = bytes([0x80 | len(payload)])
    else:
        length = bytes([0x80 | 126]) + struct.pack(">H", len(payload))
    return b"\x82" + length + mask + masked


def _recv_exact(sock: socket.socket, n: int) -> bytes:
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("closed")
        buf += chunk
    return buf


def _read_message(sock: socket.socket) -> tuple[int, int, int, bytes]:
    """``(uuid, flag, serde, data)`` of the next binary frame."""
    while True:
        first, second = _recv_exact(sock, 2)
        length = second & 0x7F
        if length == 126:
            (length,) = struct.unpack(">H", _recv_exact(sock, 2))
        elif length == 127:
            (length,) = struct.unpack(">Q", _recv_exact(sock, 8))
        payload = _recv_exact(sock, length)
        if first & 0x0F == 0x2:
            break
    header = int.from_bytes(payload[:9], "little")
    metadata_len = (header >> 49) & 0x7FFF
    return (
        header & 0xFFFF,
        (header >> 16) & 0xF,
        (header >> 20) & 0x3,
        payload[9 + metadata_len :],
    )


@contextmanager
def _websocket(port: int):
    with socket.create_connection((HOST, port), timeout=10) as sock:
        sock.sendall(ws_upgrade_request())
        response = b""
        while b"\r\n\r\n" not in response:
            chunk = sock.recv(1024)
            assert chunk, "server closed during the upgrade"
            response += chunk
        assert b" 101 " in response.split(b"\r\n", 1)[0], response
        yield sock


# ── 1. PICKLE ─────────────────────────────────────────────────────────────────


@pytest.fixture(params=[1, 4], ids=["inline", "pool"])
def target(request, free_port):
    from daffi import SerdeFormat

    proc = _start_target(free_port, request.param, serdes=SerdeFormat.ALL)
    yield free_port
    quiet_kill(proc)


class TestPickleFromWebSocket:
    def test_json_request_reaches_the_callback(self, target):
        """The frames below are well formed: the same request in JSON is run."""
        from daffi import SerdeFormat
        from daffi._serialization import Serializer

        data, is_bytes = Serializer.serialize(SerdeFormat.JSON, "from-ws")
        if isinstance(data, str):
            data = data.encode()
        with _websocket(target) as sock:
            sock.sendall(_masked_binary_frame(_handshake()))
            sock.sendall(
                _masked_binary_frame(
                    _request(7, SerdeFormat.JSON, "remember", data, is_bytes, return_result=False)
                )
            )
            with _client(target, "ws-witness", TARGET) as (_, conn):
                _wait_until(lambda: conn.rpc(timeout=10, serde=SerdeFormat.PICKLE).recall(), 10, "the WebSocket request")
                assert conn.rpc(timeout=10, serde=SerdeFormat.PICKLE).recall() == [(("from-ws",), {})]

    def test_pickle_request_is_refused_and_never_unpickled(self, target, tmp_path):
        from daffi import SerdeFormat
        from daffi._serialization import Serializer

        marker = tmp_path / "unpickled"
        data, is_bytes = Serializer.serialize(SerdeFormat.PICKLE, _Booby(str(marker)))
        with _websocket(target) as sock:
            sock.sendall(_masked_binary_frame(_request(9, SerdeFormat.PICKLE, "lookup", data, is_bytes)))
            uuid, flag, serde, body = _read_message(sock)
        assert (uuid, flag) == (9, FLAG_ERROR)
        assert b"SerdeNotAllowed" in body
        time.sleep(0.3)
        assert not marker.exists(), "a PICKLE payload from a WebSocket was unpickled"

    def test_pickle_through_a_router_is_refused(self, free_port, tmp_path):
        from daffi import SerdeFormat
        from daffi._serialization import Serializer

        router = mp.Process(target=proc_router, args=(active_runtime(), free_port), daemon=True)
        router.start()
        worker = None
        try:
            wait_for_port(free_port)
            worker = mp.Process(
                target=_proc_target_worker, args=(active_runtime(), free_port), daemon=True
            )
            worker.start()
            wait_for_members(free_port, {TARGET})
            marker = tmp_path / "unpickled"
            data, is_bytes = Serializer.serialize(SerdeFormat.PICKLE, _Booby(str(marker)))
            with _websocket(free_port) as sock:
                sock.sendall(
                    _masked_binary_frame(_request(11, SerdeFormat.PICKLE, "lookup", data, is_bytes))
                )
                uuid, flag, _, body = _read_message(sock)
            assert (uuid, flag) == (11, FLAG_ERROR)
            assert b"SerdeNotAllowed" in body
            time.sleep(0.3)
            assert not marker.exists()
        finally:
            if worker is not None:
                quiet_kill(worker)
            quiet_kill(router)


def _proc_target_worker(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Client, callback, TCPTransport

    @callback
    def lookup(key):
        return key

    client = Client(app_name=TARGET, transport=TCPTransport(HOST, port), runtime=runtime)
    client.connect()
    client.join()


class TestSerdesAllowList:
    @pytest.mark.parametrize("workers", [1, 4], ids=["inline", "pool"])
    def test_refused_formats_are_never_decoded(self, free_port, tmp_path, workers):
        from daffi import SerdeFormat
        from daffi.exceptions import RemoteCallError

        proc = _start_target(free_port, workers, serdes=[SerdeFormat.JSON])
        try:
            marker = tmp_path / "unpickled"
            with _client(free_port, "allow-list", TARGET) as (_, conn):
                with pytest.raises(RemoteCallError, match="PICKLE") as info:
                    conn.rpc(timeout=10, serde=SerdeFormat.PICKLE).lookup(_Booby(str(marker)))
                assert type(info.value).__name__ == "SerdeNotAllowed"
                with pytest.raises(RemoteCallError) as info:
                    conn.rpc(timeout=10, serde=SerdeFormat.OPAQUE).lookup(b"raw")
                assert type(info.value).__name__ == "SerdeNotAllowed"
                assert conn.rpc(timeout=10, serde=SerdeFormat.JSON).add(2, 3) == 5
            assert not marker.exists(), "a refused PICKLE payload was unpickled"
        finally:
            quiet_kill(proc)

    def test_invalid_values_are_rejected(self, free_port):
        from daffi import Service, SerdeFormat, TCPTransport
        from daffi.exceptions import InitializationError

        for bad in ("json", [99], [], 5):
            with pytest.raises(InitializationError):
                Service(
                    transport=TCPTransport(HOST, free_port), runtime=active_runtime(), serdes=bad
                )
        svc = Service(transport=TCPTransport(HOST, free_port), runtime=active_runtime())
        assert svc.serdes == SerdeFormat.ALL


# ── 2. invalid UTF-8 ──────────────────────────────────────────────────────────


def test_invalid_utf8_text_does_not_stop_the_service(target):
    """The payload arrives as bytes, and the service keeps answering."""
    from daffi import SerdeFormat
    from daffi._bindings import MessageFlag, send_message_from_client

    with _client(target, "bad-utf8", TARGET) as (client, conn):
        for _ in range(3):
            send_message_from_client(
                data=b"\xff\xfe",
                flag=MessageFlag.REQUEST,
                serde=SerdeFormat.OPAQUE,
                receiver="",
                func_name="remember",
                return_result=False,
                conn_num=client._conn_num,
                is_bytes=False,
            )
        assert conn.rpc(timeout=10).add(20, 22) == 42
        assert conn.rpc(timeout=10, serde=SerdeFormat.PICKLE).recall() == [((b"\xff\xfe",), {})] * 3


# ── 3. nested calls between clients of one process ────────────────────────────


@pytest.mark.parametrize("hops", [1, 3])
def test_callback_can_call_a_client_in_the_same_process(free_port, hops):
    rt = active_runtime()
    script = f"""
import threading, time
from daffi import Client, Router, TCPTransport, callback, dfcore
dfcore.setRuntime({rt!r})
conns = {{}}

@callback
def bounce(path):
    if not path:
        return "done"
    return conns["C"].rpc(timeout=10, receiver=path[0]).bounce(path[1:])

router = Router(transport=TCPTransport("127.0.0.1", {free_port}), runtime={rt!r})
router.start()
clients = []
for name in ("A", "B", "C"):
    client = Client(app_name=name, transport=TCPTransport("127.0.0.1", {free_port}), runtime={rt!r})
    conns[name] = client.connect()
    clients.append(client)
conns["C"].wait_for_members("A", "B", timeout=10)
path = (["B", "A"] * 2)[:{hops}]
started = time.monotonic()
for _ in range(10):
    assert conns["C"].rpc(timeout=10, receiver="A").bounce(path) == "done"
print("took", round(time.monotonic() - started, 2), flush=True)
time.sleep(0.3)
print("pollers", sum(t.name == "daffi-poller" for t in threading.enumerate()), flush=True)
for client in clients:
    client.stop()
router.stop()
"""
    code, output = _run_script(script)
    assert code == 0, output
    took = float(output.split("took ")[1].split()[0])
    assert took < 5, output
    # The threads that handed polling off exit once their callback returns.
    assert int(output.split("pollers ")[1].split()[0]) <= 2, output


# ── 4. restart ────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("kind", ["Service", "Router"])
def test_server_restarted_after_stop_stops_again(free_port, kind):
    import daffi
    from daffi import TCPTransport

    server = getattr(daffi, kind)(
        app_name=f"restart-{kind.lower()}",
        transport=TCPTransport(HOST, free_port),
        runtime=active_runtime(),
    )
    server.start()
    server.stop()
    _wait_until(lambda: not _accepts(free_port), 5, "the first stop to close the port")
    server.start()
    try:
        assert _accepts(free_port)
        joiner = threading.Thread(target=server.join, daemon=True)
        joiner.start()
        joiner.join(0.3)
        assert joiner.is_alive(), "join() returned while the server was running"
    finally:
        server.stop()
    _wait_until(lambda: not _accepts(free_port), 5, "the second stop to close the port")
    joiner.join(5)
    assert not joiner.is_alive()


def test_client_reconnected_after_stop_works(free_port):
    from daffi import Client, TCPTransport

    proc = mp.Process(target=proc_service, args=(active_runtime(), free_port), daemon=True)
    proc.start()
    try:
        wait_for_port(free_port)
        wait_for_members(free_port, {"integ-service"})
        client = Client(
            app_name="reconnect-after-stop",
            transport=TCPTransport(HOST, free_port),
            runtime=active_runtime(),
        )
        for round_ in range(2):
            conn = client.connect()
            try:
                conn.wait_for_members("integ-service", timeout=10)
                assert conn.rpc(timeout=10).add(round_, 1) == round_ + 1
                joiner = threading.Thread(target=client.join, daemon=True)
                joiner.start()
                joiner.join(0.3)
                assert joiner.is_alive(), f"round {round_}: join() returned while connected"
            finally:
                client.stop()
            joiner.join(5)
            assert not joiner.is_alive()
    finally:
        quiet_kill(proc)


# ── 5. rpc_nowait ─────────────────────────────────────────────────────────────


def test_rpc_nowait_sends_one_call_with_all_arguments(target):
    from daffi import SerdeFormat

    with _client(target, "nowait-caller", TARGET) as (_, conn):
        conn.rpc_nowait().remember(["a", "b", "c"], tag="x")
        conn.rpc_nowait().remember("plain")
        conn.rpc_nowait().remember(key=[1, 2])
        _wait_until(lambda: len(conn.rpc(timeout=10, serde=SerdeFormat.PICKLE).recall()) >= 3, 10, "the calls")
        time.sleep(0.2)
        # A pool may run them in any order.
        assert sorted(conn.rpc(timeout=10, serde=SerdeFormat.PICKLE).recall(), key=repr) == sorted(
            [
                ((["a", "b", "c"],), {"tag": "x"}),
                (("plain",), {}),
                ((), {"key": [1, 2]}),
            ],
            key=repr,
        )
