"""
Performance benchmark: 1000 sequential rpc() calls per layout.

Layouts
-------
1. Direct    — Client → Service (one TCP connection, no broker)
2. Via Router — Client → Router → Worker (two hops, message is forwarded)

Run directly::

    python3 tests/perf_benchmark.py

Metrics reported per layout
---------------------------
  total time   Wall-clock time for all N calls (ms)
  throughput   Calls per second
  avg          Mean per-call latency
  p50          Median latency
  p95          95th-percentile latency
  p99          99th-percentile latency
"""

from __future__ import annotations

import logging
import multiprocessing as mp
import os
import socket
import sys
import time

# ── constants ─────────────────────────────────────────────────────────────────

N = 1_000_00         # number of measured calls per layout
WARMUP = 20        # throwaway calls before measurement starts
TIMEOUT = 30       # per-call RPC timeout (seconds)
HOST = "127.0.0.1"

# ── utility ───────────────────────────────────────────────────────────────────

def _free_port() -> int:
    """Return a free TCP port (kernel picks it, we release and use it)."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, 0))
        return s.getsockname()[1]


def _wait_for_port(port: int, timeout: float = 15.0) -> None:
    """Block until *port* on localhost accepts connections."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"Server on {HOST}:{port} did not become ready within {timeout}s")


def _silence_subprocess() -> None:
    """Redirect stdout/stderr to /dev/null for a benchmark subprocess.

    Works at the file-descriptor level so it catches both Python logging and
    any Zig native prints (std.debug.print, etc.) that bypass Python's I/O.
    """
    import os

    devnull_fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull_fd, 1)   # redirect fd 1 (stdout)
    os.dup2(devnull_fd, 2)   # redirect fd 2 (stderr)
    os.close(devnull_fd)
    # Also disable Python-level logging in case any handler writes to a
    # pre-opened file object rather than the raw fd.
    logging.disable(logging.CRITICAL)


def _quiet_teardown(fn, *args, **kwargs) -> None:
    """Call *fn* while suppressing any fd-level output (Zig debug prints, etc.)."""
    import os
    from contextlib import contextmanager

    devnull = os.open(os.devnull, os.O_WRONLY)
    saved = (os.dup(1), os.dup(2))
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    try:
        fn(*args, **kwargs)
    finally:
        os.dup2(saved[0], 1)
        os.dup2(saved[1], 2)
        os.close(saved[0])
        os.close(saved[1])


def _report(label: str, latencies_ms: list[float]) -> None:
    n = len(latencies_ms)
    total_s = sum(latencies_ms) / 1_000
    print(f"  {label}: {total_s:.3f} s for {n} calls  ({n / total_s:.0f} calls/s)")


# ── subprocess entry points ───────────────────────────────────────────────────
# Each function runs inside its own spawned process so they have completely
# isolated global state (EXECUTOR_REGISTRY, native connections, etc.).

def _proc_service(host: str, port: int) -> None:
    """Service process: binds a port, exposes a single 'ping' callback."""
    _silence_subprocess()
    from daffi import Service, callback

    @callback
    def ping(x: int) -> int:  # noqa: F811
        return x

    svc = Service(app_name="perf-service", host=host, port=port)
    svc.start()
    svc.join()


def _proc_router(host: str, port: int) -> None:
    """Router process: central message broker for the via-router layout."""
    _silence_subprocess()
    from daffi import Router

    router = Router(app_name="perf-router", host=host, port=port)
    router.start()
    router.join()


def _proc_worker(host: str, port: int) -> None:
    """Worker process: connects to a router and exposes the 'ping' callback."""
    _silence_subprocess()
    from daffi import Client, callback

    @callback
    def ping(x: int) -> int:  # noqa: F811
        return x

    client = Client(app_name="perf-worker", host=host, port=port)
    client.connect()
    try:
        while True:
            time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()



