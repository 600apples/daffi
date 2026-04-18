"""
RPyC performance benchmark — comparable to perf_benchmark.py.

Layouts
-------
1. Direct     — Client → Server  (one TCP hop, ThreadedServer)
2. Via Proxy  — Client → Proxy → Worker
                The Proxy server receives each call and forwards it to a
                backend Worker server — the closest RPyC equivalent to daffi's
                Client → Router → Worker topology.

Run directly::

    python3 tests/rpyc_benchmark.py
"""

from __future__ import annotations

import logging
import multiprocessing as mp
import os
import socket
import sys
import time

# ── constants ──────────────────────────────────────────────────────────────────

N      = 1_000_00   # measured calls per layout (keep same as perf_benchmark.py)
WARMUP = 20      # throwaway calls before measurement
TIMEOUT = 30     # per-call timeout (seconds)
HOST   = "127.0.0.1"

# ── helpers (identical to perf_benchmark.py so output is comparable) ──────────

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
    """Redirect stdout/stderr to /dev/null and kill Python logging."""
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
    """Background process: plain RPyC ThreadedServer exposing ping()."""
    _silence()
    import rpyc
    from rpyc.utils.server import ThreadedServer

    class PingService(rpyc.Service):
        def exposed_ping(self, x: int) -> int:
            return x

    srv = ThreadedServer(
        PingService,
        hostname=HOST,
        port=port,
        protocol_config={"allow_public_attrs": True},
    )
    srv.start()


def _proc_rpyc_worker(port: int) -> None:
    """Background process: backend worker server for the proxy layout."""
    _silence()
    import rpyc
    from rpyc.utils.server import ThreadedServer

    class WorkerService(rpyc.Service):
        def exposed_ping(self, x: int) -> int:
            return x

    srv = ThreadedServer(
        WorkerService,
        hostname=HOST,
        port=port,
        protocol_config={"allow_public_attrs": True},
    )
    srv.start()


def _proc_rpyc_proxy(proxy_port: int, worker_port: int) -> None:
    """Background process: proxy server that forwards every call to the worker.

    This is the RPyC equivalent of daffi's Router.  Each incoming call on
    ``exposed_ping`` is synchronously forwarded to the worker's
    ``exposed_ping``, adding one extra TCP round-trip per call.
    """
    _silence()
    import rpyc
    from rpyc.utils.server import ThreadedServer

    # Connect once to the backend worker and reuse the connection.
    _backend: list = []  # mutable container so the nested class can capture it

    class ProxyService(rpyc.Service):
        def on_connect(self, conn):
            if not _backend:
                _backend.append(
                    rpyc.connect(
                        HOST,
                        worker_port,
                        config={"allow_public_attrs": True},
                    )
                )

        def exposed_ping(self, x: int) -> int:
            return _backend[0].root.ping(x)

    srv = ThreadedServer(
        ProxyService,
        hostname=HOST,
        port=proxy_port,
        protocol_config={"allow_public_attrs": True},
    )
    srv.start()


# ── benchmark functions ────────────────────────────────────────────────────────

def bench_rpyc_direct() -> list[float]:
    """RPyC benchmark: Client → Server (single hop)."""
    import rpyc

    port = _free_port()
    proc = mp.Process(target=_proc_rpyc_server, args=(port,), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)

        conn = rpyc.connect(
            HOST, port, config={"allow_public_attrs": True, "sync_request_timeout": TIMEOUT}
        )
        svc = conn.root

        print(f"  [rpyc-direct] warming up ({WARMUP} calls)…", end="", flush=True)
        for i in range(WARMUP):
            assert svc.ping(i) == i
        print(" done")

        print(f"  [rpyc-direct] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for i in range(N):
            t0 = time.perf_counter()
            result = svc.ping(i)
            latencies.append((time.perf_counter() - t0) * 1_000)
            assert result == i, f"expected {i}, got {result}"
        print(" done")

        conn.close()
        return latencies
    finally:
        proc.terminate()
        proc.join(timeout=5)


def bench_rpyc_via_proxy() -> list[float]:
    """RPyC benchmark: Client → Proxy → Worker (two hops)."""
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
        time.sleep(0.1)  # let the proxy finish its on_connect handshake

        conn = rpyc.connect(
            HOST, proxy_port,
            config={"allow_public_attrs": True, "sync_request_timeout": TIMEOUT},
        )
        svc = conn.root

        print(f"  [rpyc-proxy] warming up ({WARMUP} calls)…", end="", flush=True)
        for i in range(WARMUP):
            assert svc.ping(i) == i
        print(" done")

        print(f"  [rpyc-proxy] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for i in range(N):
            t0 = time.perf_counter()
            result = svc.ping(i)
            latencies.append((time.perf_counter() - t0) * 1_000)
            assert result == i, f"expected {i}, got {result}"
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
    print(f"\nRPyC {_rpyc.__version__} performance benchmark  —  {N} sequential calls per layout")
    print(f"host: {HOST}   warmup: {WARMUP} calls   timeout: {TIMEOUT}s\n")

    print("Layout 1: Direct (Client → Server)")
    direct_lat = bench_rpyc_direct()
    _report("Direct: Client → Server", direct_lat)

    print("\nLayout 2: Via Proxy (Client → Proxy → Worker)")
    proxy_lat = bench_rpyc_via_proxy()
    _report("Via Proxy: Client → Proxy → Worker", proxy_lat)

    d_avg_s = sum(direct_lat) / len(direct_lat) / 1_000
    r_avg_s = sum(proxy_lat)  / len(proxy_lat)  / 1_000
    overhead_s = r_avg_s - d_avg_s
    print(
        f"\n  Proxy overhead vs direct: {overhead_s * 1000:+.3f} ms / call"
        f"  ({overhead_s / d_avg_s * 100:+.1f}%)\n"
    )


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
