"""
Fair unary benchmark: Python grpcio pushed to its fast path, same bytes as daffi.

Both stacks echo one pre-encoded payload (``data.json``, ~2 KB).  Nothing in
the timed loop parses JSON.

gRPC fast path
    * Registered unary method (the generated stub already does this).
    * No per-call deadline.  A deadline is computed in Python on every call
      when ``timeout=`` is passed; daffi stores it once on the proxy.
    * Channel args: ``grpc.minimal_stack``, retries off, HTTP proxy off,
      latency target for one-in-flight, throughput target once calls overlap.
    * Raw row: gRPC framing only.  The protobuf codec is not in the hot path.
    * Protobuf row: generated stub, ``bytes`` field, same tuning.  This is the
      normal Python API.
    * Peak row: ``grpc.aio``, several unary calls in flight on one channel.
      Sync ``grpcio`` stays near 6k calls/s no matter the thread count.

daffi
    * OPAQUE ships those same bytes unchanged.  This is the matching echo.
    * MSGPACK round-trips the parsed object (four structured serde passes).
      It is a different amount of work and is reported separately.
    * ``workers=1`` runs the callback on the poller.  A larger pool was slower
      for this echo.  Overlapping calls use one proxy from several threads.

Both: loopback TCP, no TLS, server in its own process, warmup outside the
timer, wall time for N calls.

Run::

    python3 tests/perf/grpc_benchmark.py

``BENCH_N`` overrides the call count (default 100000).
"""

from __future__ import annotations

import asyncio
import json
import logging
import multiprocessing as mp
import os
import socket
import sys
import time
import traceback
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

os.environ.setdefault("GRPC_ENABLE_FORK_SUPPORT", "0")
os.environ.setdefault("GRPC_POLL_STRATEGY", "epoll1")

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
from tests.conftest import active_runtime

_DATA_FILE = Path(__file__).parent / "data.json"
_ERR = Path("/tmp/daffi-grpc-bench.err")
_METHOD = "/daffi.perf.Echo/Echo"
_SERVICE = "daffi.perf.Echo"

N = int(os.environ.get("BENCH_N", "100000"))
WARMUP = 50
HOST = "127.0.0.1"
# Depths past one-in-flight.  Sync grpcio does not get faster by adding
# threads; aio does, up to a point.  daffi's echo is fastest at workers=1.
INFLIGHT = (8, 16, 32)

_LATENCY_OPTIONS = (
    ("grpc.minimal_stack", 1),
    ("grpc.optimization_target", "latency"),
    ("grpc.enable_retries", 0),
    ("grpc.enable_http_proxy", 0),
    ("grpc.so_reuseport", 0),
    ("grpc.dns_enable_srv_queries", 0),
    ("grpc.dns_enable_txt_queries", 0),
)
_THROUGHPUT_OPTIONS = tuple(
    ("grpc.optimization_target", "throughput")
    if key == "grpc.optimization_target"
    else (key, value)
    for key, value in _LATENCY_OPTIONS
)


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, 0))
        return s.getsockname()[1]


def _wait_for_port(port: int, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"{HOST}:{port} did not accept connections within {timeout}s")


def _silence() -> None:
    dn = os.open(os.devnull, os.O_WRONLY)
    os.dup2(dn, 1)
    os.dup2(dn, 2)
    os.close(dn)
    logging.disable(logging.CRITICAL)


def _child(fn, *args) -> None:
    try:
        _silence()
        fn(*args)
    except Exception:
        _ERR.write_text(traceback.format_exc())
        raise


def _stop(proc: mp.Process) -> None:
    proc.terminate()
    proc.join(timeout=5)
    if proc.exitcode not in (0, None, -15) and _ERR.exists():
        print(_ERR.read_text(), file=sys.stderr)


def _elapsed(call, n: int) -> float:
    t0 = time.perf_counter()
    for _ in range(n):
        call()
    return time.perf_counter() - t0


def _report(label: str, elapsed: float, n: int) -> float:
    rate = n / elapsed
    print(f"  {label}: {elapsed:.3f} s for {n} calls  ({rate:.0f} calls/s)")
    return rate


# ── gRPC servers ──────────────────────────────────────────────────────────────


def _echo_raw(request, context):
    return request


async def _echo_raw_async(request, context):
    return request


