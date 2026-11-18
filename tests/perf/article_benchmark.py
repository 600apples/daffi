"""
Current benchmark for the Daffi 4.0 article.

The older scripts in this directory still run, but they are not one dataset:

* most of them time every call and sum those samples, so the reported
  calls/s includes the timer and is not wall-clock throughput
* several still use PICKLE as the Daffi baseline; 4.0's default is MSGPACK
* nothing writes the machine, the spread across repeats, or one table

This script measures one matrix on loopback TCP with no TLS and writes
``results/article_benchmark.json`` and ``results/article_benchmark.csv``.

Two kinds of work are kept apart, because they are not the same CPU cost:

* ``raw-bytes`` — one buffer is echoed and nobody parses it
  (Daffi OPAQUE, gRPC raw, gRPC protobuf ``bytes``, ZeroMQ, nng)
* ``object`` — the ``data.json`` order dict, each library's normal codec
  (Daffi MSGPACK / PICKLE / JSON, RPyC brine, Pyro5 serpent, ZeroRPC)

Daffi runs as a user gets it by default: ``runtime="threads"``, ``workers=1``
(the callback runs inline on the connection). gRPC is on the fast path
from ``grpc_benchmark.py`` (no per-call deadline, retries off, registered
method). Throughput is the wall clock of the call loop. p50 and p99 come
from a second pass that timestamps each call, and only for the sequential
echo. Each published figure is the median of ``--repeats`` runs.

Run::

    python tests/perf/article_benchmark.py
    python tests/perf/article_benchmark.py --quick
    python tests/perf/article_benchmark.py --only bytes
"""

from __future__ import annotations

import argparse
import csv
import importlib.metadata
import json
import logging
import multiprocessing as mp
import os
import platform
import socket
import statistics
import sys
import threading
import time
import traceback
from pathlib import Path

os.environ.setdefault("GRPC_ENABLE_FORK_SUPPORT", "0")
os.environ.setdefault("GRPC_POLL_STRATEGY", "epoll1")
os.environ.setdefault("PYRO_LOGLEVEL", "ERROR")

_REPO_ROOT = Path(__file__).resolve().parents[2]
_PERF_DIR = Path(__file__).resolve().parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
if str(_PERF_DIR) not in sys.path:
    sys.path.insert(0, str(_PERF_DIR))

_DATA_FILE = _PERF_DIR / "data.json"
_OUT_DIR = _PERF_DIR / "results"
_ERR = Path("/tmp/daffi-article-bench.err")

HOST = "127.0.0.1"
RUNTIME = "threads"
TIMEOUT = 30

_GRPC_LATENCY = (
    ("grpc.minimal_stack", 1),
    ("grpc.optimization_target", "latency"),
    ("grpc.enable_retries", 0),
    ("grpc.enable_http_proxy", 0),
    ("grpc.so_reuseport", 0),
    ("grpc.dns_enable_srv_queries", 0),
    ("grpc.dns_enable_txt_queries", 0),
)
_GRPC_THROUGHPUT = tuple(
    ("grpc.optimization_target", "throughput") if key == "grpc.optimization_target" else (key, value)
    for key, value in _GRPC_LATENCY
)
_GRPC_METHOD = "/daffi.perf.Echo/Echo"
_GRPC_SERVICE = "daffi.perf.Echo"

PAYLOAD_SIZES = (
    ("64 B", 64),
    ("1 KiB", 1 << 10),
    ("64 KiB", 1 << 16),
    ("1 MiB", 1 << 20),
)


def _version(dist: str) -> str | None:
    try:
        return importlib.metadata.version(dist)
    except importlib.metadata.PackageNotFoundError:
        return None


def _cpu_model() -> str:
    try:
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or "unknown"


def _ram_gib() -> float | None:
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal:"):
                kib = int(line.split()[1])
                return round(kib / 1024 / 1024, 1)
    except (OSError, ValueError, IndexError):
        return None
    return None


def environment() -> dict:
    return {
        "date": time.strftime("%Y-%m-%d"),
        "python": platform.python_version(),
        "os": platform.platform(),
        "cpu": _cpu_model(),
        "logical_cpus": os.cpu_count(),
        "ram_gib": _ram_gib(),
        "daffi": _version("daffi"),
        "grpcio": _version("grpcio"),
        "pyzmq": _version("pyzmq"),
        "pynng": _version("pynng"),
        "rpyc": _version("rpyc"),
        "Pyro5": _version("Pyro5"),
        "zerorpc": _version("zerorpc"),
        "msgpack": _version("msgpack"),
    }


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((HOST, 0))
        return sock.getsockname()[1]


