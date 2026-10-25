"""
Several transports on one Router or Service.

Every listener belongs to the same node.  A client that arrives on one
transport must be able to call a worker that connected on another.  The node
binds all listeners together and gets one handle for them: either every
listener comes up or none stays bound, and stopping releases all of them.
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
import traceback

import pytest

from daffi.exceptions import InitializationError

from .conftest import HOST, TIMEOUT, quiet_kill, silence_subprocess, wait_for_port

pytestmark = pytest.mark.skipif(
    sys.platform == "win32", reason="Unix transports are POSIX-only"
)

OPENSSL = shutil.which("openssl")


# Ports already returned by _port().  Binding port 0 and closing the socket
# can hand that same port straight back (Linux does this), so two listeners
# in one spec would be the same address.
_issued_ports: set[int] = set()


def _port() -> int:
    """A TCP port this process has not already handed out, left unbound."""
    held: list[socket.socket] = []
    try:
        while True:
            sock = socket.socket()
            held.append(sock)
            sock.bind((HOST, 0))
            port = sock.getsockname()[1]
            if port not in _issued_ports:
                _issued_ports.add(port)
                return port
    finally:
        for sock in held:
            sock.close()


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

    @callback
    def sleepy(seconds: float) -> float:
        time.sleep(seconds)
        return seconds


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


def _caller_proc(endpoint, receiver: str, calling) -> None:
    """Keep one slow call in flight until killed."""
    silence_subprocess()
    from daffi import Client

    client = Client(app_name="doomed-caller", transport=_materialize([endpoint], bare=True))
    conn = client.connect()
    conn.wait_for_members(receiver, timeout=20)
    calling.set()
    while True:
        conn.rpc(timeout=TIMEOUT, receiver=receiver).sleepy(5)


def _tcp(port: int):
    return ("tcp", HOST, port)


def _unix(path: str):
    return ("unix", path, 0)


def _wait_accepts(endpoint, timeout: float = 5.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if _accepts(endpoint):
            return
        time.sleep(0.05)
    raise AssertionError(f"{endpoint} did not accept")


def _accepts(endpoint) -> bool:
    """True if something is listening on *endpoint*."""
    kind, host, port = endpoint
    family = socket.AF_INET if kind == "tcp" else socket.AF_UNIX
    sock = socket.socket(family, socket.SOCK_STREAM)
    try:
        sock.settimeout(1.0)
        sock.connect((host, port) if kind == "tcp" else host)
        return True
    except OSError:
        return False
    finally:
        sock.close()


def _tcp_port_is_free(port: int) -> bool:
    with socket.socket() as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind((HOST, port))
            sock.listen()
            return True
        except OSError:
            return False


def _released(endpoint) -> bool:
    """True once nothing holds *endpoint* any more."""
    if endpoint[0] == "tcp":
        return _tcp_port_is_free(endpoint[2])
    return not _accepts(endpoint)


def _members(conn) -> set[str]:
    from daffi._rpc_proxy import get_available_members

    return {m["name"] for m in get_available_members(conn.client._conn_num)}


def _wait_gone(conn, name: str, timeout: float = 20.0) -> None:
    deadline = time.monotonic() + timeout
    while name in _members(conn):
        if time.monotonic() > deadline:
            raise TimeoutError(f"{name} still listed as a member")
        time.sleep(0.1)


def _connect(endpoint, app_name: str):
    from daffi import Client

    client = Client(app_name=app_name, transport=_materialize([endpoint], bare=True))
    return client, client.connect()


def _isolated(target, *args, timeout: float = 90.0):
    """Run ``target(*args)`` in a fresh interpreter and return its result.

    Starting a node installs native SIGINT/SIGTERM handlers in its process, so
    nodes are never started inside the pytest process itself.
    """
    queue = mp.Queue()
    proc = mp.Process(target=_run_isolated, args=(queue, target, args), daemon=True)
    proc.start()
    try:
        ok, value = queue.get(timeout=timeout)
    finally:
        quiet_kill(proc)
    if not ok:
        pytest.fail(value, pytrace=False)
    return value


def _run_isolated(queue, target, args) -> None:
    silence_subprocess()
    try:
        queue.put((True, target(*args)))
    except BaseException:
        queue.put((False, traceback.format_exc()))


def _occupy(endpoint) -> socket.socket:
    """Hold *endpoint* so a node cannot bind it.  A Unix socket is made
    unbindable by pointing it into a directory that does not exist."""
    kind, host, port = endpoint
    assert kind == "tcp", "occupy Unix endpoints with _unbindable_unix()"
    sock = socket.socket()
    sock.bind((host, port))
    sock.listen()
    return sock


def _unbindable_unix() -> tuple:
    return _unix(f"/tmp/dfm-missing-{os.getpid()}-{time.monotonic_ns()}/x.sock")


# ── bodies run by _isolated() ─────────────────────────────────────────────────


def _start_stop_once(spec, node: str) -> dict:
    from daffi import Router, Service

    cls = Router if node == "router" else Service
    app = cls(app_name=f"iso-{node}", transports=_materialize(spec))
    app.start()
    conn_num = app._conn_num
    # Every listener must accept as soon as start() returns, without waiting.
    reachable = [_accepts(endpoint) for endpoint in spec]
    began = time.monotonic()
    app.stop()
    stop_seconds = time.monotonic() - began
    return {
        "conn_num": conn_num,
        "reachable": reachable,
        "stop_seconds": stop_seconds,
        "released": [_released(endpoint) for endpoint in spec],
    }


def _start_with_one_bad_listener(spec, bad: int, node: str) -> dict:
    from daffi import Router, Service

    from daffi.exceptions import InitializationError as InitError

    blocker = _occupy(spec[bad]) if spec[bad][0] == "tcp" else None
    cls = Router if node == "router" else Service
    app = cls(app_name=f"iso-bad-{node}", transports=_materialize(spec))
    try:
        app.start()
    except InitError as exc:
        error = str(exc)
    else:
        app.stop()
        raise AssertionError("start() succeeded although a listener could not bind")
    finally:
        if blocker is not None:
            blocker.close()
    others = [endpoint for i, endpoint in enumerate(spec) if i != bad]
    result = {
        "error": error,
        "conn_num": app._conn_num,
        "others_released": [_released(endpoint) for endpoint in others],
    }
    if blocker is not None:
        # The same node starts cleanly once the address is free again.
        app.start()
        result["retry_reachable"] = [_accepts(endpoint) for endpoint in spec]
        app.stop()
        result["retry_released"] = [_released(endpoint) for endpoint in spec]
    return result


def _start_failing_after_peers_connected(spec, node: str, sync: bool = True) -> dict:
    """Connect a peer through every listener while start() is still running,
    then fail the step after the bind.  start() must raise, drop every peer,
    close every listener and stay retryable."""
    import threading

    from daffi import Client, Router, Service
    from daffi._rpc_proxy import RpcProxy
    from daffi.aio import AsyncRouter, AsyncService

    peers = []

    def connect_everyone_then_fail(*_):
        for i, endpoint in enumerate(spec):
            client = Client(app_name=f"peer-{i}", transport=_materialize([endpoint], bare=True))
            client.connect()
            peers.append(client)
        raise RuntimeError("late start failure")

    kwargs = {"workers": 2} if node == "service" else {}
    if sync:
        cls = Router if node == "router" else Service
    else:
        cls = AsyncRouter if node == "router" else AsyncService
    app = cls(app_name=f"iso-late-{node}", transports=_materialize(spec), **kwargs)

    # Routers fail while registering executors; Services one step later, in
    # the handshake, after their dispatcher has started polling.
    original_handshake = RpcProxy._process_service_handshake
    if node == "router":
        app._register_executors = connect_everyone_then_fail
    else:
        RpcProxy._process_service_handshake = classmethod(connect_everyone_then_fail)

    async def start_async():
        await app.start()

    def start():
        if sync:
            app.start()
        else:
            asyncio.run(start_async())

    try:
        start()
    except RuntimeError as exc:
        error = str(exc)
    else:
        raise AssertionError("start() succeeded although a step after the bind failed")

    deadline = time.monotonic() + 15
    while not all(p._disconnected or p._stop_event.is_set() for p in peers):
        if time.monotonic() > deadline:
            break
        time.sleep(0.05)
    result = {
        "error": error,
        "peers": len(peers),
        "peers_dropped": [p._disconnected or p._stop_event.is_set() for p in peers],
        "conn_num": app._conn_num,
        "dispatcher_gone": app._task_dispatcher is None,
        "worker_threads": [t.name for t in threading.enumerate() if t.name.startswith("daffi-worker")],
        "released": [_released(endpoint) for endpoint in spec],
    }
    for peer in peers:
        try:
            peer.stop()
        except BaseException:
            pass

    if node == "router":
        del app._register_executors
    else:
        RpcProxy._process_service_handshake = original_handshake
    start()
    result["retry_reachable"] = [_accepts(endpoint) for endpoint in spec]
    if sync:
        app.stop()
    return result


def _failed_service_start_threads(spec) -> dict:
    """A Service pre-starts its worker threads; a failed bind must stop them."""
    import threading

    from daffi import Service

    from daffi.exceptions import InitializationError as InitError

    blocker = _occupy(spec[-1])
    svc = Service(app_name="iso-threads", transports=_materialize(spec), workers=3)
    try:
        svc.start()
    except InitError as exc:
        error = str(exc)
    else:
        svc.stop()
        raise AssertionError("start() succeeded although a listener could not bind")
    finally:
        blocker.close()
    return {
        "error": error,
        "worker_threads": [t.name for t in threading.enumerate() if t.name.startswith("daffi-worker")],
        "others_released": [_released(endpoint) for endpoint in spec[:-1]],
    }


def _restart_cycles(spec, rounds: int) -> list[list[bool]]:
    from daffi import Router

    seen = []
    for i in range(rounds):
        router = Router(app_name=f"iso-cycle-{i}", transports=_materialize(spec))
        router.start()
        seen.append([_accepts(endpoint) for endpoint in spec])
        router.stop()
        seen.append([_released(endpoint) for endpoint in spec])
    return seen


def _native_start(listeners, busy_port: int | None) -> dict:
    from daffi import dfcore

    blocker = _occupy(_tcp(busy_port)) if busy_port else None
    try:
        dfcore.startServer(listeners, 0, "iso-native", False, "", "")
    except ValueError as exc:
        return {"args": exc.args}
    finally:
        if blocker is not None:
            blocker.close()
    raise AssertionError("startServer accepted a listener set it should reject")


def _async_start_with_one_bad_listener(spec, bad: int) -> dict:
    from daffi.aio import AsyncRouter

    from daffi.exceptions import InitializationError as InitError

    blocker = _occupy(spec[bad])

    async def main():
        router = AsyncRouter(app_name="iso-async-bad", transports=_materialize(spec))
        try:
            await router.start()
        except InitError as exc:
            return str(exc)
        await router.stop()
        raise AssertionError("start() succeeded although a listener could not bind")

    try:
        error = asyncio.run(main())
    finally:
        blocker.close()
    others = [endpoint for i, endpoint in enumerate(spec) if i != bad]
    return {"error": error, "others_released": [_released(e) for e in others]}


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

    def test_duplicate_tcp_transport_is_rejected(self):
        from daffi import Router, TCPTransport

        with pytest.raises(InitializationError, match="duplicate transport tcp://"):
            Router(transports=[TCPTransport(HOST, 7001), TCPTransport(HOST, 7001)])

    def test_duplicate_unix_transport_is_rejected(self):
        from daffi import Service, UnixTransport

        path = "/tmp/daffi-dup.sock"
        relative = os.path.relpath(path)
        with pytest.raises(InitializationError, match="duplicate transport unix://"):
            Service(transports=[UnixTransport(path), UnixTransport(relative)])

    def test_same_port_on_different_hosts_or_ephemeral_ports_are_distinct(self):
        from daffi import Router, TCPTransport

        Router(transports=[TCPTransport(HOST, 7002), TCPTransport("localhost", 7002)])
        Router(transports=[TCPTransport(HOST, 0), TCPTransport(HOST, 0)])

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


class TestNativeStart:
    """``dfcore.startServer`` takes every listener in one call."""

    def test_empty_listener_list_is_rejected(self):
        from daffi import dfcore

        with pytest.raises(ValueError, match="at least one listener"):
            dfcore.startServer([], 0, "empty", False, "", "")

    def test_listeners_must_be_a_list_of_pairs(self):
        from daffi import dfcore

        with pytest.raises(TypeError):
            dfcore.startServer((HOST, 1), 0, "not-a-list", False, "", "")
        with pytest.raises(TypeError):
            dfcore.startServer([HOST], 0, "not-a-pair", False, "", "")

    def test_bad_port_names_its_listener(self):
        from daffi import dfcore

        with pytest.raises(ValueError) as info:
            dfcore.startServer([(HOST, 1), (HOST, 70000)], 0, "bad-port", False, "", "")
        assert info.value.args == ("port must be in range 0-65535", 1)

    def test_duplicate_listener_names_its_index(self):
        result = _isolated(_native_start, [(HOST, 7003), (HOST, 7004), (HOST, 7003)], None)
        assert result["args"] == ("DuplicateListener", 2)

    def test_bind_failure_names_the_failing_listener(self):
        a, b, c = _port(), _port(), _port()
        result = _isolated(_native_start, [(HOST, a), (HOST, b), (HOST, c)], b)
        assert result["args"] == ("ConnectionRefused", 1)
        assert all(_tcp_port_is_free(p) for p in (a, c))


class TestOneHandleForEveryListener:
    @pytest.mark.parametrize("node", ["router", "service"])
    def test_one_conn_num_and_all_listeners_up_when_start_returns(self, node):
        spec = [_tcp(_port()), _tcp(_port()), _unix(_sock(f"h-{node}"))]
        result = _isolated(_start_stop_once, spec, node)
        assert isinstance(result["conn_num"], int)
        assert result["reachable"] == [True, True, True]
        assert result["released"] == [True, True, True]

    def test_many_listeners_start_and_stop_together(self):
        spec = [_tcp(_port()) for _ in range(12)]
        spec += [_unix(_sock(f"many{i}")) for i in range(4)]
        result = _isolated(_start_stop_once, spec, "router")
        assert all(result["reachable"])
        assert all(result["released"])
        # One wake-up stops every listener; nothing waits for a poll timeout
        # per listener.
        assert result["stop_seconds"] < 1.0, result["stop_seconds"]

    def test_repeated_start_stop_on_the_same_addresses(self):
        spec = [_tcp(_port()), _tcp(_port()), _unix(_sock("cycle"))]
        rounds = _isolated(_restart_cycles, spec, 5)
        assert rounds == [[True, True, True]] * 10


class TestAllOrNothingStart:
    @pytest.mark.parametrize("bad", [0, 1, 2])
    def test_busy_tcp_port_leaves_nothing_bound(self, bad):
        spec = [_tcp(_port()), _tcp(_port()), _tcp(_port())]
        spec.append(_unix(_sock(f"aon{bad}")))
        result = _isolated(_start_with_one_bad_listener, spec, bad, "router")
        port = spec[bad][2]
        assert f"{HOST}:{port}" in result["error"]
        assert "already occupied" in result["error"]
        assert result["conn_num"] is None
        assert all(result["others_released"])
        assert result["retry_reachable"] == [True] * len(spec)
        assert all(result["retry_released"])

    def test_unbindable_unix_socket_leaves_tcp_unbound(self):
        spec = [_tcp(_port()), _unbindable_unix(), _tcp(_port())]
        result = _isolated(_start_with_one_bad_listener, spec, 1, "router")
        assert f"unix://{spec[1][1]}" in result["error"]
        assert result["conn_num"] is None
        assert all(result["others_released"])

    def test_service_rolls_back_too(self):
        spec = [_unix(_sock("svc-aon")), _tcp(_port())]
        result = _isolated(_start_with_one_bad_listener, spec, 1, "service")
        assert f"{HOST}:{spec[1][2]}" in result["error"]
        assert all(result["others_released"])
        assert result["retry_reachable"] == [True, True]

    def test_async_router_rolls_back_too(self):
        spec = [_tcp(_port()), _tcp(_port())]
        result = _isolated(_async_start_with_one_bad_listener, spec, 0)
        assert f"{HOST}:{spec[0][2]}" in result["error"]
        assert all(result["others_released"])

    @pytest.mark.parametrize("sync", [True, False], ids=["sync", "async"])
    @pytest.mark.parametrize("node", ["router", "service"])
    def test_failure_after_bind_drops_every_connected_peer(self, node, sync):
        spec = [_tcp(_port()), _tcp(_port()), _unix(_sock(f"late-{node}-{sync}"))]
        result = _isolated(_start_failing_after_peers_connected, spec, node, sync)
        assert result["error"] == "late start failure"
        assert result["peers"] == len(spec)
        assert result["peers_dropped"] == [True] * len(spec)
        assert result["conn_num"] is None
        assert result["dispatcher_gone"]
        assert result["worker_threads"] == []
        assert result["released"] == [True] * len(spec)
        assert result["retry_reachable"] == [True] * len(spec)

    def test_failed_service_start_stops_its_worker_threads(self):
        spec = [_tcp(_port()), _tcp(_port())]
        result = _isolated(_failed_service_start_threads, spec)
        assert "already occupied" in result["error"]
        assert result["worker_threads"] == []
        assert all(result["others_released"])


class TestOneListenerLosesItsPeers:
    """Trouble on one listener must not leak into the others."""

    def test_worker_killed_on_one_listener(self):
        a, b = _port(), _port()
        path = _sock("loss")
        spec = [_tcp(a), _tcp(b), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-loss"))
        try:
            _wait_spec(spec)
            on_a = _spawn(_worker_proc, (_tcp(a), "worker-on-a", None))
            on_unix = _spawn(_worker_proc, (_unix(path), "worker-on-unix", None))
            client, conn = _connect(_tcp(b), "watcher-b")
            try:
                conn.wait_for_members("worker-on-a", "worker-on-unix", timeout=20)
                assert conn.rpc(timeout=TIMEOUT, receiver="worker-on-unix").add(1, 1) == 2

                on_unix.kill()
                on_unix.join(5)
                _wait_gone(conn, "worker-on-unix")

                assert "worker-on-a" in _members(conn)
                assert conn.rpc(timeout=TIMEOUT, receiver="worker-on-a").add(2, 2) == 4
                # The listener whose only peer died keeps accepting.
                assert _rpc(_unix(path), "worker-on-a", "echo", "still", app_name="late-unix") == "still"
            finally:
                client.stop()
                quiet_kill(on_a)
        finally:
            quiet_kill(router)

    def test_worker_comes_back_through_another_listener(self):
        a, b = _port(), _port()
        path = _sock("move")
        spec = [_tcp(a), _tcp(b), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-move"))
        try:
            _wait_spec(spec)
            client, conn = _connect(_tcp(a), "watcher-a")
            first = _spawn(_worker_proc, (_unix(path), "mover", None))
            second = None
            try:
                conn.wait_for_members("mover", timeout=20)
                assert conn.rpc(timeout=TIMEOUT, receiver="mover").who() == "mover"
                first.kill()
                first.join(5)
                _wait_gone(conn, "mover")

                second = _spawn(_worker_proc, (_tcp(b), "mover", None))
                conn.wait_for_members("mover", timeout=20)
                assert conn.rpc(timeout=TIMEOUT, receiver="mover").add(20, 22) == 42
            finally:
                client.stop()
                quiet_kill(first)
                if second is not None:
                    quiet_kill(second)
        finally:
            quiet_kill(router)

    def test_caller_killed_mid_call_on_one_listener(self):
        port = _port()
        path = _sock("doomed")
        spec = [_tcp(port), _unix(path)]
        proc = _spawn(_service_proc, (spec, "svc-doomed", False, None))
        try:
            _wait_spec(spec)
            calling = mp.Event()
            doomed = _spawn(_caller_proc, (_unix(path), "svc-doomed", calling))
            try:
                assert calling.wait(30)
                time.sleep(0.5)
                doomed.kill()
                doomed.join(5)
            finally:
                quiet_kill(doomed)
            assert _rpc(_tcp(port), "svc-doomed", "add", 5, 5, app_name="survivor") == 10
            assert _rpc(_unix(path), "svc-doomed", "echo", "again", app_name="next-unix") == "again"
        finally:
            quiet_kill(proc)

    def test_silent_peers_on_one_listener_do_not_block_the_others(self):
        a, b = _port(), _port()
        path = _sock("silent")
        spec = [_tcp(a), _tcp(b), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-silent"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_tcp(b), "worker-silent", None))
            idle = [socket.create_connection((HOST, a), timeout=5) for _ in range(32)]
            try:
                began = time.monotonic()
                assert _rpc(_unix(path), "worker-silent", "add", 3, 4) == 7
                assert time.monotonic() - began < 20
            finally:
                for sock in idle:
                    sock.close()
                quiet_kill(worker)
            assert _accepts(_tcp(a))
        finally:
            quiet_kill(router)

    def test_garbage_on_one_listener_is_dropped(self):
        a, b = _port(), _port()
        path = _sock("junk")
        spec = [_tcp(a), _tcp(b), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-junk"))
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_unix(path), "worker-junk", None))
            try:
                for _ in range(5):
                    with socket.create_connection((HOST, a), timeout=5) as sock:
                        sock.sendall(os.urandom(4096))
                assert _rpc(_tcp(b), "worker-junk", "echo", "clean") == "clean"
                assert _rpc(_tcp(a), "worker-junk", "add", 6, 6, app_name="after-junk") == 12
            finally:
                quiet_kill(worker)
        finally:
            quiet_kill(router)

    def test_unix_socket_file_removed_while_running(self):
        port = _port()
        path = _sock("unlinked")
        spec = [_tcp(port), _unix(path)]
        started, stop = mp.Event(), mp.Event()
        router = _spawn(_router_until, (spec, started, stop))
        try:
            assert started.wait(20)
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_unix(path), "worker-unlinked", None))
            try:
                client, conn = _connect(_tcp(port), "watcher-unlinked")
                try:
                    conn.wait_for_members("worker-unlinked", timeout=20)
                    os.unlink(path)
                    # The worker's established connection is unaffected while
                    # the path is gone, and the listener binds the path again.
                    assert conn.rpc(timeout=TIMEOUT, receiver="worker-unlinked").add(7, 8) == 15
                    assert _rpc(_tcp(port), "worker-unlinked", "who", app_name="new-tcp") == "worker-unlinked"
                    _wait_accepts(_unix(path))
                    assert (
                        _rpc(_unix(path), "worker-unlinked", "echo", "back", app_name="new-unix")
                        == "back"
                    )
                finally:
                    client.stop()
            finally:
                quiet_kill(worker)
            stop.set()
            router.join(15)
            assert router.exitcode == 0
            assert _tcp_port_is_free(port)
        finally:
            stop.set()
            quiet_kill(router)

    def test_deleted_unix_socket_is_not_taken_from_someone_else(self):
        port = _port()
        path = _sock("held")
        spec = [_tcp(port), _unix(path)]
        router = _spawn(_router_proc, (spec, "router-held"))
        holder = None
        try:
            _wait_spec(spec)
            worker = _spawn(_worker_proc, (_tcp(port), "worker-held", None))
            try:
                os.unlink(path)
                holder = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                # Win the path back if the server restored it between the
                # unlink and this bind.  Unlinking here removes the file, not
                # the server's listening socket.
                bound = False
                for _ in range(40):
                    try:
                        holder.bind(path)
                        bound = True
                        break
                    except OSError:
                        try:
                            os.unlink(path)
                        except FileNotFoundError:
                            pass
                        time.sleep(0.05)
                assert bound, "could not occupy the socket path"
                holder.listen(8)
                time.sleep(1.2)
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                    client.settimeout(2)
                    client.connect(path)
                    holder.settimeout(2)
                    taken, _ = holder.accept()
                    taken.close()
                # The server kept its other listener and did not steal the path.
                assert _rpc(_tcp(port), "worker-held", "add", 1, 2, app_name="held-tcp") == 3
                holder.close()
                holder = None
                os.unlink(path)
                _wait_accepts(_unix(path))
                assert (
                    _rpc(_unix(path), "worker-held", "echo", "restored", app_name="held-unix")
                    == "restored"
                )
            finally:
                quiet_kill(worker)
        finally:
            if holder is not None:
                holder.close()
            quiet_kill(router)

    def test_stop_with_peers_on_every_listener(self):
        a, b = _port(), _port()
        path = _sock("busy-stop")
        spec = [_tcp(a), _tcp(b), _unix(path)]
        started, stop = mp.Event(), mp.Event()
        router = _spawn(_router_until, (spec, started, stop))
        workers = []
        idle = []
        try:
            assert started.wait(20)
            _wait_spec(spec)
            workers = [
                _spawn(_worker_proc, (endpoint, f"busy-{i}", None))
                for i, endpoint in enumerate(spec)
            ]
            client, conn = _connect(_tcp(a), "busy-watcher")
            try:
                conn.wait_for_members("busy-0", "busy-1", "busy-2", timeout=20)
            finally:
                client.stop()
            idle = [socket.create_connection((HOST, b), timeout=5) for _ in range(4)]

            began = time.monotonic()
            stop.set()
            router.join(15)
            assert router.exitcode == 0
            assert time.monotonic() - began < 10
            assert all(_released(endpoint) for endpoint in spec)
        finally:
            for sock in idle:
                sock.close()
            for worker in workers:
                quiet_kill(worker)
            stop.set()
            quiet_kill(router)


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
