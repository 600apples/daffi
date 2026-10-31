"""
Regression tests for the robustness fixes in the native core.

1. Malformed input from an unauthenticated peer must never take a Service /
   Router down.  Wheels ship ``ReleaseSafe`` so any Zig panic aborts the whole
   Python process; each payload below used to do exactly that (or, for the
   oversized ones, allocate attacker-chosen amounts of memory).
2. Disconnected peers must release their socket (no ``CLOSE_WAIT`` pile-up).
3. ``stop()`` on a server must return, release the port, and be re-startable.
"""

from __future__ import annotations
from tests.conftest import active_runtime

import base64
import multiprocessing as mp
import os
import shutil
import socket
import struct
import subprocess
import time

import pytest

from .conftest import (
    HOST,
    quiet_kill,
    silence_subprocess,
    wait_for_members,
    wait_for_port,
    proc_router,
    proc_service,
)

# ── wire helpers ──────────────────────────────────────────────────────────────

NATIVE_LITTLE = 1  # std.builtin.Endian.little


def pack_header(
    *,
    uuid: int = 1,
    flag: int = 0,
    decoder: int = 0,
    is_bytes: int = 0,
    return_result: int = 0,
    msg_len: int = 0,
    metadata_len: int = 0,
    msg_parts: int = 1,
    endian: int = NATIVE_LITTLE,
) -> bytes:
    """Build the 9-byte packed ``Header`` (LSB-first bit layout)."""
    v = uuid
    v |= flag << 16
    v |= decoder << 20
    v |= is_bytes << 22
    v |= return_result << 23
    v |= msg_len << 24
    v |= metadata_len << 49
    v |= msg_parts << 64
    v |= endian << 71
    return v.to_bytes(9, "little")