def _wait_for_port(port: int, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"{HOST}:{port} did not accept connections")


def _silence() -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)


def _child(fn, *args) -> None:
    try:
        _silence()
        fn(*args)
    except Exception:
        _ERR.write_text(traceback.format_exc())
        raise


def _equal(got, expect) -> bool:
    if isinstance(expect, (bytes, bytearray, memoryview)):
        try:
            return bytes(got) == bytes(expect)
        except TypeError:
            return False
    if got == expect:
        return True
    if isinstance(expect, dict):
        try:
            return json.loads(json.dumps(got)) == expect
        except (TypeError, ValueError):
            return False
    return False


def _percentile(sorted_us: list[float], p: float) -> float:
    if not sorted_us:
        raise ValueError("empty latency sample")
    rank = (len(sorted_us) - 1) * p
    low = int(rank)
    high = min(low + 1, len(sorted_us) - 1)
    weight = rank - low
    return sorted_us[low] * (1 - weight) + sorted_us[high] * weight


def _median(values: list[float]) -> float:
    return statistics.median(values)


class _Procs:
    def __init__(self) -> None:
        self._procs: list[mp.Process] = []

    def spawn(self, target, args: tuple) -> mp.Process:
        _ERR.unlink(missing_ok=True)
        proc = mp.Process(target=target, args=args, daemon=True)
        proc.start()
        self._procs.append(proc)
        return proc

    def close(self) -> None:
        for proc in self._procs:
            if proc.is_alive():
                proc.terminate()
                proc.join(timeout=3)
            if proc.is_alive():
                proc.kill()
                proc.join(timeout=2)
        self._procs.clear()
        if _ERR.exists():
            text = _ERR.read_text().strip()
            _ERR.unlink(missing_ok=True)
            if text:
                print(text, file=sys.stderr)


def _boot_daffi() -> None:
    from daffi import dfcore

    dfcore.setRuntime(RUNTIME)


# ── servers ───────────────────────────────────────────────────────────────────


def _serve_daffi(port: int) -> None:
    _boot_daffi()
    from daffi import Service, TCPTransport, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(
        app_name="article-svc",
        transport=TCPTransport(HOST, port),
        runtime=RUNTIME,
        workers=1,
    )
    svc.start()
    svc.join()


def _serve_router(port: int) -> None:
    _boot_daffi()
    from daffi import Router, TCPTransport

    router = Router(
        app_name="article-router",
        transport=TCPTransport(HOST, port),
        runtime=RUNTIME,
    )
    router.start()
    router.join()


def _serve_worker(port: int) -> None:
    _boot_daffi()
    from daffi import Client, TCPTransport, callback

    @callback
    def echo(payload):
        return payload

    client = Client(
        app_name="article-worker",
        transport=TCPTransport(HOST, port),
        runtime=RUNTIME,
        workers=1,
    )
    client.connect()
    client.join()


def _serve_grpc_sync(port: int, options: tuple, pool: int, proto: bool) -> None:
    import grpc
    from concurrent.futures import ThreadPoolExecutor

    server = grpc.server(ThreadPoolExecutor(max_workers=pool), options=options)
    if proto:
        from grpc_echo import echo_pb2, echo_pb2_grpc

        class EchoServicer(echo_pb2_grpc.EchoServicer):
            def Echo(self, request, context):  # noqa: N802
                return echo_pb2.EchoReply(data=request.data)

        echo_pb2_grpc.add_EchoServicer_to_server(EchoServicer(), server)
    else:
        handler = grpc.unary_unary_rpc_method_handler(lambda request, context: request)
        server.add_registered_method_handlers(_GRPC_SERVICE, {"Echo": handler})
    server.add_insecure_port(f"{HOST}:{port}")
    server.start()
    server.wait_for_termination()


