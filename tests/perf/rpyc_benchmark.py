"""
RPyC performance benchmark — comparable to perf_benchmark.py.

Layouts
-------
1. Direct     — Client → Server  (one TCP hop, ThreadedServer)
2. Via Proxy  — Client → Proxy → Worker
                The Proxy server receives each call and forwards it to a
                backend Worker server — the closest RPyC equivalent to daffi's
                Client → Router → Worker topology.

Payload
-------
Same ``data.json`` used by perf_benchmark.py — a realistic nested order record
(~2 KB).  The server echoes it back unchanged so the comparison is apples-to-apples.

Run::

    python3 tests/perf/rpyc_benchmark.py
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

# ── constants ──────────────────────────────────────────────────────────────────

_DATA_FILE = Path(__file__).parent / "data.json"

N      = 100_000  # measured calls per layout — same as perf_benchmark.py
WARMUP = 20
TIMEOUT = 30
HOST   = "127.0.0.1"

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


def _silence() -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)


def _report(label: str, latencies_ms: list[float]) -> None:
    n = len(latencies_ms)
    total_s = sum(latencies_ms) / 1_000
    print(f"  {label}: {total_s:.3f} s for {n} calls  ({n / total_s:.0f} calls/s)")


# ── subprocess entry points ────────────────────────────────────────────────────

def _proc_rpyc_server(port: int) -> None:
    _silence()
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


def _proc_rpyc_worker(port: int) -> None:
    _silence()
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


def _proc_rpyc_proxy(proxy_port: int, worker_port: int) -> None:
    _silence()
    import rpyc
    from rpyc.utils.server import ThreadedServer

    _backend: list = []

    class ProxyService(rpyc.Service):
        def on_connect(self, conn):
            if not _backend:
                _backend.append(
                    rpyc.connect(HOST, worker_port, config={"allow_public_attrs": True})
                )

        def exposed_echo(self, payload):
            return _backend[0].root.echo(payload)

    ThreadedServer(
        ProxyService,
        hostname=HOST,
        port=proxy_port,
        protocol_config={"allow_public_attrs": True},
    ).start()


# ── benchmark functions ────────────────────────────────────────────────────────

def bench_rpyc_direct(data: dict) -> list[float]:
    import rpyc

    port = _free_port()
    proc = mp.Process(target=_proc_rpyc_server, args=(port,), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        conn = rpyc.connect(HOST, port, config={"allow_public_attrs": True, "sync_request_timeout": TIMEOUT})
        svc = conn.root

        print(f"  [rpyc-direct] warming up ({WARMUP} calls)…", end="", flush=True)
        for _ in range(WARMUP):
            svc.echo(data)
        print(" done")

        print(f"  [rpyc-direct] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for _ in range(N):
            t0 = time.perf_counter()
            svc.echo(data)
            latencies.append((time.perf_counter() - t0) * 1_000)
        print(" done")

        conn.close()
        return latencies
    finally:
        proc.terminate()
        proc.join(timeout=5)


def bench_rpyc_via_proxy(data: dict) -> list[float]:
    import rpyc

    worker_port = _free_port()
    proxy_port  = _free_port()

    worker_proc = mp.Process(target=_proc_rpyc_worker, args=(worker_port,), daemon=True)
    proxy_proc  = mp.Process(target=_proc_rpyc_proxy,  args=(proxy_port, worker_port), daemon=True)

    worker_proc.start()
    try:
        _wait_for_port(worker_port)
        proxy_proc.start()
        _wait_for_port(proxy_port)
        time.sleep(0.1)

        conn = rpyc.connect(HOST, proxy_port, config={"allow_public_attrs": True, "sync_request_timeout": TIMEOUT})
        svc = conn.root

        print(f"  [rpyc-proxy] warming up ({WARMUP} calls)…", end="", flush=True)
        for _ in range(WARMUP):
            svc.echo(data)
        print(" done")

        print(f"  [rpyc-proxy] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for _ in range(N):
            t0 = time.perf_counter()
            svc.echo(data)
            latencies.append((time.perf_counter() - t0) * 1_000)
        print(" done")

        conn.close()
        return latencies
    finally:
        proxy_proc.terminate()
        proxy_proc.join(timeout=5)
        worker_proc.terminate()
        worker_proc.join(timeout=5)


# ── main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    logging.disable(logging.INFO)

    import rpyc as _rpyc

    data: dict = json.loads(_DATA_FILE.read_text())
    payload_bytes = len(json.dumps(data).encode())

    print(f"\nRPyC {_rpyc.__version__} performance benchmark  —  {N} sequential calls per layout")
    print(f"host: {HOST}   warmup: {WARMUP} calls   timeout: {TIMEOUT}s")
    print(f"payload: {_DATA_FILE.name}  ({payload_bytes} bytes JSON)\n")

    print("Layout 1: Direct (Client → Server)")
    direct_lat = bench_rpyc_direct(data)
    _report("Direct: Client → Server", direct_lat)

    print("\nLayout 2: Via Proxy (Client → Proxy → Worker)")
    proxy_lat = bench_rpyc_via_proxy(data)
    _report("Via Proxy: Client → Proxy → Worker", proxy_lat)

    d_avg_s = sum(direct_lat) / len(direct_lat) / 1_000
    r_avg_s = sum(proxy_lat)  / len(proxy_lat)  / 1_000
    print(f"\n  Proxy overhead vs direct: {(r_avg_s - d_avg_s) * 1000:+.3f} ms / call\n")


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
