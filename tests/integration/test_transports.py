"""
Several transports on one Router or Service.

Every listener belongs to the same node.  A client that arrives on one
transport must be able to call a worker that connected on another.
"""

from __future__ import annotations

import asyncio
import multiprocessing as mp
import os
import shutil
import socket
import subprocess
import sys
import time

import pytest

from daffi.exceptions import InitializationError

from .conftest import HOST, TIMEOUT, quiet_kill, silence_subprocess, wait_for_port

pytestmark = pytest.mark.skipif(
    sys.platform == "win32", reason="Unix transports are POSIX-only"
)

OPENSSL = shutil.which("openssl")


def _port() -> int:
    with socket.socket() as sock:
        sock.bind((HOST, 0))
        return sock.getsockname()[1]


def _sock(name: str) -> str:
    path = os.path.join(
        "/tmp", f"dfm{os.getpid()}-{time.monotonic_ns() % 10**9}-{name}.sock"
    )
    assert len(path) < 100
    return path


def _wait_unix(path: str, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if os.path.exists(path):
            return
        time.sleep(0.05)
    raise TimeoutError(path)


def _wait_spec(spec) -> None:
    for kind, host, port in spec:
        if kind == "tcp":
            wait_for_port(port)
        else:
            _wait_unix(host)


def _materialize(spec, *, bare: bool = False):
    from daffi import TCPTransport, UnixTransport

    items = []
    for kind, host, port in spec:
        if kind == "tcp":
            items.append(TCPTransport(host, port))
        else:
            items.append(UnixTransport(host))
    if bare:
        return items[0]
    return items


def _callbacks():
    from daffi import callback

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    @callback
    def who():
        return os.environ["DAFFI_WHO"]


def _service_proc(spec, app_name: str, bare: bool, tls: tuple | None) -> None:
    silence_subprocess()
    os.environ["DAFFI_WHO"] = app_name
    from daffi import Service

    _callbacks()
    kwargs = {}
    if tls is not None:
        kwargs = {"tls": True, "cert_file": tls[0], "key_file": tls[1]}
    svc = Service(
        app_name=app_name,
        transports=_materialize(spec, bare=bare),
        workers=2,
        **kwargs,
    )
    svc.start()
    svc.join()


def _router_proc(spec, app_name: str) -> None:
    silence_subprocess()
    from daffi import Router

    router = Router(app_name=app_name, transports=_materialize(spec))
    router.start()
    router.join()


def _async_service_proc(spec, app_name: str) -> None:
    silence_subprocess()
    os.environ["DAFFI_WHO"] = app_name

    async def main():
        from daffi.aio import AsyncService

        _callbacks()
        svc = AsyncService(
            app_name=app_name,
            transports=_materialize(spec),
            workers=2,
        )
        await svc.start()
        await svc.join()

    asyncio.run(main())


def _async_router_proc(spec, app_name: str) -> None:
    silence_subprocess()

    async def main():
        from daffi.aio import AsyncRouter

        router = AsyncRouter(app_name=app_name, transports=_materialize(spec))
        await router.start()
        await router.join()

    asyncio.run(main())


def _router_until(spec, started, stop) -> None:
    silence_subprocess()
    from daffi import Router

    router = Router(app_name="rt-until", transports=_materialize(spec))
    router.start()
    started.set()
    stop.wait()
    router.stop()


def _worker_proc(endpoint, app_name: str, tls_ca: str | None) -> None:
    silence_subprocess()
    os.environ["DAFFI_WHO"] = app_name
    from daffi import Client

    _callbacks()
    kwargs = {"tls": True, "ca_file": tls_ca} if tls_ca else {}
    client = Client(
        app_name=app_name,
        transport=_materialize([endpoint], bare=True),
        workers=2,
        **kwargs,
    )
    client.connect()
    while True:
        time.sleep(0.5)


def _spawn(target, args):
    proc = mp.Process(target=target, args=args, daemon=True)
    proc.start()
    return proc


def _rpc(
    endpoint,
    receiver: str,
    fn: str,
    *args,
    tls_ca: str | None = None,
    app_name: str = "caller",
):
    from daffi import Client

    kwargs = {"tls": True, "ca_file": tls_ca} if tls_ca else {}
    client = Client(
        app_name=app_name,
        transport=_materialize([endpoint], bare=True),
        **kwargs,
    )
    conn = client.connect()
    try:
        conn.wait_for_members(receiver, timeout=20)
        return getattr(conn.rpc(timeout=TIMEOUT, receiver=receiver), fn)(*args)
    finally:
        client.stop()


def _tcp(port: int):
    return ("tcp", HOST, port)


def _unix(path: str):
    return ("unix", path, 0)


class TestConstruction:
    def test_single_transport_is_not_wrapped(self):
        from daffi import Router, TCPTransport, UnixTransport

        tcp = TCPTransport(HOST, 1)
        router = Router(app_name="one-tcp", transports=tcp)
        assert router.transports == [tcp]

        path = "/tmp/daffi-annotation.sock"
        unix = UnixTransport(path)
        router = Router(app_name="one-unix", transports=unix)
        assert router.transports == [unix]

    def test_list_and_tuple_are_sequences(self):
        from daffi import Service, TCPTransport

        a, b = TCPTransport(HOST, 2), TCPTransport(HOST, 3)
        svc = Service(app_name="seq", transports=(a, b))
        assert [t.port for t in svc.transports] == [2, 3]
        assert "tcp://127.0.0.1:2" in svc.info and "tcp://127.0.0.1:3" in svc.info

    def test_empty_sequence_is_rejected(self):
        from daffi import Router

        with pytest.raises(InitializationError):
            Router(transports=[])

    def test_a_string_is_not_a_sequence_of_transports(self):
        from daffi import Service

        with pytest.raises(InitializationError):
            Service(transports="/tmp/daffi.sock")

    def test_unknown_item_is_rejected(self):
        from daffi import Router, TCPTransport

        with pytest.raises(InitializationError):
            Router(transports=[TCPTransport(HOST, 1), object()])

    def test_client_takes_one_transport(self):
        from daffi import Client, Router, TCPTransport, UnixTransport

        tcp = TCPTransport(HOST, 1)
        client = Client(app_name="one", transport=tcp)
        assert client.transport is tcp

        with pytest.raises(TypeError):
            Client(app_name="named-wrong", transports=tcp)
        with pytest.raises(InitializationError):
            Client(transport=[tcp, UnixTransport("/tmp/daffi-client.sock")])
        with pytest.raises(TypeError):
            Router(transport=tcp)

    def test_bad_port_is_rejected(self):
        from daffi import TCPTransport

        with pytest.raises(InitializationError):
            TCPTransport(HOST, 70000)
        with pytest.raises(InitializationError):
            TCPTransport(HOST, True)
        with pytest.raises(InitializationError):
            TCPTransport("", 1)


class TestServiceManyTransports:
    def test_bare_tcp_transport(self):
        port = _port()
        spec = [_tcp(port)]
        proc = _spawn(_service_proc, (spec, "svc-bare-tcp", True, None))
        try:
            _wait_spec(spec)
            assert _rpc(_tcp(port), "svc-bare-tcp", "add", 20, 22) == 42
        finally:
            quiet_kill(proc)

    def test_bare_unix_transport(self):
        path = _sock("bare")
        spec = [_unix(path)]
        proc = _spawn(_service_proc, (spec, "svc-bare-unix", True, None))
        try:
            _wait_spec(spec)
            assert _rpc(_unix(path), "svc-bare-unix", "echo", "ok") == "ok"
        finally:
            quiet_kill(proc)

    def test_tcp_and_unix_from_each_side(self):
        port = _port()
        path = _sock("svc")
        spec = [_tcp(port), _unix(path)]
        proc = _spawn(_service_proc, (spec, "svc-mix", False, None))
        try:
            _wait_spec(spec)
            assert _rpc(_tcp(port), "svc-mix", "add", 2, 3, app_name="c-tcp") == 5
            assert _rpc(_unix(path), "svc-mix", "who", app_name="c-unix") == "svc-mix"
        finally:
            quiet_kill(proc)

    def test_two_tcp_ports(self):
        a, b = _port(), _port()
        spec = [_tcp(a), _tcp(b)]
        proc = _spawn(_service_proc, (spec, "svc-2tcp", False, None))
        try:
            _wait_spec(spec)
            assert _rpc(_tcp(b), "svc-2tcp", "echo", b"xyz", app_name="c-b") == b"xyz"
            assert _rpc(_tcp(a), "svc-2tcp", "add", 1, 1, app_name="c-a") == 2
        finally:
            quiet_kill(proc)

    def test_two_unix_sockets(self):
        first, second = _sock("u1"), _sock("u2")
        spec = [_unix(first), _unix(second)]
        proc = _spawn(_service_proc, (spec, "svc-2ux", False, None))
        try:
            _wait_spec(spec)
            assert _rpc(_unix(second), "svc-2ux", "add", 8, 9, app_name="c2") == 17
            assert _rpc(_unix(first), "svc-2ux", "echo", [1, 2], app_name="c1") == [
                1,
                2,
            ]
        finally:
            quiet_kill(proc)

    def test_three_transports_all_reach_the_service(self):
        a, b = _port(), _port()
        path = _sock("tri")
        spec = [_tcp(a), _tcp(b), _unix(path)]
        proc = _spawn(_service_proc, (spec, "svc-3", False, None))
        try:
            _wait_spec(spec)
            assert _rpc(_tcp(a), "svc-3", "who", app_name="ca") == "svc-3"
            assert _rpc(_tcp(b), "svc-3", "add", 4, 5, app_name="cb") == 9
            assert _rpc(_unix(path), "svc-3", "echo", {"k": 1}, app_name="cu") == {
                "k": 1
            }
        finally:
            quiet_kill(proc)


class TestRouterSharedMembership:
    def test_unix_client_calls_tcp_worker(self):
        port = _port()
        path = _sock("r1")
        spec = [_tcp(port), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-1"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_tcp(port), "worker-tcp", None))
            try:
                assert _rpc(_unix(path), "worker-tcp", "add", 10, 32) == 42
                assert (
                    _rpc(_unix(path), "worker-tcp", "echo", "from-unix") == "from-unix"
                )
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)

    def test_tcp_client_calls_unix_worker(self):
        port = _port()
        path = _sock("r2")
        spec = [_unix(path), _tcp(port)]
        router = _spawn(_router_proc, (spec, "router-2"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_unix(path), "worker-unix", None))
            try:
                assert _rpc(_tcp(port), "worker-unix", "who") == "worker-unix"
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)

    def test_two_tcp_ports_share_workers(self):
        a, b = _port(), _port()
        spec = [_tcp(a), _tcp(b)]
        router = _spawn(_router_proc, (spec, "router-ports"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_tcp(a), "worker-a", None))
            try:
                assert _rpc(_tcp(b), "worker-a", "add", 6, 7, app_name="client-b") == 13
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)

    def test_two_unix_sockets_share_workers(self):
        left, right = _sock("rl"), _sock("rr")
        spec = [_unix(left), _unix(right)]
        router = _spawn(_router_proc, (spec, "router-socks"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_unix(left), "worker-left", None))
            try:
                assert _rpc(_unix(right), "worker-left", "echo", "cross") == "cross"
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)

    def test_three_transports_both_clients_reach_one_worker(self):
        a, b = _port(), _port()
        path = _sock("r3")
        spec = [_tcp(a), _tcp(b), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-3"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_tcp(a), "worker-shared", None))
            try:
                assert _rpc(_tcp(b), "worker-shared", "add", 1, 2, app_name="on-b") == 3
                assert (
                    _rpc(_unix(path), "worker-shared", "who", app_name="on-unix")
                    == "worker-shared"
                )
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)

    def test_both_clients_at_once(self):
        port = _port()
        path = _sock("both")
        spec = [_tcp(port), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-both"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_tcp(port), "worker-both", None))
            try:
                from concurrent.futures import ThreadPoolExecutor

                with ThreadPoolExecutor(max_workers=2) as pool:
                    tcp = pool.submit(
                        _rpc,
                        _tcp(port),
                        "worker-both",
                        "add",
                        3,
                        4,
                        tls_ca=None,
                        app_name="sim-tcp",
                    )
                    unix = pool.submit(
                        _rpc,
                        _unix(path),
                        "worker-both",
                        "add",
                        5,
                        6,
                        tls_ca=None,
                        app_name="sim-unix",
                    )
                    assert tcp.result(timeout=40) == 7
                    assert unix.result(timeout=40) == 11
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)

    def test_stop_closes_every_listener(self):
        a, b = _port(), _port()
        path = _sock("stop")
        spec = [_tcp(a), _tcp(b), _unix(path)]
        started, stop = mp.Event(), mp.Event()
        proc = _spawn(_router_until, (spec, started, stop))
        try:
            assert started.wait(20)
            _wait_spec(spec)
            stop.set()
            proc.join(15)
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                try:
                    with socket.create_connection((HOST, b), timeout=0.2):
                        time.sleep(0.05)
                        continue
                except OSError:
                    break
            else:
                raise AssertionError("second TCP listener still accepts")
            with pytest.raises(OSError):
                socket.create_connection((HOST, a), timeout=0.3)
            with pytest.raises(OSError):
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                try:
                    sock.settimeout(0.3)
                    sock.connect(path)
                finally:
                    sock.close()
        finally:
            stop.set()
            quiet_kill(proc)