def _serve_grpc_aio(port: int) -> None:
    import asyncio
    import grpc

    async def echo(request, context):
        return request

    async def serve() -> None:
        handler = grpc.unary_unary_rpc_method_handler(echo)
        server = grpc.aio.server(options=_GRPC_THROUGHPUT)
        server.add_registered_method_handlers(_GRPC_SERVICE, {"Echo": handler})
        server.add_insecure_port(f"{HOST}:{port}")
        await server.start()
        await server.wait_for_termination()

    asyncio.run(serve())


def _serve_zmq_rep(port: int) -> None:
    import zmq

    ctx = zmq.Context()
    sock = ctx.socket(zmq.REP)
    sock.bind(f"tcp://{HOST}:{port}")
    try:
        while True:
            sock.send(sock.recv())
    finally:
        sock.close(0)
        ctx.term()


def _serve_zmq_router(port: int) -> None:
    import zmq

    ctx = zmq.Context()
    sock = ctx.socket(zmq.ROUTER)
    sock.bind(f"tcp://{HOST}:{port}")
    try:
        while True:
            parts = sock.recv_multipart()
            sock.send_multipart([parts[0], parts[-1]])
    finally:
        sock.close(0)
        ctx.term()


def _serve_nng(port: int) -> None:
    import pynng

    with pynng.Rep0(listen=f"tcp://{HOST}:{port}") as sock:
        while True:
            sock.send(sock.recv())


def _serve_rpyc(port: int) -> None:
    import rpyc
    from rpyc.utils.server import ThreadedServer

    class EchoService(rpyc.Service):
        def exposed_echo(self, payload):
            return payload

    ThreadedServer(
        EchoService,
        hostname=HOST,
        port=port,
        protocol_config={"allow_public_attrs": True},
    ).start()


def _serve_pyro(port: int) -> None:
    import Pyro5.api

    @Pyro5.api.expose
    class Echo:
        def echo(self, payload):
            return payload

    daemon = Pyro5.api.Daemon(host=HOST, port=port)
    daemon.register(Echo, objectId="echo")
    daemon.requestLoop()


def _serve_zerorpc(port: int) -> None:
    import gevent.monkey

    gevent.monkey.patch_all()
    import zerorpc

    class Echo:
        def echo(self, payload):
            return payload

    server = zerorpc.Server(Echo())
    server.bind(f"tcp://{HOST}:{port}")
    server.run()


def _proc(fn, *args) -> None:
    _child(fn, *args)


# ── measurements ──────────────────────────────────────────────────────────────


def _wait_ready(call, expect, tries: int = 40):
    last: Exception | None = None
    for _ in range(tries):
        try:
            got = call()
        except Exception as exc:
            last = exc
            time.sleep(0.05)
            continue
        if not _equal(got, expect):
            raise RuntimeError(
                f"echo mismatch: {type(got).__name__} vs {type(expect).__name__}"
            )
        return got
    raise RuntimeError(f"peer never became ready: {last!r}")


def _warmup(call, n: int) -> None:
    for _ in range(n):
        call()


def _wall(call, n: int) -> tuple[float, float]:
    started = time.perf_counter()
    for _ in range(n):
        call()
    elapsed = time.perf_counter() - started
    return n / elapsed, elapsed / n * 1e6


def _timed(call, n: int) -> tuple[float, float]:
    samples = [0.0] * n
    for i in range(n):
        started = time.perf_counter()
        call()
        samples[i] = (time.perf_counter() - started) * 1e6
    samples.sort()
    return _percentile(samples, 0.50), _percentile(samples, 0.99)


def _finish(closes: list) -> None:
    errors: list[BaseException] = []
    for close in closes:
        try:
            close()
        except BaseException as exc:  # noqa: BLE001 — teardown must keep going
            errors.append(exc)
    if errors:
        raise errors[0]


def _daffi_call(port: int, serde: int, payload, app_name: str):
    from daffi import Client, TCPTransport

    client = Client(
        app_name=app_name,
        transport=TCPTransport(HOST, port),
        runtime=RUNTIME,
    )
    echo = client.connect().rpc(timeout=TIMEOUT, serde=serde).echo
    return (lambda: echo(payload)), client.stop


def _open_daffi(serde: int, payload, via_router: bool):
    procs = _Procs()
    port = _free_port()
    if via_router:
        procs.spawn(_proc, (_serve_router, port))
        _wait_for_port(port)
        procs.spawn(_proc, (_serve_worker, port))
        time.sleep(0.3)
    else:
        procs.spawn(_proc, (_serve_daffi, port))
        _wait_for_port(port)
        time.sleep(0.1)
    call, stop = _daffi_call(port, serde, payload, "article-client")
    return call, [stop, procs.close]


