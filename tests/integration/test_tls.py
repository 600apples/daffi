"""
TLS transport tests.

The native TLS layer was reworked to (a) serialise access to each ``SSL*``
(OpenSSL sessions are not thread-safe), (b) bound the handshake so silent peers
cannot stall the accept loop, (c) verify the server certificate *and* host
name, and (d) refuse a server that asks for TLS without a certificate.
"""

from __future__ import annotations

import multiprocessing as mp
import shutil
import socket
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor

import pytest

from .conftest import HOST, TIMEOUT, quiet_kill, silence_subprocess, wait_for_port

OPENSSL = shutil.which("openssl")
pytestmark = pytest.mark.skipif(OPENSSL is None, reason="openssl CLI not available")


# ── certificates ──────────────────────────────────────────────────────────────


def _make_cert(directory, name: str, san: str):
    cert = directory / f"{name}.crt"
    key = directory / f"{name}.key"
    subprocess.run(
        [
            OPENSSL,
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(key),
            "-out",
            str(cert),
            "-days",
            "2",
            "-subj",
            "/CN=daffi-test",
            "-addext",
            f"subjectAltName={san}",
        ],
        check=True,
        capture_output=True,
        timeout=60,
    )
    return str(cert), str(key)


@pytest.fixture(scope="module")
def certs(tmp_path_factory):
    d = tmp_path_factory.mktemp("tls")
    try:
        good = _make_cert(d, "good", "DNS:localhost,IP:127.0.0.1")
        other = _make_cert(d, "other", "DNS:localhost,IP:127.0.0.1")  # different CA
        wrong_host = _make_cert(d, "wronghost", "DNS:not-this-host.example")
    except subprocess.CalledProcessError as exc:  # e.g. LibreSSL without -addext
        pytest.skip(f"cannot generate test certificates: {exc.stderr[:200]!r}")
    return {"good": good, "other": other, "wrong_host": wrong_host}


# ── subprocess servers ────────────────────────────────────────────────────────


def _tls_service(port: int, cert: str, key: str) -> None:
    silence_subprocess()
    from daffi import Service, callback, TCPTransport

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    svc = Service(
        app_name="tls-service",
        workers=4,
        tls=True,
        cert_file=cert,
        key_file=key,
        transports=TCPTransport(HOST, port),
    )
    svc.start()
    svc.join()


def _tls_service_without_cert(port: int, q) -> None:
    silence_subprocess()
    from daffi import Service, TCPTransport

    try:
        Service(
            app_name="tls-nocert", tls=True, transports=TCPTransport(HOST, port)
        ).start()
        q.put("started")
    except BaseException as exc:  # noqa: BLE001
        q.put(f"error:{type(exc).__name__}")


def _start(port, cert, key):
    proc = mp.Process(target=_tls_service, args=(port, cert, key), daemon=True)
    proc.start()
    wait_for_port(port)
    return proc


@pytest.fixture
def tls_service(free_port, certs):
    cert, key = certs["good"]
    proc = _start(free_port, cert, key)
    yield proc, free_port, cert
    quiet_kill(proc)


def _connect(port, ca_file, name="tls-client"):
    from daffi import Client, TCPTransport

    client = Client(
        app_name=name, tls=True, ca_file=ca_file, transport=TCPTransport(HOST, port)
    )
    conn = client.connect()
    return client, conn


# ── tests ─────────────────────────────────────────────────────────────────────


def test_tls_round_trip(tls_service):
    _, port, ca = tls_service
    client, conn = _connect(port, ca)
    try:
        conn.wait_for_members("tls-service", timeout=15)
        rpc = conn.rpc(timeout=TIMEOUT)
        assert rpc.add(20, 22) == 42
        assert rpc.echo("héllo") == "héllo"
    finally:
        client.stop()


def test_tls_large_payload(tls_service):
    """Exercises the non-blocking read/write + poll loops with partial writes."""
    _, port, ca = tls_service
    client, conn = _connect(port, ca)
    try:
        conn.wait_for_members("tls-service", timeout=15)
        blob = b"x" * (4 * 1024 * 1024)
        assert conn.rpc(timeout=TIMEOUT).echo(blob) == blob
    finally:
        client.stop()


def test_tls_concurrent_calls_share_one_session(tls_service):
    """Many threads on a single client => concurrent SSL_read/SSL_write on one
    connection.  Before the per-session mutex this corrupted the SSL state."""
    _, port, ca = tls_service
    client, conn = _connect(port, ca)
    try:
        conn.wait_for_members("tls-service", timeout=15)
        rpc = conn.rpc(timeout=TIMEOUT)

        def work(i):
            return [rpc.add(i, j) for j in range(40)] == [i + j for j in range(40)]

        with ThreadPoolExecutor(8) as pool:
            assert all(pool.map(work, range(8)))
    finally:
        client.stop()


def test_tls_many_clients_connect_and_leave(tls_service):
    _, port, ca = tls_service
    for i in range(10):
        client, conn = _connect(port, ca, name=f"tls-churn-{i}")
        try:
            conn.wait_for_members("tls-service", timeout=15)
        finally:
            client.stop()
    client, conn = _connect(port, ca)
    try:
        conn.wait_for_members("tls-service", timeout=15)
        assert conn.rpc(timeout=TIMEOUT).add(1, 2) == 3
    finally:
        client.stop()


def test_client_rejects_untrusted_certificate(tls_service, certs):
    _, port, _ = tls_service
    other_ca = certs["other"][0]
    with pytest.raises(Exception):
        client, conn = _connect(port, other_ca, name="tls-untrusted")
        client.stop()


def test_client_rejects_certificate_for_other_host(free_port, certs):
    cert, key = certs["wrong_host"]
    proc = _start(free_port, cert, key)
    try:
        with pytest.raises(Exception):
            client, conn = _connect(free_port, cert, name="tls-wronghost")
            client.stop()
    finally:
        quiet_kill(proc)


def test_plaintext_and_garbage_do_not_hurt_tls_server(tls_service):
    proc, port, ca = tls_service

    for payload in (
        b"GET / HTTP/1.1\r\n\r\n",
        b"\x16\x03\x01\x00\x05garbage",
        b"\x00" * 64,
    ):
        with socket.create_connection((HOST, port), timeout=2) as s:
            s.settimeout(0.5)
            s.sendall(payload)
            time.sleep(0.1)
            try:
                s.recv(1024)
            except (socket.timeout, OSError):
                pass
    assert proc.is_alive()

    # a peer that connects and never speaks must not stall the next TLS client
    silent = [socket.create_connection((HOST, port)) for _ in range(3)]
    try:
        t0 = time.monotonic()
        client, conn = _connect(port, ca, name="tls-behind-silent")
        try:
            conn.wait_for_members("tls-service", timeout=15)
            assert conn.rpc(timeout=TIMEOUT).add(2, 2) == 4
        finally:
            client.stop()
        assert time.monotonic() - t0 < 12
    finally:
        for s in silent:
            s.close()
    assert proc.is_alive()


def test_server_tls_without_certificate_is_an_error(free_port):
    q = mp.Queue()
    proc = mp.Process(
        target=_tls_service_without_cert, args=(free_port, q), daemon=True
    )
    proc.start()
    try:
        result = q.get(timeout=30)
    finally:
        quiet_kill(proc)
    assert result.startswith("error:"), result
