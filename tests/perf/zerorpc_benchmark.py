"""
ZeroRPC performance benchmark — comparable to perf_benchmark.py / rpyc_benchmark.py.

Layout
------
Direct — Client → Server  (REQ/REP over ZeroMQ under the hood)

Also runs a daffi Client → Service baseline (PICKLE) on the same payload.

Payload: ``data.json`` (~2 KB), echoed unchanged.

Requires::

    pip install zerorpc   # pulls in pyzmq + gevent

Run::

    python3 tests/perf/zerorpc_benchmark.py

Note: ZeroRPC's server is gevent-based; the worker process installs gevent before
serving.  This is still a fair sequential-RPC comparison (one client, one call
at a time).
"""

from __future__ import annotations

import json
import logging
import multiprocessing as mp
import os
import socket
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
from tests.conftest import active_runtime

_DATA_FILE = Path(__file__).parent / "data.json"

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


# ── ZeroRPC ───────────────────────────────────────────────────────────────────


def _proc_zerorpc(port: int) -> None:
    _silence()
    # gevent must be active in this process before zerorpc serves.
    import gevent.monkey

    gevent.monkey.patch_all()
    import zerorpc

    class Echo:
        def echo(self, payload):
            return payload

    srv = zerorpc.Server(Echo())
    srv.bind(f"tcp://{HOST}:{port}")
    srv.run()


def bench_zerorpc(data: dict) -> list[float]:
    import zerorpc

    port = _free_port()
    proc = mp.Process(target=_proc_zerorpc, args=(port,), daemon=True)
    proc.start()
    try:
        # ZMQ bind is not a normal TCP listen until first connect; retry client.
        deadline = time.monotonic() + 15.0
        client = None
        last_err: Exception | None = None
        while time.monotonic() < deadline:
            try:
                client = zerorpc.Client(timeout=TIMEOUT)
                client.connect(f"tcp://{HOST}:{port}")
                client.echo(data)  # probe
                break
            except Exception as exc:  # noqa: BLE001 — probe until ready
                last_err = exc
                if client is not None:
                    try:
                        client.close()
                    except Exception:
                        pass
                    client = None
                time.sleep(0.05)
        else:
            raise TimeoutError(f"ZeroRPC server not ready: {last_err!r}")

        assert client is not None
        try:
            return _measure("zerorpc", lambda: client.echo(data))
        finally:
            client.close()
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

    svc = Service(app_name="zrpc-cmp-svc", transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def bench_daffi_pickle(data: dict) -> list[float]:
    from daffi import Client, TCPTransport
    from daffi._serialization import SerdeFormat

    port = _free_port()
    proc = mp.Process(target=_proc_daffi, args=(active_runtime(), port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)
        client = Client(
            app_name="zrpc-cmp-cli",
            transport=TCPTransport(HOST, port),
            runtime=active_runtime(),
        )
        c = client.connect().rpc(timeout=TIMEOUT, serde=SerdeFormat.PICKLE)
        try:
            return _measure("daffi-pickle", lambda: c.echo(data))
        finally:
            client.stop()
    finally:
        proc.terminate()
        proc.join(timeout=5)


def main() -> None:
    logging.disable(logging.INFO)
    try:
        import zerorpc
    except ImportError:
        print("zerorpc not installed — pip install zerorpc", file=sys.stderr)
        sys.exit(1)

    data = json.loads(_DATA_FILE.read_text())
    payload_bytes = len(json.dumps(data).encode())
    ver = getattr(zerorpc, "__version__", "unknown")

    print(f"\nZeroRPC {ver} vs daffi  —  {N} sequential rpc calls")
    print(f"host: {HOST}   warmup: {WARMUP}   payload: {_DATA_FILE.name} ({payload_bytes} bytes JSON)")
    print("layout: Direct; daffi serde=PICKLE (object RPC peer)\n")

    print("── ZeroRPC ──────────────────────────────────────────────")
    zrpc_rate = _report("ZeroRPC", bench_zerorpc(data))

    print("\n── daffi (PICKLE) ──────────────────────────────────────")
    daffi_rate = _report("daffi PICKLE", bench_daffi_pickle(data))

    print("\n── Summary (calls/s) ───────────────────────────────────")
    print(f"  {'stack':<16}  {'calls/s':>10}")
    print(f"  {'----------------':<16}  {'----------':>10}")
    print(f"  {'ZeroRPC':<16}  {zrpc_rate:>10.0f}")
    print(f"  {'daffi PICKLE':<16}  {daffi_rate:>10.0f}")
    if zrpc_rate > 0:
        print(f"\n  daffi vs ZeroRPC: {daffi_rate / zrpc_rate:.2f}×\n")


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