def _open_grpc(payload: bytes, proto: bool, latency: bool):
    import grpc

    options = _GRPC_LATENCY if latency else _GRPC_THROUGHPUT
    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_grpc_sync, port, options, 1, proto))
    _wait_for_port(port)
    channel = grpc.insecure_channel(
        f"{HOST}:{port}",
        options=options,
        compression=grpc.Compression.NoCompression,
    )
    grpc.channel_ready_future(channel).result(timeout=10)

    if proto:
        from grpc_echo import echo_pb2, echo_pb2_grpc

        stub = echo_pb2_grpc.EchoStub(channel)
        request = echo_pb2.EchoRequest(data=payload)

        def call():
            return stub.Echo(request).data
    else:
        rpc = channel.unary_unary(_GRPC_METHOD, _registered_method=True)

        def call():
            return rpc(payload)

    return call, [channel.close, procs.close]


def _open_zmq(payload: bytes):
    import zmq

    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_zmq_rep, port))
    _wait_for_port(port)
    ctx = zmq.Context()
    sock = ctx.socket(zmq.REQ)
    sock.setsockopt(zmq.LINGER, 0)
    sock.setsockopt(zmq.RCVTIMEO, TIMEOUT * 1000)
    sock.setsockopt(zmq.SNDTIMEO, TIMEOUT * 1000)
    sock.connect(f"tcp://{HOST}:{port}")

    def call():
        sock.send(payload)
        return sock.recv()

    def close() -> None:
        sock.close(0)
        ctx.term()

    return call, [close, procs.close]


def _open_nng(payload: bytes):
    import pynng

    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_nng, port))
    time.sleep(0.25)
    sock = pynng.Req0(dial=f"tcp://{HOST}:{port}")
    sock.send_timeout = TIMEOUT * 1000
    sock.recv_timeout = TIMEOUT * 1000

    def call():
        sock.send(payload)
        return sock.recv()

    return call, [sock.close, procs.close]


def _open_rpyc(payload):
    import rpyc

    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_rpyc, port))
    _wait_for_port(port)
    conn = rpyc.connect(
        HOST,
        port,
        config={"allow_public_attrs": True, "sync_request_timeout": TIMEOUT},
    )
    echo = conn.root.echo
    return (lambda: echo(payload)), [conn.close, procs.close]


def _open_pyro(payload):
    import Pyro5.api

    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_pyro, port))
    _wait_for_port(port)
    time.sleep(0.1)
    proxy = Pyro5.api.Proxy(f"PYRO:echo@{HOST}:{port}")
    proxy._pyroTimeout = TIMEOUT
    return (lambda: proxy.echo(payload)), [proxy._pyroRelease, procs.close]


def _open_zerorpc(payload):
    import zerorpc

    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_zerorpc, port))
    deadline = time.monotonic() + 15
    client = None
    last: Exception | None = None
    while time.monotonic() < deadline:
        try:
            client = zerorpc.Client(timeout=TIMEOUT)
            client.connect(f"tcp://{HOST}:{port}")
            break
        except Exception as exc:  # noqa: BLE001 — server bind is not instant
            last = exc
            if client is not None:
                client.close()
                client = None
            time.sleep(0.05)
    if client is None:
        procs.close()
        raise RuntimeError(f"ZeroRPC did not start: {last!r}")
    return (lambda: client.echo(payload)), [client.close, procs.close]


def _sequential(opener, payload, calls: int, warmup: int, repeats: int, percentiles: bool) -> dict:
    rates: list[float] = []
    avgs: list[float] = []
    p50s: list[float] = []
    p99s: list[float] = []
    for _ in range(repeats):
        call, closes = opener()
        try:
            _wait_ready(call, payload)
            _warmup(call, warmup)
            rate, avg = _wall(call, calls)
            rates.append(rate)
            avgs.append(avg)
            if percentiles:
                p50, p99 = _timed(call, calls)
                p50s.append(p50)
                p99s.append(p99)
        finally:
            _finish(closes)
    return {
        "calls_per_s": _median(rates),
        "calls_per_s_min": min(rates),
        "calls_per_s_max": max(rates),
        "avg_latency_us": _median(avgs),
        "p50_us": _median(p50s) if p50s else None,
        "p99_us": _median(p99s) if p99s else None,
        "calls": calls,
        "repeats": repeats,
    }