def _serve_raw_sync(port: int, options: tuple) -> None:
    import grpc

    handler = grpc.unary_unary_rpc_method_handler(_echo_raw)
    server = grpc.server(ThreadPoolExecutor(max_workers=1), options=options)
    server.add_registered_method_handlers(_SERVICE, {"Echo": handler})
    server.add_insecure_port(f"{HOST}:{port}")
    server.start()
    server.wait_for_termination()


def _serve_proto_sync(port: int, options: tuple) -> None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import grpc
    from grpc_echo import echo_pb2, echo_pb2_grpc

    class EchoServicer(echo_pb2_grpc.EchoServicer):
        def Echo(self, request, context):  # noqa: N802 — gRPC naming
            return echo_pb2.EchoReply(data=request.data)

    server = grpc.server(ThreadPoolExecutor(max_workers=1), options=options)
    echo_pb2_grpc.add_EchoServicer_to_server(EchoServicer(), server)
    server.add_insecure_port(f"{HOST}:{port}")
    server.start()
    server.wait_for_termination()


def _serve_raw_aio(port: int, options: tuple) -> None:
    import grpc
    import grpc.aio

    async def serve() -> None:
        handler = grpc.unary_unary_rpc_method_handler(_echo_raw_async)
        server = grpc.aio.server(options=options)
        server.add_registered_method_handlers(_SERVICE, {"Echo": handler})
        server.add_insecure_port(f"{HOST}:{port}")
        await server.start()
        await server.wait_for_termination()

    asyncio.run(serve())


def _proc_raw_sync(port: int, options: tuple) -> None:
    _child(_serve_raw_sync, port, options)


def _proc_proto_sync(port: int, options: tuple) -> None:
    _child(_serve_proto_sync, port, options)


def _proc_raw_aio(port: int, options: tuple) -> None:
    _child(_serve_raw_aio, port, options)


def _start(target, *args) -> tuple[mp.Process, int]:
    _ERR.unlink(missing_ok=True)
    port = _free_port()
    proc = mp.Process(target=target, args=(port, *args), daemon=True)
    proc.start()
    _wait_for_port(port)
    return proc, port


def bench_grpc_raw(wire: bytes) -> float:
    import grpc

    proc, port = _start(_proc_raw_sync, _LATENCY_OPTIONS)
    try:
        channel = grpc.insecure_channel(
            f"{HOST}:{port}",
            options=_LATENCY_OPTIONS,
            compression=grpc.Compression.NoCompression,
        )
        grpc.channel_ready_future(channel).result(timeout=10)
        rpc = channel.unary_unary(_METHOD, _registered_method=True)
        try:
            for _ in range(WARMUP):
                if rpc(wire) != wire:
                    raise SystemExit("gRPC raw echo returned different bytes")
            print(f"  [grpc raw] measuring {N} calls…", flush=True)
            return _report("gRPC raw bytes", _elapsed(lambda: rpc(wire), N), N)
        finally:
            channel.close()
    finally:
        _stop(proc)


def bench_grpc_proto(wire: bytes) -> float:
    import grpc

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from grpc_echo import echo_pb2, echo_pb2_grpc

    proc, port = _start(_proc_proto_sync, _LATENCY_OPTIONS)
    try:
        channel = grpc.insecure_channel(
            f"{HOST}:{port}",
            options=_LATENCY_OPTIONS,
            compression=grpc.Compression.NoCompression,
        )
        grpc.channel_ready_future(channel).result(timeout=10)
        stub = echo_pb2_grpc.EchoStub(channel)
        req = echo_pb2.EchoRequest(data=wire)
        try:
            for _ in range(WARMUP):
                if stub.Echo(req).data != wire:
                    raise SystemExit("gRPC protobuf echo returned different bytes")
            print(f"  [grpc protobuf] measuring {N} calls…", flush=True)
            return _report(
                "gRPC protobuf",
                _elapsed(lambda: stub.Echo(req).data, N),
                N,
            )
        finally:
            channel.close()
    finally:
        _stop(proc)


async def _aio_call(rpc, wire: bytes) -> bytes:
    return await rpc(wire)


