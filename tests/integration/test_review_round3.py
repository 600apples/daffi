"""
End-to-end regression tests for the third review round.

Each test fails on the behaviour that used to happen:

* a request with uuid 0 aborted the service process (assertion in the
  native send path);
* any peer could answer a request routed through a Router, by sending a
  response with the caller's name and a guessed uuid;
* a request could name any sender, so its reply went to whoever held that
  name;
* a client that reconnected under the same name received the replies meant
  for its previous connection, whose uuids its restarted counter reuses;
* a peer that handshook again while a write to it was stalled froze all
  routing through the Router;
* a TCP host that failed to resolve was used as a Unix socket path, so a
  server unlinked and bound a file of that name in the working directory;
* a WebSocket upgrade was accepted from any page's Origin;
* a peer that sent part of a message and then nothing held its connection
  (and the memory of the partial message) forever;
* ``auth_token=`` did not exist: any process that could reach the port
  could call and take names;
* every registered callback was offered by every node in the process;
  ``callbacks=`` limits it;
* ``rpc(receiver=[...])`` with a list was not supported;
* a connect() the kernel refused at once waited out the connect timeout.
"""

from __future__ import annotations
from tests.conftest import active_runtime

import json
import multiprocessing as mp
import socket
import threading
import time
from contextlib import contextmanager

import pytest

from .conftest import (
    HOST,
    proc_router,
    quiet_kill,
    silence_subprocess,
    wait_for_members,
    wait_for_port,
)
from .test_hardening import pack_header
from .test_review_fixes import (
    TARGET,
    _handshake as _ws_handshake,
    _read_message as _ws_read_message,
    _request as _ws_request,
    _start_target,
    _websocket,
)

FLAG_HANDSHAKE, FLAG_REQUEST, FLAG_RESPONSE, FLAG_ERROR = 0, 1, 2, 3
JSON = 1
SYN = b"\x1f" * 9
SLOW = "slow-target"


# ── subprocess targets ────────────────────────────────────────────────────────


def _register_callbacks():
    import time as _time

    from daffi import callback

    @callback
    def slow(tag, delay):
        _time.sleep(delay)
        return tag

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    @callback
    def sink(data):
        return None