def _parallel_threads(n_clients: int, n_calls: int, make_worker) -> tuple[float, float]:
    per = [None] * n_clients
    starts = [None] * n_clients
    ends = [None] * n_clients
    errors: list[tuple[int, BaseException]] = []
    barrier = threading.Barrier(n_clients)

    def run(idx: int) -> None:
        close = None
        try:
            call, close = make_worker(idx)
            barrier.wait(timeout=120)
            started = time.perf_counter()
            for _ in range(n_calls):
                call()
            ended = time.perf_counter()
            starts[idx] = started
            ends[idx] = ended
            per[idx] = ended - started
        except BaseException as exc:  # noqa: BLE001 — report and release the barrier
            errors.append((idx, exc))
            try:
                barrier.abort()
            except Exception:
                pass
        finally:
            if close is not None:
                try:
                    close()
                except Exception:
                    pass

    threads = [threading.Thread(target=run, args=(i,), daemon=True) for i in range(n_clients)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    if errors or any(item is None for item in per):
        detail = errors[0][1] if errors else RuntimeError("a client produced no sample")
        raise RuntimeError(f"{len(errors)} client errors") from detail
    wall = max(ends) - min(starts)
    avg_us = (sum(per) / n_clients / n_calls) * 1e6
    return (n_clients * n_calls) / wall, avg_us


def _clients_daffi(wire: bytes, n_clients: int, n_calls: int, warmup: int) -> tuple[float, float]:
    from daffi import SerdeFormat

    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_daffi, port))
    _wait_for_port(port)
    time.sleep(0.1)

    def make_worker(idx: int):
        call, stop = _daffi_call(port, SerdeFormat.OPAQUE, wire, f"article-c{idx}")
        _wait_ready(call, wire)
        _warmup(call, warmup)
        return call, stop

    try:
        return _parallel_threads(n_clients, n_calls, make_worker)
    finally:
        procs.close()


def _clients_grpc(wire: bytes, n_clients: int, n_calls: int, warmup: int, aio: bool) -> tuple[float, float]:
    procs = _Procs()
    port = _free_port()
    if aio:
        procs.spawn(_proc, (_serve_grpc_aio, port))
    else:
        procs.spawn(_proc, (_serve_grpc_sync, port, _GRPC_THROUGHPUT, max(n_clients, 4), False))
    _wait_for_port(port)
    try:
        if aio:
            return _clients_grpc_aio(port, wire, n_clients, n_calls, warmup)
        return _clients_grpc_sync(port, wire, n_clients, n_calls, warmup)
    finally:
        procs.close()


def _clients_grpc_sync(port: int, wire: bytes, n_clients: int, n_calls: int, warmup: int):
    import grpc

    def make_worker(idx: int):
        channel = grpc.insecure_channel(
            f"{HOST}:{port}",
            options=_GRPC_THROUGHPUT,
            compression=grpc.Compression.NoCompression,
        )
        grpc.channel_ready_future(channel).result(timeout=10)
        rpc = channel.unary_unary(_GRPC_METHOD, _registered_method=True)

        def call():
            return rpc(wire)

        _wait_ready(call, wire)
        _warmup(call, warmup)
        return call, channel.close

    return _parallel_threads(n_clients, n_calls, make_worker)


def _clients_grpc_aio(port: int, wire: bytes, n_clients: int, n_calls: int, warmup: int):
    import asyncio
    import grpc

    async def run() -> tuple[float, float]:
        barrier = asyncio.Barrier(n_clients)
        per: list[float | None] = [None] * n_clients
        starts: list[float | None] = [None] * n_clients
        ends: list[float | None] = [None] * n_clients

        async def one(idx: int) -> None:
            channel = grpc.aio.insecure_channel(
                f"{HOST}:{port}",
                options=_GRPC_THROUGHPUT,
                compression=grpc.Compression.NoCompression,
            )
            try:
                await asyncio.wait_for(channel.channel_ready(), timeout=10)
                rpc = channel.unary_unary(_GRPC_METHOD, _registered_method=True)

                async def call():
                    return await rpc(wire)

                got = await call()
                if not _equal(got, wire):
                    raise RuntimeError("gRPC aio echo mismatch")
                for _ in range(warmup):
                    await call()
                await barrier.wait()
                started = time.perf_counter()
                for _ in range(n_calls):
                    await call()
                ended = time.perf_counter()
                starts[idx] = started
                ends[idx] = ended
                per[idx] = ended - started
            except Exception:
                try:
                    await barrier.abort()
                except Exception:
                    pass
                raise
            finally:
                await channel.close()

        await asyncio.gather(*(one(i) for i in range(n_clients)))
        if any(item is None for item in per):
            raise RuntimeError("a gRPC aio client produced no sample")
        wall = max(ends) - min(starts)
        avg_us = (sum(per) / n_clients / n_calls) * 1e6
        return (n_clients * n_calls) / wall, avg_us

    return asyncio.run(run())