async def _aio_window(rpc, wire: bytes, n: int, conc: int) -> float:
    pending: set[asyncio.Task] = set()
    t0 = time.perf_counter()
    for _ in range(n):
        pending.add(asyncio.create_task(_aio_call(rpc, wire)))
        if len(pending) >= conc:
            done, pending = await asyncio.wait(
                pending, return_when=asyncio.FIRST_COMPLETED
            )
            for task in done:
                task.result()
    if pending:
        done, _pending = await asyncio.wait(pending)
        for task in done:
            task.result()
    return time.perf_counter() - t0


def bench_grpc_aio(wire: bytes) -> list[tuple[int, float]]:
    import grpc
    import grpc.aio

    proc, port = _start(_proc_raw_aio, _THROUGHPUT_OPTIONS)

    async def run() -> list[tuple[int, float]]:
        channel = grpc.aio.insecure_channel(
            f"{HOST}:{port}",
            options=_THROUGHPUT_OPTIONS,
            compression=grpc.Compression.NoCompression,
        )
        try:
            await asyncio.wait_for(channel.channel_ready(), timeout=10)
            rpc = channel.unary_unary(_METHOD, _registered_method=True)
            for _ in range(WARMUP):
                if await rpc(wire) != wire:
                    raise SystemExit("gRPC aio echo returned different bytes")
            rates: list[tuple[int, float]] = []
            for conc in INFLIGHT:
                print(f"  [grpc aio] measuring {N} calls, {conc} in flight…", flush=True)
                elapsed = await _aio_window(rpc, wire, N, conc)
                rates.append((conc, _report(f"gRPC aio x{conc}", elapsed, N)))
            return rates
        finally:
            await channel.close()

    try:
        return asyncio.run(run())
    finally:
        _stop(proc)


# ── daffi ─────────────────────────────────────────────────────────────────────


def _serve_daffi(port: int, runtime: str) -> None:
    import tests.conftest as runtime_state
    from daffi import Service, TCPTransport, callback, dfcore

    runtime_state.SELECTED_RUNTIME = runtime
    dfcore.setRuntime(runtime)

    @callback
    def echo(payload):
        return payload

    svc = Service(
        app_name="grpc-cmp-svc",
        transport=TCPTransport(HOST, port),
        runtime=runtime,
        workers=1,
    )
    svc.start()
    svc.join()


def _proc_daffi(port: int, runtime: str) -> None:
    _child(_serve_daffi, port, runtime)


def _daffi_client(port: int, runtime: str, serde):
    from daffi import Client, TCPTransport

    client = Client(
        app_name="grpc-cmp-cli",
        transport=TCPTransport(HOST, port),
        runtime=runtime,
    )
    echo = client.connect().rpc(timeout=30, serde=serde).echo
    return client, echo


def bench_daffi_opaque(wire: bytes, runtime: str) -> float:
    from daffi import SerdeFormat

    proc, port = _start(_proc_daffi, runtime)
    time.sleep(0.15)
    try:
        client, echo = _daffi_client(port, runtime, SerdeFormat.OPAQUE)
        try:
            for _ in range(WARMUP):
                if echo(wire) != wire:
                    raise SystemExit("daffi OPAQUE echo returned different bytes")
            print(f"  [daffi opaque] measuring {N} calls…", flush=True)
            return _report("daffi OPAQUE", _elapsed(lambda: echo(wire), N), N)
        finally:
            client.stop()
    finally:
        _stop(proc)


def bench_daffi_msgpack(payload: object, runtime: str) -> float:
    from daffi import SerdeFormat

    proc, port = _start(_proc_daffi, runtime)
    time.sleep(0.15)
    try:
        client, echo = _daffi_client(port, runtime, SerdeFormat.MSGPACK)
        try:
            for _ in range(WARMUP):
                if echo(payload) != payload:
                    raise SystemExit("daffi MSGPACK echo changed the object")
            print(f"  [daffi msgpack] measuring {N} calls…", flush=True)
            return _report(
                "daffi MSGPACK", _elapsed(lambda: echo(payload), N), N
            )
        finally:
            client.stop()
    finally:
        _stop(proc)