class TestAsync:
    def test_async_unix_client_calls_tcp_worker(self):
        port = _port()
        path = _sock("aio")
        spec = [_tcp(port), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-aio"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_tcp(port), "worker-aio", None))
            try:

                async def main():
                    from daffi import UnixTransport
                    from daffi.aio import AsyncClient

                    client = AsyncClient(
                        app_name="aio-caller",
                        transport=UnixTransport(path),
                    )
                    conn = await client.connect()
                    try:
                        await conn.wait_for_members("worker-aio", timeout=20)
                        assert (
                            await conn.rpc(timeout=TIMEOUT, receiver="worker-aio").add(
                                9, 8
                            )
                            == 17
                        )
                    finally:
                        await client.stop()

                asyncio.run(main())
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)

    def test_async_service_second_tcp_port(self):
        a, b = _port(), _port()
        spec = [_tcp(a), _tcp(b)]
        proc = _spawn(_service_proc, (spec, "svc-aio", False, None))
        try:
            _wait_spec(spec)

            async def main():
                from daffi import TCPTransport
                from daffi.aio import AsyncClient

                client = AsyncClient(
                    app_name="aio-svc", transport=TCPTransport(HOST, b)
                )
                conn = await client.connect()
                try:
                    await conn.wait_for_members("svc-aio", timeout=20)
                    assert await conn.rpc(timeout=TIMEOUT).echo("async") == "async"
                finally:
                    await client.stop()

            asyncio.run(main())
        finally:
            quiet_kill(proc)

    def test_async_service_binds_every_transport(self):
        port = _port()
        path = _sock("aio-svc")
        spec = [_tcp(port), _unix(path)]
        proc = _spawn(_async_service_proc, (spec, "svc-async-bind"))
        try:
            _wait_spec(spec)
            assert (
                _rpc(_unix(path), "svc-async-bind", "add", 4, 6, app_name="c-unix")
                == 10
            )
            assert (
                _rpc(_tcp(port), "svc-async-bind", "who", app_name="c-tcp")
                == "svc-async-bind"
            )
        finally:
            quiet_kill(proc)

    def test_async_router_shares_membership(self):
        a, b = _port(), _port()
        spec = [_tcp(a), _tcp(b)]
        router = _spawn(_async_router_proc, (spec, "router-async-bind"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_tcp(a), "worker-on-a", None))
            try:
                assert (
                    _rpc(_tcp(b), "worker-on-a", "echo", "via-b", app_name="client-b")
                    == "via-b"
                )
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)


@pytest.mark.skipif(OPENSSL is None, reason="openssl CLI not available")
class TestTlsOnEveryListener:
    def test_second_tcp_port_uses_the_node_certificate(self, tmp_path):
        cert = tmp_path / "good.crt"
        key = tmp_path / "good.key"
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
                "subjectAltName=DNS:localhost,IP:127.0.0.1",
            ],
            check=True,
            capture_output=True,
            timeout=60,
        )
        a, b = _port(), _port()
        spec = [_tcp(a), _tcp(b)]
        proc = _spawn(_service_proc, (spec, "svc-tls", False, (str(cert), str(key))))
        try:
            _wait_spec(spec)
            assert (
                _rpc(
                    _tcp(b),
                    "svc-tls",
                    "add",
                    11,
                    31,
                    tls_ca=str(cert),
                    app_name="tls-b",
                )
                == 42
            )
            assert (
                _rpc(
                    _tcp(a),
                    "svc-tls",
                    "echo",
                    "locked",
                    tls_ca=str(cert),
                    app_name="tls-a",
                )
                == "locked"
            )
        finally:
            quiet_kill(proc)