def _clients_zmq(wire: bytes, n_clients: int, n_calls: int, warmup: int) -> tuple[float, float]:
    import zmq

    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_zmq_router, port))
    _wait_for_port(port)
    endpoint = f"tcp://{HOST}:{port}"

    def make_worker(idx: int):
        ctx = zmq.Context()
        sock = ctx.socket(zmq.DEALER)
        sock.setsockopt(zmq.LINGER, 0)
        sock.setsockopt(zmq.RCVTIMEO, TIMEOUT * 1000)
        sock.setsockopt(zmq.SNDTIMEO, TIMEOUT * 1000)
        sock.connect(endpoint)

        def call():
            sock.send(wire)
            return sock.recv()

        def close() -> None:
            sock.close(0)
            ctx.term()

        _wait_ready(call, wire)
        _warmup(call, warmup)
        return call, close

    try:
        return _parallel_threads(n_clients, n_calls, make_worker)
    finally:
        procs.close()


def _clients_rpyc(wire: bytes, n_clients: int, n_calls: int, warmup: int) -> tuple[float, float]:
    import rpyc

    procs = _Procs()
    port = _free_port()
    procs.spawn(_proc, (_serve_rpyc, port))
    _wait_for_port(port)

    def make_worker(idx: int):
        conn = rpyc.connect(
            HOST,
            port,
            config={"allow_public_attrs": True, "sync_request_timeout": TIMEOUT},
        )
        echo = conn.root.echo

        def call():
            return echo(wire)

        _wait_ready(call, wire)
        _warmup(call, warmup)
        return call, conn.close

    try:
        return _parallel_threads(n_clients, n_calls, make_worker)
    finally:
        procs.close()


def _repeat_clients(fn, repeats: int) -> dict:
    rates: list[float] = []
    avgs: list[float] = []
    for _ in range(repeats):
        rate, avg = fn()
        rates.append(rate)
        avgs.append(avg)
    return {
        "calls_per_s": _median(rates),
        "calls_per_s_min": min(rates),
        "calls_per_s_max": max(rates),
        "avg_latency_us": _median(avgs),
        "p50_us": None,
        "p99_us": None,
        "repeats": repeats,
    }


def _row(group: str, work: str, framework: str, **fields) -> dict:
    payload = fields.pop("payload_bytes")
    base = {
        "group": group,
        "work": work,
        "framework": framework,
        "transport": "tcp-loopback",
        "tls": False,
        "payload_bytes": payload,
        "concurrency": fields.pop("concurrency", 1),
        "goodput_mib_s": None,
    }
    base.update(fields)
    return base


def _with_goodput(row: dict) -> dict:
    rate = row.get("calls_per_s")
    size = row.get("payload_bytes") or 0
    if rate and size:
        # Request and response both carry the payload.
        row["goodput_mib_s"] = size * 2 * rate / (1024 * 1024)
    return row


def _write(path_json: Path, path_csv: Path, payload: dict) -> None:
    path_json.write_text(json.dumps(payload, indent=2) + "\n")
    columns = [
        "group",
        "work",
        "framework",
        "payload_bytes",
        "concurrency",
        "calls",
        "repeats",
        "calls_per_s",
        "calls_per_s_min",
        "calls_per_s_max",
        "avg_latency_us",
        "p50_us",
        "p99_us",
        "goodput_mib_s",
        "error",
    ]
    with path_csv.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for row in payload["rows"]:
            writer.writerow(row)