def bench_daffi_inflight(wire: bytes, runtime: str) -> list[tuple[int, float]]:
    from daffi import SerdeFormat

    proc, port = _start(_proc_daffi, runtime)
    time.sleep(0.15)
    rates: list[tuple[int, float]] = []
    try:
        client, echo = _daffi_client(port, runtime, SerdeFormat.OPAQUE)
        try:
            for _ in range(WARMUP):
                if echo(wire) != wire:
                    raise SystemExit("daffi OPAQUE echo returned different bytes")
            for conc in INFLIGHT:
                print(
                    f"  [daffi opaque] measuring {N} calls, {conc} in flight…",
                    flush=True,
                )
                with ThreadPoolExecutor(max_workers=conc) as pool:
                    t0 = time.perf_counter()
                    futs = [pool.submit(echo, wire) for _ in range(N)]
                    for fut in futs:
                        fut.result()
                    elapsed = time.perf_counter() - t0
                rates.append((conc, _report(f"daffi OPAQUE x{conc}", elapsed, N)))
            return rates
        finally:
            client.stop()
    finally:
        _stop(proc)


def _line(label: str, rate: float) -> None:
    print(f"  {label:<22}  {rate:>10.0f}")


def main() -> None:
    logging.disable(logging.INFO)
    try:
        import grpc
    except ImportError:
        print(
            "grpcio not installed — pip install grpcio grpcio-tools protobuf",
            file=sys.stderr,
        )
        sys.exit(1)

    data = json.loads(_DATA_FILE.read_text())
    wire = json.dumps(data).encode()
    runtime = active_runtime()

    print(
        f"\nFair unary echo  —  grpcio {grpc.__version__} vs daffi"
        f"  —  {N} calls, {len(wire)} bytes, no TLS"
    )
    print(f"host: {HOST}   warmup: {WARMUP}   daffi runtime: {runtime}")
    print("payload: the same JSON bytes.  OPAQUE and gRPC raw do not parse them.")
    print("gRPC: minimal_stack, retries off, no per-call deadline, registered method.\n")

    print("── Sequential, 1 in flight ──────────────────────────────")
    proto = bench_grpc_proto(wire)
    raw = bench_grpc_raw(wire)
    opaque = bench_daffi_opaque(wire, runtime)
    print()
    msgpack = bench_daffi_msgpack(data, runtime)

    print("\n── Several unary calls in flight (raw / OPAQUE) ────────")
    print("  gRPC uses grpc.aio on one channel.  daffi uses threads, workers=1.\n")
    aio_rates = bench_grpc_aio(wire)
    daffi_rates = bench_daffi_inflight(wire, runtime)

    best_aio_conc, best_aio_rate = max(aio_rates, key=lambda item: item[1])
    best_daffi_conc, best_daffi_rate = max(daffi_rates, key=lambda item: item[1])
    grpc_rows = (
        ("gRPC protobuf", proto),
        ("gRPC raw bytes", raw),
        (f"gRPC aio x{best_aio_conc}", best_aio_rate),
    )
    daffi_rows = (
        ("daffi OPAQUE", opaque),
        (f"daffi OPAQUE x{best_daffi_conc}", best_daffi_rate),
    )
    grpc_name, grpc_best = max(grpc_rows, key=lambda item: item[1])
    daffi_name, daffi_best = max(daffi_rows, key=lambda item: item[1])

    print("\n── Summary (calls/s) ───────────────────────────────────")
    print(f"  {'stack':<22}  {'calls/s':>10}")
    print(f"  {'----------------------':<22}  {'----------':>10}")
    _line("gRPC protobuf", proto)
    _line("gRPC raw bytes", raw)
    _line("daffi OPAQUE", opaque)
    _line("daffi MSGPACK", msgpack)
    print()
    for conc, rate in aio_rates:
        _line(f"gRPC aio x{conc}", rate)
    for conc, rate in daffi_rates:
        _line(f"daffi OPAQUE x{conc}", rate)

    print("\n  Equal work is OPAQUE vs gRPC (same bytes, no JSON parse).")
    print("  MSGPACK also builds and reads the dict on every call.")
    print(
        f"\n  1 in flight:  daffi OPAQUE is {opaque / raw:.2f}× gRPC raw"
        f"  and {opaque / proto:.2f}× gRPC protobuf"
    )
    print(
        f"  fastest row:  {daffi_name} is {daffi_best / grpc_best:.2f}× {grpc_name}"
        f"   ({daffi_best:.0f} vs {grpc_best:.0f} calls/s)"
    )
    print(
        f"  MSGPACK vs that gRPC row: {msgpack / grpc_best:.2f}×"
        f"   ({msgpack:.0f} vs {grpc_best:.0f}), dict round-trip included\n"
    )


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
