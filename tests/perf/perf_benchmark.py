"""
daffi performance benchmark — sequential rpc() calls, multiple serde formats.

Layouts
-------
1. Direct     — Client → Service  (one TCP hop, no broker)
2. Via Router — Client → Router → Worker  (two hops, message forwarded)

Serde formats tested
--------------------
  PICKLE   — Python pickle, default format
  JSON     — JSON envelope  {"args": [...], "kwargs": {...}}
  MSGPACK  — msgpack binary array  [args, kwargs]   (skipped if not installed)
  OPAQUE   — zero-copy pass-through; payload is pre-serialised to a JSON string
             by the caller before being handed to daffi

Payload
-------
A shared ``data.json`` file (next to this script) carries a realistic nested
order record (~1.5 KB).  The same Python dict (or its JSON string for OPAQUE)
is echoed by the remote callback and discarded — only latency is measured.

Run::

    python3 tests/perf/perf_benchmark.py
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

# ── payload ───────────────────────────────────────────────────────────────────

_DATA_FILE = Path(__file__).parent / "data.json"

# ── constants ─────────────────────────────────────────────────────────────────

N      = 100_000   # measured calls per (layout × serde) combination
WARMUP = 20       # throwaway calls before measurement
TIMEOUT = 30      # per-call RPC timeout (seconds)
HOST   = "127.0.0.1"

# ── serde format list ─────────────────────────────────────────────────────────
# Imported lazily in main() so subprocesses that don't need them stay clean.

def _serde_modes():
    """Return list of (serde_int, label) pairs to benchmark.

    MSGPACK is skipped with a notice if the optional package is absent.
    """
    from daffi.serialization import SerdeFormat
    modes = [
        (SerdeFormat.PICKLE,  "PICKLE"),
        (SerdeFormat.JSON,    "JSON"),
        (SerdeFormat.OPAQUE,  "OPAQUE"),
    ]
    try:
        import msgpack as _  # noqa: F401
        modes.insert(2, (SerdeFormat.MSGPACK, "MSGPACK"))
    except ImportError:
        print("  [note] msgpack not installed — MSGPACK format skipped")
    return modes


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


def _silence_subprocess() -> None:
    """Redirect all fd-level output to /dev/null (catches Zig native prints too)."""
    devnull_fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull_fd, 1)
    os.dup2(devnull_fd, 2)
    os.close(devnull_fd)
    logging.disable(logging.CRITICAL)


def _quiet_teardown(fn, *args, **kwargs) -> None:
    """Call *fn* while suppressing any fd-level output."""
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
    print(f"    {label}: {total_s:.3f} s for {n} calls  ({n / total_s:.0f} calls/s)")


# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_service(host: str, port: int) -> None:
    _silence_subprocess()
    from daffi import Service, callback

    @callback
    def echo(payload):  # noqa: F811
        return payload

    svc = Service(app_name="perf-service", host=host, port=port)
    svc.start()
    svc.join()


def _proc_router(host: str, port: int) -> None:
    _silence_subprocess()
    from daffi import Router

    router = Router(app_name="perf-router", host=host, port=port)
    router.start()
    router.join()


def _proc_worker(host: str, port: int) -> None:
    _silence_subprocess()
    from daffi import Client, callback

    @callback
    def echo(payload):  # noqa: F811
        return payload

    client = Client(app_name="perf-worker", host=host, port=port)
    client.connect()
    try:
        while True:
            time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── benchmark functions ───────────────────────────────────────────────────────

def bench_direct(serde: int, data: dict, label: str) -> list[float]:
    """Direct: Client → Service, single hop."""
    from daffi import Client

    # OPAQUE requires a single pre-serialised string argument.
    from daffi.serialization import SerdeFormat
    wire = json.dumps(data) if serde == SerdeFormat.OPAQUE else data

    port = _free_port()
    proc = mp.Process(target=_proc_service, args=(HOST, port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)

        client = Client(app_name="perf-direct", host=HOST, port=port)
        conn = client.connect()
        c = conn.rpc(timeout=TIMEOUT, serde=serde)

        print(f"    [direct/{label}] warming up ({WARMUP} calls)…", end="", flush=True)
        for _ in range(WARMUP):
            c.echo(wire)
        print(" done")

        print(f"    [direct/{label}] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for _ in range(N):
            t0 = time.perf_counter()
            c.echo(wire)
            latencies.append((time.perf_counter() - t0) * 1_000)
        print(" done")

        _quiet_teardown(client.stop)
        return latencies
    finally:
        _quiet_teardown(proc.terminate)
        proc.join(timeout=5)


def bench_via_router(serde: int, data: dict, label: str) -> list[float]:
    """Via Router: Client → Router → Worker, two hops."""
    from daffi import Client
    from daffi.serialization import SerdeFormat

    wire = json.dumps(data) if serde == SerdeFormat.OPAQUE else data

    router_port = _free_port()
    router_proc = mp.Process(target=_proc_router, args=(HOST, router_port), daemon=True)
    worker_proc = mp.Process(target=_proc_worker, args=(HOST, router_port), daemon=True)

    router_proc.start()
    try:
        _wait_for_port(router_port)
        worker_proc.start()
        time.sleep(0.4)

        client = Client(app_name="perf-router-caller", host=HOST, port=router_port)
        conn = client.connect()
        c = conn.rpc(timeout=TIMEOUT, serde=serde)

        print(f"    [router/{label}] warming up ({WARMUP} calls)…", end="", flush=True)
        for _ in range(WARMUP):
            c.echo(wire)
        print(" done")

        print(f"    [router/{label}] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for _ in range(N):
            t0 = time.perf_counter()
            c.echo(wire)
            latencies.append((time.perf_counter() - t0) * 1_000)
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
    logging.disable(logging.INFO)

    # Redirect stderr so async Zig teardown prints don't corrupt output.
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)

    try:
        data: dict = json.loads(_DATA_FILE.read_text())
        payload_bytes = len(json.dumps(data).encode())

        modes = _serde_modes()

        print(f"\ndaffi performance benchmark  —  {N} sequential rpc() calls per layout × serde")
        print(f"host: {HOST}   warmup: {WARMUP} calls   timeout: {TIMEOUT}s")
        print(f"payload: {_DATA_FILE.name}  ({payload_bytes} bytes JSON)\n")

        results: dict[str, tuple[list[float], list[float]]] = {}

        for serde, label in modes:
            print(f"── {label} ─────────────────────────────────────────")
            print(f"  Layout 1: Direct (Client → Service)")
            direct_lat = bench_direct(serde, data, label)
            _report(f"Direct/{label}", direct_lat)

            print(f"  Layout 2: Via Router (Client → Router → Worker)")
            router_lat = bench_via_router(serde, data, label)
            _report(f"Router/{label}", router_lat)

            d_avg_s = sum(direct_lat) / len(direct_lat) / 1_000
            r_avg_s = sum(router_lat) / len(router_lat) / 1_000
            overhead_ms = (r_avg_s - d_avg_s) * 1_000
            print(f"    Router overhead: {overhead_ms:+.3f} ms / call\n")

            results[label] = (direct_lat, router_lat)

        # ── summary table ─────────────────────────────────────────────────────
        print("── Summary ──────────────────────────────────────────")
        print(f"  {'Format':<10}  {'Direct (calls/s)':>18}  {'Router (calls/s)':>18}")
        print(f"  {'-'*10}  {'-'*18}  {'-'*18}")
        for label, (dl, rl) in results.items():
            d_s = sum(dl) / 1_000
            r_s = sum(rl) / 1_000
            print(f"  {label:<10}  {len(dl) / d_s:>18.0f}  {len(rl) / r_s:>18.0f}")
        print()

    finally:
        os.dup2(saved_stderr, 2)
        os.close(saved_stderr)


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