def bench_direct() -> list[float]:
    """Benchmark: Client → Service (direct, single hop)."""
    from daffi import Client

    port = _free_port()

    proc = mp.Process(target=_proc_service, args=(HOST, port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)  # let the service finish its internal handshake setup

        client = Client(app_name="perf-caller-direct", host=HOST, port=port)
        conn = client.connect()
        c = conn.rpc(timeout=TIMEOUT)

        print(f"  [direct] warming up ({WARMUP} calls)…", end="", flush=True)
        for i in range(WARMUP):
            assert c.ping(i) == i
        print(" done")

        print(f"  [direct] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for i in range(N):
            t0 = time.perf_counter()
            result = c.ping(i)
            latencies.append((time.perf_counter() - t0) * 1_000)
            assert result == i, f"expected {i}, got {result}"
        print(" done")

        _quiet_teardown(client.stop)
        return latencies
    finally:
        _quiet_teardown(proc.terminate)
        proc.join(timeout=5)


def bench_via_router() -> list[float]:
    """Benchmark: Client → Router → Worker (two hops)."""
    from daffi import Client

    router_port = _free_port()

    router_proc = mp.Process(target=_proc_router, args=(HOST, router_port), daemon=True)
    worker_proc = mp.Process(target=_proc_worker, args=(HOST, router_port), daemon=True)

    router_proc.start()
    try:
        _wait_for_port(router_port)
        worker_proc.start()
        # Give the worker time to connect and advertise the 'ping' method.
        time.sleep(0.4)

        client = Client(app_name="perf-caller-router", host=HOST, port=router_port)
        conn = client.connect()
        c = conn.rpc(timeout=TIMEOUT)

        print(f"  [router] warming up ({WARMUP} calls)…", end="", flush=True)
        for i in range(WARMUP):
            assert c.ping(i) == i
        print(" done")

        print(f"  [router] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for i in range(N):
            t0 = time.perf_counter()
            result = c.ping(i)
            latencies.append((time.perf_counter() - t0) * 1_000)
            assert result == i, f"expected {i}, got {result}"
        print(" done")

        _quiet_teardown(client.stop)
        return latencies
    finally:
        _quiet_teardown(worker_proc.terminate)
        worker_proc.join(timeout=5)
        _quiet_teardown(router_proc.terminate)
        router_proc.join(timeout=5)


# ── main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    # ── silence all noise in the main process ────────────────────────────────
    # 1. Python logging: daffi loggers use custom names + propagate=False so
    #    we must disable at the root level rather than per-namespace.
    logging.disable(logging.INFO)

    # 2. Zig native prints (fd 1 / fd 2): redirect stderr for the duration of
    #    the benchmark so that async teardown messages from native threads
    #    don't interleave with our results.  stdout stays open for our output.
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)

    try:
        print(f"\ndaffi performance benchmark  —  {N} sequential rpc() calls per layout")
        print(f"host: {HOST}   warmup: {WARMUP} calls   timeout: {TIMEOUT}s\n")

        print("Layout 1: Direct (Client → Service)")
        direct_lat = bench_direct()
        _report("Direct: Client → Service", direct_lat)

        print("\nLayout 2: Via Router (Client → Router → Worker)")
        router_lat = bench_via_router()
        _report("Via Router: Client → Router → Worker", router_lat)

        # Side-by-side overhead comparison
        d_avg_s = sum(direct_lat) / len(direct_lat) / 1_000
        r_avg_s = sum(router_lat) / len(router_lat) / 1_000
        overhead_s = r_avg_s - d_avg_s
        print(
            f"\n  Router overhead vs direct: {overhead_s * 1000:+.3f} ms / call"
            f"  ({overhead_s / d_avg_s * 100:+.1f}%)\n"
        )
    finally:
        os.dup2(saved_stderr, 2)
        os.close(saved_stderr)


if __name__ == "__main__":
    # 'spawn' is required: each subprocess must start with a clean Python
    # interpreter so that EXECUTOR_REGISTRY and native state are isolated.
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