def _run_cell(label: str, fn) -> dict:
    print(f"\n── {label}", flush=True)
    started = time.perf_counter()
    try:
        result = fn()
    except Exception as exc:
        print(f"   FAILED: {exc}", flush=True)
        traceback.print_exc()
        return {"error": f"{type(exc).__name__}: {exc}"}
    elapsed = time.perf_counter() - started
    rate = result.get("calls_per_s")
    avg = result.get("avg_latency_us")
    if rate is not None:
        print(f"   {rate:,.0f} calls/s   avg {avg:,.1f} µs   ({elapsed:.1f}s)", flush=True)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quick", action="store_true", help="short run, to check that the matrix works")
    parser.add_argument(
        "--only",
        choices=("all", "bytes", "object", "payload", "clients"),
        default="all",
    )
    parser.add_argument("--calls", type=int, default=None, help="sequential calls per repeat")
    parser.add_argument("--repeats", type=int, default=None)
    args = parser.parse_args()

    if args.quick:
        seq_calls = args.calls or 200
        repeats = args.repeats or 1
        warmup = 10
        client_counts = (1, 4)
        client_calls = 40
        client_warmup = 5

        def payload_calls(size: int) -> int:
            return 20 if size >= (1 << 20) else 40
    else:
        seq_calls = args.calls or 10_000
        repeats = args.repeats or 3
        warmup = 50
        client_counts = (1, 8, 32)
        client_calls = 1_000
        client_warmup = 20

        def payload_calls(size: int) -> int:
            if size <= 1024:
                return 5_000
            if size <= (1 << 16):
                return 1_000
            return 200

    logging.disable(logging.INFO)
    order = json.loads(_DATA_FILE.read_text())
    wire = json.dumps(order).encode()
    from daffi import SerdeFormat, dfcore

    dfcore.setRuntime(RUNTIME)

    rows: list[dict] = []
    doc = {
        "environment": environment(),
        "methodology": {
            "daffi": (
                "4.0 defaults: runtime=threads, workers=1, no TLS. "
                "MSGPACK is the default codec. OPAQUE ships the buffer unchanged. "
                "The router row is Client → Router → worker (two TCP hops)."
            ),
            "others": (
                "Same host, loopback TCP, no TLS, server in its own process. "
                "gRPC uses a registered unary method, no per-call deadline, "
                "retries off, HTTP proxy off. Sequential gRPC is tuned for "
                "latency with one server thread. Concurrent gRPC uses the "
                "throughput target; the sync server pool is at least the "
                "client count, and the aio row is grpc.aio with one channel "
                "per client. ZeroMQ sequential is REQ/REP. ZeroMQ concurrent "
                "is one DEALER socket per client against one ROUTER. "
                "nng is req/rep. RPyC uses ThreadedServer and brine. "
                "Pyro5 uses its default serpent codec. ZeroRPC uses its "
                "default msgpack-over-ZeroMQ server."
            ),
            "timing": (
                "Warmup is outside the timer. calls/s and avg_latency_us are "
                "wall-clock of a loop that does not timestamp each call. "
                "p50_us and p99_us are from a second pass and are omitted "
                "for payload and client rows. Published values are medians; "
                "calls_per_s_min and calls_per_s_max are the repeat spread. "
                "goodput_mib_s counts the payload twice (request and response) "
                "and divides by 1024*1024."
            ),
            "do_not_mix": (
                "raw-bytes and object rows are different amounts of work. "
                "RPyC on the client chart serializes the bytes with brine; "
                "Daffi OPAQUE, gRPC raw, and ZeroMQ do not. "
                "The clients group is its own harness (a thread barrier and "
                "1,000 calls per client). Use it to compare a framework with "
                "itself at 1, 8, and 32 clients. The one-in-flight latency "
                "table is the bytes and object groups."
            ),
            "order_json_bytes": len(wire),
            "sequential_calls": seq_calls,
            "repeats": repeats,
        },
        "rows": rows,
    }
    _OUT_DIR.mkdir(parents=True, exist_ok=True)
    path_json = _OUT_DIR / "article_benchmark.json"
    path_csv = _OUT_DIR / "article_benchmark.csv"

    def keep(group: str) -> bool:
        return args.only in ("all", group)

    def add(group: str, work: str, framework: str, opener_or_fn, **meta) -> None:
        if not keep(group):
            return
        measured = _run_cell(f"{group}: {framework}", opener_or_fn)
        row = _row(group, work, framework, **meta)
        row.update(measured)
        _with_goodput(row)
        rows.append(row)
        _write(path_json, path_csv, doc)

    if keep("bytes"):
        byte_specs = (
            ("Daffi OPAQUE", lambda: _open_daffi(SerdeFormat.OPAQUE, wire, False)),
            ("gRPC protobuf", lambda: _open_grpc(wire, True, True)),
            ("gRPC raw", lambda: _open_grpc(wire, False, True)),
            ("ZeroMQ REQ/REP", lambda: _open_zmq(wire)),
            ("nng req/rep", lambda: _open_nng(wire)),
        )
        for name, opener in byte_specs:
            add(
                "bytes",
                "raw-bytes",
                name,
                lambda opener=opener: _sequential(opener, wire, seq_calls, warmup, repeats, True),
                payload_bytes=len(wire),
                calls=seq_calls,
                layout="direct",
            )

    if keep("object"):
        object_specs = (
            ("Daffi MSGPACK", lambda: _open_daffi(SerdeFormat.MSGPACK, order, False), "direct"),
            ("Daffi PICKLE", lambda: _open_daffi(SerdeFormat.PICKLE, order, False), "direct"),
            ("Daffi JSON", lambda: _open_daffi(SerdeFormat.JSON, order, False), "direct"),
            (
                "Daffi MSGPACK via Router",
                lambda: _open_daffi(SerdeFormat.MSGPACK, order, True),
                "router",
            ),
            ("RPyC", lambda: _open_rpyc(order), "direct"),
            ("Pyro5", lambda: _open_pyro(order), "direct"),
            ("ZeroRPC", lambda: _open_zerorpc(order), "direct"),
        )
        for name, opener, layout in object_specs:
            add(
                "object",
                "structured-object",
                name,
                lambda opener=opener: _sequential(opener, order, seq_calls, warmup, repeats, True),
                payload_bytes=len(wire),
                calls=seq_calls,
                layout=layout,
            )

    if keep("payload"):
        for label, size in PAYLOAD_SIZES:
            blob = bytes(size)
            calls = payload_calls(size)
            payload_specs = (
                ("Daffi OPAQUE", lambda blob=blob: _open_daffi(SerdeFormat.OPAQUE, blob, False)),
                ("Daffi MSGPACK", lambda blob=blob: _open_daffi(SerdeFormat.MSGPACK, blob, False)),
                ("gRPC protobuf", lambda blob=blob: _open_grpc(blob, True, True)),
                ("ZeroMQ REQ/REP", lambda blob=blob: _open_zmq(blob)),
            )
            for name, opener in payload_specs:
                add(
                    "payload",
                    "raw-bytes" if name != "Daffi MSGPACK" else "structured-object",
                    name,
                    lambda opener=opener, blob=blob, calls=calls: _sequential(
                        opener, blob, calls, min(warmup, 5), repeats, False
                    ),
                    payload_bytes=size,
                    payload_label=label,
                    calls=calls,
                    layout="direct",
                )

    if keep("clients"):
        for count in client_counts:
            client_specs = (
                (
                    "Daffi OPAQUE",
                    lambda count=count: _clients_daffi(wire, count, client_calls, client_warmup),
                ),
                (
                    "gRPC raw sync",
                    lambda count=count: _clients_grpc(wire, count, client_calls, client_warmup, False),
                ),
                (
                    "gRPC raw aio",
                    lambda count=count: _clients_grpc(wire, count, client_calls, client_warmup, True),
                ),
                (
                    "ZeroMQ DEALER/ROUTER",
                    lambda count=count: _clients_zmq(wire, count, client_calls, client_warmup),
                ),
                (
                    "RPyC",
                    lambda count=count: _clients_rpyc(wire, count, client_calls, client_warmup),
                ),
            )
            for name, fn in client_specs:
                add(
                    "clients",
                    "raw-bytes",
                    name,
                    lambda fn=fn, count=count: _repeat_clients(
                        fn, repeats
                    )
                    | {"calls": client_calls * count},
                    payload_bytes=len(wire),
                    concurrency=count,
                    calls_per_client=client_calls,
                    layout="direct",
                )

    _write(path_json, path_csv, doc)
    print(f"\nWrote {path_json}", flush=True)
    print(f"Wrote {path_csv}", flush=True)


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