def ws_upgrade_request() -> bytes:
    key = base64.b64encode(os.urandom(16)).decode()
    return (
        "GET / HTTP/1.1\r\n"
        f"Host: {HOST}\r\n"
        "Origin: http://localhost\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    ).encode()


def ws_frame_header(payload_len_field: bytes, first: int = 0x82) -> bytes:
    # FIN+binary, MASK bit set, (extended) length, 4-byte mask key.
    return bytes([first]) + payload_len_field + b"\x00\x00\x00\x00"


MALFORMED: dict[str, bytes] = {
    "garbage_3_bytes": b"\xff\xff\xff",
    "all_zero_header": b"\x00" * 9,
    "all_ones_header": b"\xff" * 9,
    "flag_out_of_range": pack_header(flag=15, msg_len=3, metadata_len=0) + b"abc",
    "wrong_endian": pack_header(endian=0, msg_len=3) + b"abc",
    "metadata_longer_than_msg": pack_header(msg_len=2, metadata_len=100) + b"ab",
    "metadata_without_separators": pack_header(msg_len=4, metadata_len=4) + b"abcd",
    "huge_claimed_msg_len": pack_header(msg_len=(1 << 25) - 1, metadata_len=0),
    "http_request_line_only": b"GET HTTP/1.1\r\n\r\n",
    "http_no_upgrade": b"GET / HTTP/1.1\r\nHost: x\r\n\r\n",
    "http_truncated": b"GET / HT",
    "ws_truncated_frame": ws_upgrade_request() + b"\x82",
    "ws_3_byte_frame": ws_upgrade_request() + b"\x82\x80\x00",
    "ws_huge_len_u64": ws_upgrade_request()
    + ws_frame_header(b"\xff" + struct.pack(">Q", 0xFFFFFFFFFFFFFFFF)),
    "ws_huge_len_u64_signed": ws_upgrade_request()
    + ws_frame_header(b"\xff" + struct.pack(">Q", 0x7FFFFFFFFFFFFFFF)),
}


def _poke(port: int, payload: bytes, *, linger: float = 0.15) -> None:
    """Send *payload*, give the server a moment to chew on it, hang up."""
    with socket.create_connection((HOST, port), timeout=2) as s:
        s.settimeout(0.5)
        try:
            s.sendall(payload)
        except OSError:
            return
        time.sleep(linger)
        try:
            s.recv(4096)
        except (socket.timeout, OSError):
            pass


# ── fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture
def service_proc(free_port):
    proc = mp.Process(target=proc_service, args=(active_runtime(), free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"integ-service"})
    yield proc, free_port
    quiet_kill(proc)


@pytest.fixture
def router_proc(free_port):
    proc = mp.Process(target=proc_router, args=(active_runtime(), free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    yield proc, free_port
    quiet_kill(proc)


# ── 1. malformed input ────────────────────────────────────────────────────────


@pytest.mark.parametrize("name", sorted(MALFORMED))
def test_service_survives_malformed_input(service_proc, name):
    proc, port = service_proc
    _poke(port, MALFORMED[name])
    assert proc.is_alive(), f"Service died on {name!r} (exit {proc.exitcode})"


@pytest.mark.parametrize("name", sorted(MALFORMED))
def test_router_survives_malformed_input(router_proc, name):
    proc, port = router_proc
    _poke(port, MALFORMED[name])
    assert proc.is_alive(), f"Router died on {name!r} (exit {proc.exitcode})"


def test_service_still_serves_after_all_malformed_input(service_proc):
    from daffi import Client, TCPTransport

    proc, port = service_proc
    for payload in MALFORMED.values():
        _poke(port, payload, linger=0.02)
    assert proc.is_alive()

    client = Client(app_name="after-garbage", transport=TCPTransport(HOST, port), runtime=active_runtime())
    conn = client.connect()
    try:
        conn.wait_for_members("integ-service", timeout=10)
        assert conn.rpc(timeout=10).add(2, 3) == 5
    finally:
        client.stop()


def test_silent_peer_does_not_block_accept(service_proc):
    """A peer that connects and sends nothing must not stall other peers."""
    from daffi import Client, TCPTransport

    _, port = service_proc
    silent = [socket.create_connection((HOST, port)) for _ in range(5)]
    try:
        t0 = time.monotonic()
        client = Client(app_name="behind-silent", transport=TCPTransport(HOST, port), runtime=active_runtime())
        conn = client.connect()
        try:
            conn.wait_for_members("integ-service", timeout=10)
            assert conn.rpc(timeout=10).add(1, 1) == 2
        finally:
            client.stop()
        assert time.monotonic() - t0 < 10
    finally:
        for s in silent:
            s.close()


# ── 2. socket / fd leak ───────────────────────────────────────────────────────


def _close_wait_count(pid: int) -> int:
    out = subprocess.run(
        ["lsof", "-nP", "-a", "-p", str(pid), "-iTCP"],
        capture_output=True,
        text=True,
        timeout=20,
    ).stdout
    return sum(1 for line in out.splitlines() if "CLOSE_WAIT" in line)


def _open_fd_count(pid: int) -> int:
    out = subprocess.run(
        ["lsof", "-nP", "-p", str(pid)], capture_output=True, text=True, timeout=20
    ).stdout
    return max(0, len(out.splitlines()) - 1)


@pytest.mark.skipif(shutil.which("lsof") is None, reason="lsof not available")
def test_disconnected_clients_do_not_leak_sockets(service_proc):
    from daffi import Client, TCPTransport

    proc, port = service_proc
    baseline = _open_fd_count(proc.pid)

    for i in range(15):
        client = Client(app_name=f"leak-probe-{i}", transport=TCPTransport(HOST, port), runtime=active_runtime())
        conn = client.connect()
        conn.wait_for_members("integ-service", timeout=10)
        client.stop()

    # Raw connections that just hang up must be released too.
    for _ in range(15):
        _poke(port, b"\x00" * 9, linger=0.0)

    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if (
            _close_wait_count(proc.pid) == 0
            and _open_fd_count(proc.pid) <= baseline + 3
        ):
            break
        time.sleep(0.25)

    assert _close_wait_count(proc.pid) == 0, "sockets stuck in CLOSE_WAIT"
    assert _open_fd_count(proc.pid) <= baseline + 3, "file descriptors leaked"
    assert proc.is_alive()


# ── 3. stop() ─────────────────────────────────────────────────────────────────


def _stop_restart_target(runtime: str, port: int, q) -> None:
    silence_subprocess(runtime)
    import threading

    from daffi import Router, Service, callback, TCPTransport

    @callback
    def ping():
        return "pong"

    try:
        for _ in range(2):  # second round proves the port was released
            svc = Service(
                app_name="stop-svc", workers=2, transport=TCPTransport(HOST, port),
                runtime=runtime,
            )
            svc.start()
            done = threading.Event()

            def _stop():
                svc.stop()
                svc.stop()  # idempotent
                done.set()

            threading.Thread(target=_stop, daemon=True).start()
            if not done.wait(15):
                q.put("service stop() hung")
                return

        for _ in range(2):
            r = Router(app_name="stop-router", transport=TCPTransport(HOST, port), runtime=runtime)
            r.start()
            done = threading.Event()

            def _stop_r():
                r.stop()
                done.set()

            threading.Thread(target=_stop_r, daemon=True).start()
            if not done.wait(15):
                q.put("router stop() hung")
                return
        q.put("ok")
    except BaseException as exc:  # noqa: BLE001
        q.put(f"{type(exc).__name__}: {exc}")


def test_server_stop_returns_and_releases_port(free_port):
    q = mp.Queue()
    proc = mp.Process(target=_stop_restart_target, args=(active_runtime(), free_port, q), daemon=True)
    proc.start()
    try:
        result = q.get(timeout=90)
    finally:
        quiet_kill(proc, timeout=5)
    assert result == "ok", result


def test_server_stop_with_connected_client(free_port):
    """stop() must also tear down live connections instead of waiting on them."""
    from daffi import Client, TCPTransport

    proc = mp.Process(target=proc_service, args=(active_runtime(), free_port,), daemon=True)
    proc.start()
    try:
        wait_for_port(free_port)
        wait_for_members(free_port, {"integ-service"})
        client = Client(app_name="stop-victim", transport=TCPTransport(HOST, free_port), runtime=active_runtime())
        conn = client.connect()
        conn.wait_for_members("integ-service", timeout=10)
        proc.terminate()  # SIGTERM -> native handler / atexit stop
        proc.join(10)
        assert not proc.is_alive(), "server did not shut down on SIGTERM"
        client.stop()
    finally:
        quiet_kill(proc)
