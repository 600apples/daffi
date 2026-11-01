"""
ZeroMQ / nng vs daffi — sequential echo round-trips.

Compares request/reply latency on the same ~2 KB ``data.json`` payload used by
``perf_benchmark.py``.  Messaging libraries (ZMQ, nng) have no RPC framing, so
the wire body is raw JSON bytes; daffi uses ``SerdeFormat.OPAQUE`` so it also
avoids pickle/msgpack overhead.

Transports
----------
  TCP  — loopback ``127.0.0.1``
  UDS  — Unix domain socket / ZMQ ``ipc://`` / nng ``ipc://``  (same-machine)

Stacks (each run Direct only — one client, one server)
------------------------------------------------------
  daffi   Client → Service
  ZeroMQ  REQ    → REP
  nng     Req0   → Rep0

Missing optional packages are skipped with a notice::

    pip install pyzmq pynng

Run::

    python3 tests/perf/zmq_nng_benchmark.py
"""

from __future__ import annotations

import json
import logging
import multiprocessing as mp
import os
import socket
import sys
import tempfile
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
from tests.conftest import active_runtime

# ── constants ─────────────────────────────────────────────────────────────────

_DATA_FILE = Path(__file__).parent / "data.json"

N = 100_000
WARMUP = 20
TIMEOUT = 30
HOST = "127.0.0.1"

# ── helpers ───────────────────────────────────────────────────────────────────


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


def _wait_for_unix(path: str, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if os.path.exists(path):
            try:
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                    s.settimeout(0.1)
                    s.connect(path)
                    return
            except OSError:
                pass
        time.sleep(0.05)
    raise TimeoutError(f"Unix socket {path!r} did not become ready within {timeout}s")


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


def _tmp_ipc_path(prefix: str) -> str:
    """Absolute path under /tmp suitable for ZMQ/nng ipc:// and daffi UnixTransport."""
    fd, path = tempfile.mkstemp(prefix=f"daffi-perf-{prefix}-", suffix=".ipc")
    os.close(fd)
    os.unlink(path)  # bind creates the node
    return path


def _report(label: str, latencies_ms: list[float]) -> float:
    n = len(latencies_ms)
    total_s = sum(latencies_ms) / 1_000
    rate = n / total_s
    print(f"  {label}: {total_s:.3f} s for {n} calls  ({rate:.0f} calls/s)")
    return rate


def _measure(label: str, call) -> list[float]:
    print(f"  [{label}] warming up ({WARMUP} calls)…", end="", flush=True)
    for _ in range(WARMUP):
        call()
    print(" done")
    print(f"  [{label}] measuring {N} calls…", end="", flush=True)
    latencies: list[float] = []
    for _ in range(N):
        t0 = time.perf_counter()
        call()
        latencies.append((time.perf_counter() - t0) * 1_000)
    print(" done")
    return latencies


# ── daffi ─────────────────────────────────────────────────────────────────────


def _proc_daffi_tcp(runtime: str, port: int) -> None:
    _silence_daffi(runtime)
    from daffi import Service, TCPTransport, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="zmq-cmp-svc", transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def _proc_daffi_uds(runtime: str, path: str) -> None:
    _silence_daffi(runtime)
    from daffi import Service, UnixTransport, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="zmq-cmp-svc", transport=UnixTransport(path), runtime=runtime)
    svc.start()
    svc.join()