def _proc_slow_service(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Service, TCPTransport

    _register_callbacks()
    svc = Service(app_name=SLOW, workers=16, transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def _proc_slow_worker(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Client, TCPTransport

    _register_callbacks()
    client = Client(app_name=SLOW, workers=16, transport=TCPTransport(HOST, port), runtime=runtime)
    client.connect()
    client.join()


# ── a raw native peer ─────────────────────────────────────────────────────────


class RawPeer:
    """Speaks the native wire format directly, so it can send what a daffi
    client never would."""

    def __init__(self, port: int, name: str = "", methods=()):
        self.sock = socket.create_connection((HOST, port), timeout=10)
        self.sock.sendall(SYN)
        self.name = name
        if name:
            self.handshake(methods)

    def close(self) -> None:
        self.sock.close()

    def send(
        self,
        *,
        uuid: int,
        flag: int,
        receiver: str = "",
        func: str = "",
        data: bytes = b"",
        serde: int = JSON,
        is_bytes: bool = False,
        return_result: bool = False,
        transmitter: str | None = None,
    ) -> None:
        sender = self.name if transmitter is None else transmitter
        metadata = f"{sender}|{receiver}|{func}".encode()
        body = metadata + data
        header = pack_header(
            uuid=uuid,
            flag=flag,
            decoder=serde,
            is_bytes=int(is_bytes),
            return_result=int(return_result),
            msg_len=len(body),
            metadata_len=len(metadata),
        )
        self.sock.sendall(header + body)

    def handshake(self, methods=(), uuid: int = 1) -> None:
        body = {"meta": {"type": "client"}, "members": [{"name": self.name, "methods": list(methods) or None}]}
        self.send(uuid=uuid, flag=FLAG_HANDSHAKE, data=json.dumps(body).encode(), return_result=True)

    def _exact(self, n: int) -> bytes:
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("closed")
            buf += chunk
        return buf

    def read(self) -> tuple[int, int, list[str], bytes]:
        """``(uuid, flag, [transmitter, receiver, func], data)``."""
        header = int.from_bytes(self._exact(9), "little")
        msg_len = (header >> 24) & ((1 << 25) - 1)
        metadata_len = (header >> 49) & 0x7FFF
        body = self._exact(msg_len)
        metadata = body[:metadata_len].decode(errors="replace").split("|")
        return header & 0xFFFF, (header >> 16) & 0xF, metadata, body[metadata_len:]

    def read_reply(self, uuid: int, timeout: float = 10) -> tuple[int, bytes]:
        """``(flag, data)`` of the reply to *uuid*, skipping everything else."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.sock.settimeout(max(0.05, deadline - time.monotonic()))
            got, flag, _, data = self.read()
            if got == uuid and flag in (FLAG_RESPONSE, FLAG_ERROR, FLAG_HANDSHAKE):
                return flag, data
        raise TimeoutError(f"no reply to uuid {uuid}")


def _json(*args) -> bytes:
    from daffi import SerdeFormat
    from daffi._serialization import Serializer

    data, _ = Serializer.serialize(SerdeFormat.JSON, *args)
    return data.encode() if isinstance(data, str) else data


# ── helpers ───────────────────────────────────────────────────────────────────


def _start(target, port: int, *members: str) -> mp.Process:
    proc = mp.Process(target=target, args=(active_runtime(), port), daemon=True)
    proc.start()
    wait_for_port(port)
    if members:
        wait_for_members(port, set(members))
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


def _start_router(port: int) -> list[mp.Process]:
    router = _start(proc_router, port)
    worker = mp.Process(target=_proc_slow_worker, args=(active_runtime(), port), daemon=True)
    worker.start()
    wait_for_members(port, {SLOW})
    return [worker, router]


@pytest.fixture
def slow_router(free_port):
    procs = _start_router(free_port)
    yield procs[-1], free_port
    for proc in procs:
        quiet_kill(proc)


@pytest.fixture(params=["service", "router"])
def node(request, free_port):
    """``(process, port)`` of a Service, or of a Router with a worker, that
    serves the callbacks of ``_register_callbacks`` as ``SLOW``."""
    if request.param == "service":
        procs = [_start(_proc_slow_service, free_port, SLOW)]
    else:
        procs = _start_router(free_port)
    yield procs[-1], free_port
    for proc in procs:
        quiet_kill(proc)


# ── 1. uuid 0 ─────────────────────────────────────────────────────────────────


def test_request_with_uuid_0_is_dropped(node):
    proc, port = node
    peer = RawPeer(port, "zero-uuid")
    try:
        peer.read_reply(1)
        peer.send(uuid=0, flag=FLAG_REQUEST, receiver=SLOW, func="add", data=_json(1, 2), return_result=True)
        time.sleep(0.5)
    finally:
        peer.close()
    assert proc.is_alive(), f"died on a request with uuid 0 (exit {proc.exitcode})"
    with _client(port, "after-zero", SLOW) as (_, conn):
        assert conn.rpc(timeout=10).add(2, 3) == 5


# ── 2. who may send and answer ────────────────────────────────────────────────


def test_router_ignores_a_response_from_a_peer_it_did_not_ask(slow_router):
    _, port = slow_router
    forger = RawPeer(port, "forger")
    try:
        forger.read_reply(1)
        with _client(port, "victim", SLOW) as (_, conn):
            result: list = []
            caller = threading.Thread(target=lambda: result.append(conn.rpc(timeout=10).slow("real", 1.0)))
            caller.start()
            time.sleep(0.3)
            # The victim's request uuids are small: it counts from 1.
            for uuid in range(1, 40):
                forger.send(
                    uuid=uuid,
                    flag=FLAG_RESPONSE,
                    receiver="victim",
                    func="slow",
                    data=_json("forged"),
                    transmitter=SLOW,
                )
            caller.join(15)
            assert result == ["real"]
            # And nothing forged is parked for a later call either.
            assert conn.rpc(timeout=10).slow("second", 0) == "second"
    finally:
        forger.close()


def test_request_under_another_peers_name_is_refused(node):
    _, port = node
    with _client(port, "real-owner", SLOW):
        impostor = RawPeer(port, "impostor")
        try:
            impostor.read_reply(1)
            impostor.send(
                uuid=5,
                flag=FLAG_REQUEST,
                receiver=SLOW,
                func="add",
                data=_json(1, 2),
                return_result=True,
                transmitter="real-owner",
            )
            flag, data = impostor.read_reply(5)
        finally:
            impostor.close()
    assert flag == FLAG_ERROR
    assert b"UnknownSender" in data


def test_reconnected_client_does_not_get_the_old_connections_replies(node):
    """The old connection's requests have the same uuids the new connection's
    counter hands out again."""
    _, port = node
    name = "reconnecting"
    old = RawPeer(port, name)
    try:
        old.read_reply(1)
        for uuid in range(2, 12):
            old.send(
                uuid=uuid,
                flag=FLAG_REQUEST,
                receiver=SLOW,
                func="slow",
                data=_json("old", 1.0),
                return_result=True,
            )
        time.sleep(0.2)
        # Same name: the new connection takes over the old one's slot.
        with _client(port, name, SLOW) as (_, conn):
            assert conn.rpc(timeout=10).slow("new", 2.0) == "new"
            assert conn.rpc(timeout=10).add(1, 1) == 2
    finally:
        old.close()


# ── 3. WebSocket fragments ────────────────────────────────────────────────────


def _ws_frame(payload: bytes, opcode: int, fin: bool) -> bytes:
    mask = b"\x11\x22\x33\x44"
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    n = len(payload)
    if n < 126:
        length = bytes([0x80 | n])
    elif n < 65536:
        length = bytes([0x80 | 126]) + n.to_bytes(2, "big")
    else:
        length = bytes([0x80 | 127]) + n.to_bytes(8, "big")
    return bytes([(0x80 if fin else 0) | opcode]) + length + mask + masked


@pytest.mark.parametrize("size", [1_000, 300_000])
def test_fragmented_websocket_message_arrives_intact(free_port, size):
    """The reassembled message used to be freed before it was copied."""
    from daffi import SerdeFormat
    from daffi._serialization import Serializer

    proc = _start_target(free_port)
    try:
        key = "".join(chr(ord("a") + i % 26) for i in range(size))
        data = _json(key)
        message = _ws_request(21, SerdeFormat.JSON, "lookup", data, False)
        third = len(message) // 3
        parts = [message[:third], message[third : 2 * third], message[2 * third :]]
        with _websocket(free_port) as sock:
            sock.sendall(_ws_frame(_ws_handshake(), 0x2, True))
            sock.sendall(_ws_frame(parts[0], 0x2, False))
            sock.sendall(_ws_frame(b"", 0x9, True))  # a ping in between
            sock.sendall(_ws_frame(parts[1], 0x0, False))
            sock.sendall(_ws_frame(parts[2], 0x0, True))
            while True:
                uuid, flag, serde, body = _ws_read_message(sock)
                if uuid == 21:
                    break
        assert flag == FLAG_RESPONSE
        assert Serializer.deserialize(serde, body)[0][0] == key
        assert proc.is_alive()
    finally:
        quiet_kill(proc)


# ── 4. a stalled peer must not freeze the Router ──────────────────────────────


def test_stalled_peer_handshaking_again_does_not_freeze_routing(slow_router):
    _, port = slow_router
    stalled = RawPeer(port)
    stalled.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
    stalled.name = "stalled"
    stalled.handshake(["sink"])
    try:
        with _client(port, "flooder", SLOW, "stalled") as (_, flooder), _client(
            port, "bystander", SLOW
        ) as (_, bystander):
            blob = b"x" * (256 * 1024)

            def flood():
                try:
                    for _ in range(64):
                        flooder.rpc_nowait(receiver="stalled").sink(blob)
                except Exception:
                    pass

            threading.Thread(target=flood, daemon=True).start()
            time.sleep(0.8)  # the Router's write to the stalled peer blocks
            stalled.handshake(["sink"], uuid=2)
            time.sleep(0.2)
            started = time.monotonic()
            assert bystander.rpc(timeout=10).add(2, 2) == 4
            assert time.monotonic() - started < 2.5, "routing waited for the stalled peer"
    finally:
        stalled.close()


# ── 5. WebSocket Origin allow-list ────────────────────────────────────────────

APP_ORIGIN = "https://app.example"


def _proc_origin_router(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Router, TCPTransport

    r = Router(
        app_name="origin-router",
        transport=TCPTransport(HOST, port, allowed_origins=[APP_ORIGIN + "/"]),
        runtime=runtime,
    )
    r.start()
    r.join()


def _upgrade_status(port: int, origin: str | None) -> bytes:
    import base64
    import os

    key = base64.b64encode(os.urandom(16)).decode()
    request = (
        "GET / HTTP/1.1\r\n"
        f"Host: {HOST}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        + (f"Origin: {origin}\r\n" if origin is not None else "")
        + "Sec-WebSocket-Version: 13\r\n\r\n"
    )
    with socket.create_connection((HOST, port), timeout=10) as sock:
        sock.sendall(request.encode())
        response = b""
        while b"\r\n" not in response:
            chunk = sock.recv(1024)
            if not chunk:
                break
            response += chunk
    return response.split(b"\r\n", 1)[0]


@pytest.fixture
def origin_router(free_port):
    proc = mp.Process(target=_proc_origin_router, args=(active_runtime(), free_port), daemon=True)
    proc.start()
    wait_for_port(free_port)
    yield free_port
    quiet_kill(proc)


@pytest.mark.parametrize(
    "origin, allowed",
    [
        (APP_ORIGIN, True),
        ("HTTPS://APP.EXAMPLE", True),
        ("https://evil.example", False),
        ("https://app.example.evil", False),
        (None, False),
    ],
)
def test_websocket_origin_allow_list(origin_router, origin, allowed):
    status = _upgrade_status(origin_router, origin)
    assert (b" 101 " in status) is allowed, status
    if not allowed:
        assert b" 403 " in status, status


def test_origin_allow_list_does_not_affect_native_clients(origin_router):
    with _client(origin_router, "origin-native"):
        wait_for_members(origin_router, {"origin-native"})


def test_allowed_origins_is_validated():
    from daffi import TCPTransport
    from daffi.exceptions import InitializationError

    for bad in ("https://app.example", [], ["https://a\r\nX: y"], [""], [1]):
        with pytest.raises(InitializationError):
            TCPTransport(HOST, 1, allowed_origins=bad)
    assert TCPTransport(HOST, 1).native_listener()[-1] == ""
    assert TCPTransport(HOST, 1, allowed_origins=["https://a", "https://b/"]).native_listener()[-1] == "https://a\nhttps://b"


# ── 6. a half-sent message does not hold the connection forever ───────────────


def _wait_closed(sock: socket.socket, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        sock.settimeout(max(0.05, deadline - time.monotonic()))
        try:
            if not sock.recv(65536):
                return True
        except socket.timeout:
            return False
        except OSError:
            return True
    return False


def test_stalled_half_sent_message_closes_only_that_connection(free_port, monkeypatch):
    monkeypatch.setenv("DAFFI_FRAME_STALL_MS", "1000")
    proc = _start(_proc_slow_service, free_port, SLOW)
    idle = RawPeer(free_port, "idle-peer")
    staller = RawPeer(free_port, "stall-peer")
    try:
        idle.read_reply(1)
        staller.read_reply(1)
        metadata = f"stall-peer|{SLOW}|sink".encode()
        body = metadata + b"x" * (1024 * 1024)
        header = pack_header(
            uuid=5, flag=FLAG_REQUEST, decoder=JSON, msg_len=len(body), metadata_len=len(metadata)
        )
        staller.sock.sendall(header + body[: 200 * 1024])

        started = time.monotonic()
        assert _wait_closed(staller.sock, 10), "the stalled connection stayed open"
        assert time.monotonic() - started >= 0.9

        time.sleep(2)  # an idle connection with no message in progress is left alone
        idle.send(uuid=7, flag=FLAG_REQUEST, receiver=SLOW, func="add", data=_json(1, 2), return_result=True)
        flag, data = idle.read_reply(7)
        assert flag == FLAG_RESPONSE
    finally:
        idle.close()
        staller.close()
        quiet_kill(proc)


# ── 7. auth_token ─────────────────────────────────────────────────────────────

TOKEN = "s3cret-token"


def _proc_token_service(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Service, TCPTransport

    _register_callbacks()
    svc = Service(app_name=SLOW, transport=TCPTransport(HOST, port), runtime=runtime, auth_token=TOKEN)
    svc.start()
    svc.join()


def _proc_token_router(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Router, TCPTransport

    r = Router(app_name="token-router", transport=TCPTransport(HOST, port), runtime=runtime, auth_token=TOKEN)
    r.start()
    r.join()


def _proc_token_worker(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Client, TCPTransport

    _register_callbacks()
    client = Client(app_name=SLOW, transport=TCPTransport(HOST, port), runtime=runtime, auth_token=TOKEN)
    client.connect()
    client.join()


@pytest.fixture(params=["service", "router"])
def token_node(request, free_port):
    procs = []
    if request.param == "service":
        procs.append(mp.Process(target=_proc_token_service, args=(active_runtime(), free_port), daemon=True))
    else:
        procs.append(mp.Process(target=_proc_token_router, args=(active_runtime(), free_port), daemon=True))
    procs[0].start()
    wait_for_port(free_port)
    if request.param == "router":
        procs.append(mp.Process(target=_proc_token_worker, args=(active_runtime(), free_port), daemon=True))
        procs[1].start()
    yield free_port
    for proc in procs:
        quiet_kill(proc)


def _token_client(port: int, name: str, token):
    from daffi import Client, TCPTransport

    return Client(app_name=name, transport=TCPTransport(HOST, port), runtime=active_runtime(), auth_token=token)


def test_client_with_the_token_is_served(token_node):
    client = _token_client(token_node, "token-ok", TOKEN)
    conn = client.connect()
    try:
        conn.wait_for_members(SLOW, timeout=15)
        assert conn.rpc(timeout=10).add(2, 3) == 5
    finally:
        client.stop()


@pytest.mark.parametrize("token", [None, "wrong", TOKEN + "x"])
def test_client_without_the_token_is_refused(token_node, token):
    from daffi.exceptions import InitializationError

    client = _token_client(token_node, "token-bad", token)
    with pytest.raises(InitializationError, match="Unauthorized"):
        client.connect()
    client.stop()


def test_refused_peer_cannot_call_or_take_over_a_name(token_node):
    """Without the token a peer is never registered: its requests are
    refused, and handshaking under a member's name does not evict it."""
    good = _token_client(token_node, "token-member", TOKEN)
    conn = good.connect()
    try:
        conn.wait_for_members(SLOW, timeout=15)
        peer = RawPeer(token_node, "token-member")
        try:
            flag, data = peer.read_reply(1)
            assert b"Unauthorized" in data
            assert _wait_closed(peer.sock, 5), "the refused connection stayed open"
        finally:
            peer.close()
        assert conn.rpc(timeout=10).add(1, 1) == 2
    finally:
        good.stop()


def test_async_client_sends_the_token(token_node):
    from daffi import TCPTransport
    from daffi.aio import AsyncClient

    async def main():
        client = AsyncClient(
            app_name="token-async", transport=TCPTransport(HOST, token_node),
            runtime=active_runtime(), auth_token=TOKEN,
        )
        conn = await client.connect()
        try:
            await conn.wait_for_members(SLOW, timeout=15)
            assert await conn.rpc(timeout=10).add(4, 4) == 8
        finally:
            await client.stop()

    import asyncio

    asyncio.run(main())


def test_auth_token_is_validated():
    from daffi import Client, TCPTransport
    from daffi.exceptions import InitializationError

    for bad in ("", 123, b"bytes", "a\0b"):
        with pytest.raises(InitializationError):
            Client(app_name="x", transport=TCPTransport(HOST, 1), auth_token=bad)


# ── 8. callbacks= offers only the listed callbacks ────────────────────────────

ONLY_ADD = "only-add"


def _proc_only_add_service(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Service, TCPTransport

    _register_callbacks()
    svc = Service(app_name=ONLY_ADD, transport=TCPTransport(HOST, port), runtime=runtime, callbacks=["add"])
    svc.start()
    svc.join()


def _proc_only_add_worker(runtime: str, port: int) -> None:
    silence_subprocess(runtime)
    from daffi import Client, TCPTransport

    _register_callbacks()
    from daffi.registry._executor_registry import EXECUTOR_REGISTRY

    add = EXECUTOR_REGISTRY.get("add").func
    client = Client(app_name=ONLY_ADD, transport=TCPTransport(HOST, port), runtime=runtime, callbacks=[add])
    client.connect()
    client.join()


@pytest.fixture(params=["service", "router"])
def only_add(request, free_port):
    if request.param == "service":
        procs = [_start(_proc_only_add_service, free_port, ONLY_ADD)]
    else:
        procs = [_start(proc_router, free_port), _start(_proc_only_add_worker, free_port)]
        wait_for_members(free_port, {ONLY_ADD})
    yield free_port
    for proc in procs:
        quiet_kill(proc)


def test_only_the_listed_callbacks_are_offered(only_add):
    with _client(only_add, "only-add-caller", ONLY_ADD) as (_, conn):
        assert conn.rpc(timeout=10).add(2, 2) == 4

    peer = RawPeer(only_add, "only-add-raw")
    try:
        peer.read_reply(1)
        peer.send(uuid=9, flag=FLAG_REQUEST, receiver=ONLY_ADD, func="slow", data=_json("x", 0), return_result=True)
        flag, data = peer.read_reply(9)
        assert flag == FLAG_ERROR
        # The Service refuses it itself; the Router already knows the worker
        # never announced it.
        assert b"is not registered" in data or b"ReceiverNotFound" in data
    finally:
        peer.close()


def test_callbacks_is_validated():
    from daffi import Client, TCPTransport
    from daffi.exceptions import InitializationError

    for bad in ("add", [1], [""], 5):
        with pytest.raises(InitializationError):
            Client(app_name="x", transport=TCPTransport(HOST, 1), callbacks=bad)


# ── 9. rpc(receiver=[...]) goes to one of the listed workers ──────────────────

LISTED = ("listed-a", "listed-b")


def _proc_named_worker(runtime: str, port: int, name: str) -> None:
    silence_subprocess(runtime)
    from daffi import Client, TCPTransport, callback

    @callback
    def whoami():
        return name

    client = Client(app_name=name, transport=TCPTransport(HOST, port), runtime=runtime)
    client.connect()
    client.join()


@pytest.fixture
def listed_workers(free_port):
    procs = [_start(proc_router, free_port)]
    for name in LISTED:
        proc = mp.Process(target=_proc_named_worker, args=(active_runtime(), free_port, name), daemon=True)
        proc.start()
        procs.append(proc)
    wait_for_members(free_port, set(LISTED))
    yield free_port
    for proc in procs:
        quiet_kill(proc)


def test_rpc_to_a_list_of_receivers(listed_workers):
    from daffi.exceptions import TransmissionFailure

    with _client(listed_workers, "list-caller", *LISTED) as (_, conn):
        both = conn.rpc(timeout=10, receiver=list(LISTED))
        assert {both.whoami() for _ in range(4)} == set(LISTED)

        some_gone = conn.rpc(timeout=10, receiver=["listed-gone", "listed-b"])
        assert {some_gone.whoami() for _ in range(4)} == {"listed-b"}
        conn.rpc_nowait(receiver=["listed-gone", "listed-a"]).whoami()

        with pytest.raises(TransmissionFailure):
            conn.rpc(timeout=10, receiver=["listed-gone"]).whoami()
        with pytest.raises(ValueError):
            conn.rpc(receiver=[])
        with pytest.raises(TypeError):
            conn.rpc(receiver=5)


def test_missing_members_names_only_the_absent_peers(listed_workers):
    from daffi import dfcore

    with _client(listed_workers, "member-checker", *LISTED) as (client, _):
        conn_num = client._conn_num
        assert dfcore.missingMembers(conn_num, {"listed-a", "listed-b"}) == []
        assert dfcore.missingMembers(conn_num, ["listed-a", "listed-gone"]) == ["listed-gone"]
        with pytest.raises(TypeError):
            dfcore.missingMembers(conn_num, [1])


def test_async_rpc_to_a_list_of_receivers(listed_workers):
    import asyncio

    from daffi import TCPTransport
    from daffi.aio import AsyncClient

    async def main():
        client = AsyncClient(app_name="list-async", transport=TCPTransport(HOST, listed_workers), runtime=active_runtime())
        conn = await client.connect()
        try:
            await conn.wait_for_members(*LISTED, timeout=15)
            both = conn.rpc(timeout=10, receiver=list(LISTED))
            assert {await both.whoami() for _ in range(4)} == set(LISTED)
            some_gone = conn.rpc(timeout=10, receiver=("listed-gone", "listed-a"))
            assert await some_gone.whoami() == "listed-a"
            await conn.rpc_nowait(receiver=["listed-gone", "listed-b"]).whoami()
        finally:
            await client.stop()

    asyncio.run(main())


# ── 10. a connect() the kernel refuses at once fails at once ──────────────────


def test_connect_refused_by_the_kernel_fails_at_once(runtime):
    from daffi import Client, TCPTransport
    from daffi.exceptions import InitializationError

    # TCP to a multicast address is refused by connect() itself; poll() on that
    # socket used to wait out the whole 15 s connect timeout.
    client = Client(app_name="multicast-caller", transport=TCPTransport("224.0.0.1", 80), runtime=runtime)
    start = time.monotonic()
    with pytest.raises(InitializationError) as info:
        client.connect()
    assert time.monotonic() - start < 5
    assert "timed out" not in str(info.value)


# ── 11. a TCP host that does not resolve is not a Unix socket path ────────────


def test_unresolvable_tcp_host_is_not_taken_for_a_socket_path(tmp_path, monkeypatch):
    from daffi import Client, Service, TCPTransport

    monkeypatch.chdir(tmp_path)
    host = "no-such-host.invalid"
    (tmp_path / host).write_text("keep me")

    service = Service(app_name="dns-svc", transport=TCPTransport(host, 4999), runtime=active_runtime())
    with pytest.raises(Exception):
        service.start()
    service.stop()
    assert (tmp_path / host).read_text() == "keep me"

    (tmp_path / host).unlink()
    client = Client(app_name="dns-client", transport=TCPTransport(host, 4999), runtime=active_runtime())
    with pytest.raises(Exception):
        client.connect()
    client.stop()
    assert not (tmp_path / host).exists()
