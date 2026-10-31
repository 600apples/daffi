"""
gRPC performance benchmark — comparable to perf_benchmark.py.

Layout
------
Direct — unary Client → Server  (HTTP/2 over TCP loopback)

Payload is the same ``data.json`` pre-encoded as JSON bytes and carried in a
protobuf ``bytes`` field.  daffi baseline uses ``SerdeFormat.OPAQUE`` so both
sides avoid object serialization and only pay RPC + transport overhead.

Requires::

    pip install grpcio grpcio-tools protobuf

Run::

    python3 tests/perf/grpc_benchmark.py

Generated stubs land in ``tests/perf/grpc_echo/`` (created on first run).
"""

from __future__ import annotations

import json
import logging
import multiprocessing as mp
import os
import socket
import sys
import time
from concurrent import futures
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
from tests.conftest import active_runtime

_DATA_FILE = Path(__file__).parent / "data.json"
_GRPC_DIR = Path(__file__).parent / "grpc_echo"
_PROTO = _GRPC_DIR / "echo.proto"

N = 100_000
WARMUP = 20
TIMEOUT = 30
HOST = "127.0.0.1"


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
    raise TimeoutError(f"Server on {HOST}:{port} did not become ready within {timeout}s")


def _silence() -> None:
    dn = os.open(os.devnull, os.O_WRONLY)
    os.dup2(dn, 1)
    os.dup2(dn, 2)
    os.close(dn)
    logging.disable(logging.CRITICAL)


def _silence_daffi(runtime: str) -> None:
    _silence()
    import tests.conftest as _runtime_state

    _runtime_state.SELECTED_RUNTIME = runtime
    from daffi import dfcore

    dfcore.setRuntime(runtime)


def _report(label: str, latencies_ms: list[float]) -> float:
    n = len(latencies_ms)
    total_s = sum(latencies_ms) / 1_000
    rate = n / total_s
    print(f"  {label}: {total_s:.3f} s for {n} calls  ({rate:.0f} calls/s)")
    return rate


def _measure(tag: str, call) -> list[float]:
    print(f"  [{tag}] warming up ({WARMUP} calls)…", end="", flush=True)
    for _ in range(WARMUP):
        call()
    print(" done")
    print(f"  [{tag}] measuring {N} calls…", end="", flush=True)
    latencies: list[float] = []
    for _ in range(N):
        t0 = time.perf_counter()
        call()
        latencies.append((time.perf_counter() - t0) * 1_000)
    print(" done")
    return latencies


def _ensure_grpc_stubs() -> None:
    """Generate echo_pb2*.py next to echo.proto if missing."""
    pb2 = _GRPC_DIR / "echo_pb2.py"
    pb2_grpc = _GRPC_DIR / "echo_pb2_grpc.py"
    if pb2.exists() and pb2_grpc.exists():
        return
    try:
        from grpc_tools import protoc
    except ImportError as exc:
        raise SystemExit(
            "grpcio-tools required to generate stubs — pip install grpcio-tools"
        ) from exc

    _GRPC_DIR.mkdir(parents=True, exist_ok=True)
    init = _GRPC_DIR / "__init__.py"
    if not init.exists():
        init.write_text("")

    rc = protoc.main(
        [
            "grpc_tools.protoc",
            f"-I{_GRPC_DIR}",
            f"--python_out={_GRPC_DIR}",
            f"--grpc_python_out={_GRPC_DIR}",
            str(_PROTO),
        ]
    )
    if rc != 0:
        raise SystemExit(f"protoc failed with exit code {rc}")

    # Fix generated absolute-ish import for package-less layout.
    text = pb2_grpc.read_text()
    pb2_grpc.write_text(text.replace("import echo_pb2 as", "from . import echo_pb2 as"))


# ── gRPC ──────────────────────────────────────────────────────────────────────


def _proc_grpc(port: int) -> None:
    _silence()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import grpc
    from grpc_echo import echo_pb2, echo_pb2_grpc

    class EchoServicer(echo_pb2_grpc.EchoServicer):
        def Echo(self, request, context):  # noqa: N802 — gRPC naming
            return echo_pb2.EchoReply(data=request.data)

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=4))
    echo_pb2_grpc.add_EchoServicer_to_server(EchoServicer(), server)
    server.add_insecure_port(f"{HOST}:{port}")
    server.start()
    server.wait_for_termination()


def bench_grpc(wire: bytes) -> list[float]:
    import grpc

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from grpc_echo import echo_pb2, echo_pb2_grpc

    port = _free_port()
    proc = mp.Process(target=_proc_grpc, args=(port,), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.1)
        channel = grpc.insecure_channel(f"{HOST}:{port}")
        stub = echo_pb2_grpc.EchoStub(channel)
        req = echo_pb2.EchoRequest(data=wire)
        try:
            return _measure(
                "grpc",
                lambda: stub.Echo(req, timeout=TIMEOUT),
            )
        finally:
            channel.close()
    finally:
        proc.terminate()
        proc.join(timeout=5)


# ── daffi baseline ────────────────────────────────────────────────────────────


def _proc_daffi(runtime: str, port: int) -> None:
    _silence_daffi(runtime)
    from daffi import Service, TCPTransport, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="grpc-cmp-svc", transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def bench_daffi_opaque(wire_str: str) -> list[float]:
    from daffi import Client, TCPTransport
    from daffi._serialization import SerdeFormat

    port = _free_port()
    proc = mp.Process(target=_proc_daffi, args=(active_runtime(), port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)
        client = Client(
            app_name="grpc-cmp-cli",
            transport=TCPTransport(HOST, port),
            runtime=active_runtime(),
        )
        c = client.connect().rpc(timeout=TIMEOUT, serde=SerdeFormat.OPAQUE)
        try:
            return _measure("daffi-opaque", lambda: c.echo(wire_str))
        finally:
            client.stop()
    finally:
        proc.terminate()
        proc.join(timeout=5)


def main() -> None:
    logging.disable(logging.INFO)
    try:
        import grpc
    except ImportError:
        print("grpcio not installed — pip install grpcio grpcio-tools protobuf", file=sys.stderr)
        sys.exit(1)

    _ensure_grpc_stubs()

    data = json.loads(_DATA_FILE.read_text())
    wire_str = json.dumps(data)
    wire_bytes = wire_str.encode()
    payload_bytes = len(wire_bytes)

    print(f"\ngRPC {grpc.__version__} vs daffi  —  {N} sequential unary rpc calls")
    print(f"host: {HOST}   warmup: {WARMUP}   payload: {_DATA_FILE.name} ({payload_bytes} bytes JSON)")
    print("wire: JSON bytes in protobuf `bytes` field; daffi serde=OPAQUE\n")

    print("── gRPC ─────────────────────────────────────────────────")
    grpc_rate = _report("gRPC", bench_grpc(wire_bytes))

    print("\n── daffi (OPAQUE) ──────────────────────────────────────")
    daffi_rate = _report("daffi OPAQUE", bench_daffi_opaque(wire_str))

    print("\n── Summary (calls/s) ───────────────────────────────────")
    print(f"  {'stack':<16}  {'calls/s':>10}")
    print(f"  {'----------------':<16}  {'----------':>10}")
    print(f"  {'gRPC':<16}  {grpc_rate:>10.0f}")
    print(f"  {'daffi OPAQUE':<16}  {daffi_rate:>10.0f}")
    if grpc_rate > 0:
        print(f"\n  daffi vs gRPC: {daffi_rate / grpc_rate:.2f}×\n")


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