def bench_daffi_tcp(wire: str) -> list[float]:
    from daffi import Client, TCPTransport
    from daffi._serialization import SerdeFormat

    port = _free_port()
    proc = mp.Process(target=_proc_daffi_tcp, args=(active_runtime(), port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)
        client = Client(
            app_name="zmq-cmp-cli",
            transport=TCPTransport(HOST, port),
            runtime=active_runtime(),
        )
        c = client.connect().rpc(timeout=TIMEOUT, serde=SerdeFormat.OPAQUE)
        try:
            return _measure("daffi-tcp", lambda: c.echo(wire))
        finally:
            client.stop()
    finally:
        proc.terminate()
        proc.join(timeout=5)


def bench_daffi_uds(wire: str) -> list[float]:
    from daffi import Client, UnixTransport
    from daffi._serialization import SerdeFormat

    path = _tmp_ipc_path("daffi")
    proc = mp.Process(target=_proc_daffi_uds, args=(active_runtime(), path), daemon=True)
    proc.start()
    try:
        _wait_for_unix(path)
        time.sleep(0.15)
        client = Client(
            app_name="zmq-cmp-cli",
            transport=UnixTransport(path),
            runtime=active_runtime(),
        )
        c = client.connect().rpc(timeout=TIMEOUT, serde=SerdeFormat.OPAQUE)
        try:
            return _measure("daffi-uds", lambda: c.echo(wire))
        finally:
            client.stop()
    finally:
        proc.terminate()
        proc.join(timeout=5)
        try:
            os.unlink(path)
        except OSError:
            pass


# ── ZeroMQ ────────────────────────────────────────────────────────────────────


def _proc_zmq_rep(endpoint: str) -> None:
    _silence()
    import zmq

    ctx = zmq.Context()
    sock = ctx.socket(zmq.REP)
    sock.bind(endpoint)
    try:
        while True:
            msg = sock.recv()
            sock.send(msg)
    finally:
        sock.close(0)
        ctx.term()


def _bench_zmq(label: str, bind_ep: str, connect_ep: str, wire: bytes) -> list[float]:
    import zmq

    proc = mp.Process(target=_proc_zmq_rep, args=(bind_ep,), daemon=True)
    proc.start()
    try:
        time.sleep(0.2)
        ctx = zmq.Context()
        sock = ctx.socket(zmq.REQ)
        sock.setsockopt(zmq.LINGER, 0)
        sock.setsockopt(zmq.RCVTIMEO, TIMEOUT * 1000)
        sock.setsockopt(zmq.SNDTIMEO, TIMEOUT * 1000)
        sock.connect(connect_ep)
        try:
            return _measure(label, lambda: (sock.send(wire), sock.recv()))
        finally:
            sock.close(0)
            ctx.term()
    finally:
        proc.terminate()
        proc.join(timeout=5)


def bench_zmq_tcp(wire: bytes) -> list[float]:
    port = _free_port()
    ep = f"tcp://{HOST}:{port}"
    return _bench_zmq("zmq-tcp", ep, ep, wire)


def bench_zmq_ipc(wire: bytes) -> list[float]:
    path = _tmp_ipc_path("zmq")
    ep = f"ipc://{path}"
    try:
        return _bench_zmq("zmq-ipc", ep, ep, wire)
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


# ── nng ───────────────────────────────────────────────────────────────────────


def _proc_nng_rep(url: str) -> None:
    _silence()
    import pynng

    with pynng.Rep0(listen=url) as sock:
        while True:
            msg = sock.recv()
            sock.send(msg)


def _bench_nng(label: str, listen_url: str, dial_url: str, wire: bytes) -> list[float]:
    import pynng

    proc = mp.Process(target=_proc_nng_rep, args=(listen_url,), daemon=True)
    proc.start()
    try:
        time.sleep(0.25)
        with pynng.Req0(dial=dial_url) as sock:
            sock.send_timeout = TIMEOUT * 1000
            sock.recv_timeout = TIMEOUT * 1000

            def _call():
                sock.send(wire)
                sock.recv()

            return _measure(label, _call)
    finally:
        proc.terminate()
        proc.join(timeout=5)


def bench_nng_tcp(wire: bytes) -> list[float]:
    port = _free_port()
    url = f"tcp://{HOST}:{port}"
    return _bench_nng("nng-tcp", url, url, wire)


def bench_nng_ipc(wire: bytes) -> list[float]:
    path = _tmp_ipc_path("nng")
    # nng wants an abstract-ish path; use absolute file path under ipc://
    url = f"ipc://{path}"
    try:
        return _bench_nng("nng-ipc", url, url, wire)
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


# ── main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    logging.disable(logging.INFO)

    data = json.loads(_DATA_FILE.read_text())
    wire_str = json.dumps(data)
    wire_bytes = wire_str.encode()
    payload_bytes = len(wire_bytes)

    has_zmq = False
    has_nng = False
    zmq_ver = nng_ver = ""
    try:
        import zmq

        has_zmq = True
        zmq_ver = f"{zmq.pyzmq_version()} (libzmq {zmq.zmq_version()})"
    except ImportError:
        print("  [skip] pyzmq not installed — ZeroMQ rows omitted  (pip install pyzmq)")

    try:
        import pynng

        has_nng = True
        nng_ver = getattr(pynng, "__version__", "unknown")
    except ImportError:
        print("  [skip] pynng not installed — nng rows omitted  (pip install pynng)")

    print(
        f"\ndaffi vs ZeroMQ vs nng  —  {N} sequential echo round-trips"
    )
    print(f"host: {HOST}   warmup: {WARMUP}   payload: {_DATA_FILE.name} ({payload_bytes} bytes JSON)")
    print("wire: raw JSON bytes; daffi uses SerdeFormat.OPAQUE (no pickle/msgpack)\n")

    results: list[tuple[str, str, float]] = []

    print("── daffi (OPAQUE) ──────────────────────────────────────")
    print("  TCP")
    results.append(("daffi", "TCP", _report("daffi TCP", bench_daffi_tcp(wire_str))))
    print("  UDS")
    results.append(("daffi", "UDS", _report("daffi UDS", bench_daffi_uds(wire_str))))

    if has_zmq:
        print(f"\n── ZeroMQ REQ/REP  (pyzmq {zmq_ver}) ────────────────")
        print("  TCP")
        results.append(("ZeroMQ", "TCP", _report("zmq TCP", bench_zmq_tcp(wire_bytes))))
        print("  IPC (Unix)")
        results.append(("ZeroMQ", "IPC", _report("zmq IPC", bench_zmq_ipc(wire_bytes))))

    if has_nng:
        print(f"\n── nng req/rep  (pynng {nng_ver}) ─────────────────────")
        print("  TCP")
        results.append(("nng", "TCP", _report("nng TCP", bench_nng_tcp(wire_bytes))))
        print("  IPC (Unix)")
        results.append(("nng", "IPC", _report("nng IPC", bench_nng_ipc(wire_bytes))))

    print("\n── Summary (calls/s) ───────────────────────────────────")
    print(f"  {'stack':<10}  {'transport':<8}  {'calls/s':>10}")
    print(f"  {'----------':<10}  {'--------':<8}  {'----------':>10}")
    for stack, transport, rate in results:
        print(f"  {stack:<10}  {transport:<8}  {rate:>10.0f}")
    print()


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
