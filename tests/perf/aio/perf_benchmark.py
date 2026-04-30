"""
daffi.aio performance benchmark — sequential ``await conn.rpc()`` calls.

Mirror of ``tests/perf/perf_benchmark.py`` using the async interface so the
two results can be compared side-by-side.

Layouts
-------
1. Direct     — AsyncClient → AsyncService  (one TCP hop, no broker)
2. Via Router — AsyncClient → AsyncRouter → Async-Worker  (two hops)

Serde formats tested
--------------------
  PICKLE   — Python pickle, default format
  JSON     — JSON envelope  {"args": [...], "kwargs": {...}}
  MSGPACK  — msgpack binary (skipped if not installed)
  OPAQUE   — zero-copy pass-through

Payload
-------
The same ``data.json`` file used by the sync benchmark (~1.5 KB nested order
record) so the two results are directly comparable.

Key differences vs. the sync version
--------------------------------------
* Subprocess servers/workers are started with ``asyncio.run()``.
* Measurement loop uses ``await`` — each call is a cooperative yield;
  the event loop stays idle between the send and the response signal.
* No OS threads are used anywhere in the measurement process.

Run::

    python3 tests/perf/aio/perf_benchmark.py
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
from pathlib import Path

# ── path bootstrap ─────────────────────────────────────────────────────────────
_PROJECT_ROOT = str(Path(__file__).resolve().parents[3])
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

# ── payload ───────────────────────────────────────────────────────────────────
_DATA_FILE = Path(__file__).parent.parent / "data.json"

# ── constants ─────────────────────────────────────────────────────────────────
N      = 100_000  # measured calls per (layout × serde) combination
WARMUP = 20
TIMEOUT = 30
HOST   = "127.0.0.1"

# ── serde format list ─────────────────────────────────────────────────────────

def _serde_modes():
    from daffi._serialization import SerdeFormat
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
    devnull_fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull_fd, 1)
    os.dup2(devnull_fd, 2)
    os.close(devnull_fd)
    logging.disable(logging.CRITICAL)


def _quiet_teardown(fn, *args, **kwargs) -> None:
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
# Each subprocess runs its own asyncio event loop.

def _proc_service(host: str, port: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        @callback
        async def echo(payload):
            return payload

        svc = AsyncService(app_name="perf-svc-aio", host=host, port=port)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_router(host: str, port: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter

        router = AsyncRouter(app_name="perf-router-aio", host=host, port=port)
        await router.start()
        await router.join()

    asyncio.run(_main())


def _proc_worker(host: str, port: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def echo(payload):
            return payload

        client = AsyncClient(app_name="perf-worker-aio", host=host, port=port)
        await client.connect()
        try:
            await client.join()
        except (KeyboardInterrupt, SystemExit):
            pass
        finally:
            await client.stop()

    asyncio.run(_main())


# ── benchmark functions ───────────────────────────────────────────────────────

async def bench_direct(serde: int, data: dict, label: str) -> list[float]:
    """Direct: AsyncClient → AsyncService, single hop."""
    from daffi.aio import AsyncClient
    from daffi._serialization import SerdeFormat

    wire = json.dumps(data) if serde == SerdeFormat.OPAQUE else data

    port = _free_port()
    proc = mp.Process(target=_proc_service, args=(HOST, port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        await asyncio.sleep(0.15)

        client = AsyncClient(app_name="perf-direct-aio", host=HOST, port=port)
        conn = await client.connect()
        c = conn.rpc(timeout=TIMEOUT, serde=serde)

        print(f"    [direct/{label}] warming up ({WARMUP} calls)…", end="", flush=True)
        for _ in range(WARMUP):
            await c.echo(wire)
        print(" done")

        print(f"    [direct/{label}] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for _ in range(N):
            t0 = time.perf_counter()
            await c.echo(wire)
            latencies.append((time.perf_counter() - t0) * 1_000)
        print(" done")

        await client.stop()
        return latencies
    finally:
        _quiet_teardown(proc.terminate)
        proc.join(timeout=5)


async def bench_via_router(serde: int, data: dict, label: str) -> list[float]:
    """Via Router: AsyncClient → AsyncRouter → Async-Worker, two hops."""
    from daffi.aio import AsyncClient
    from daffi._serialization import SerdeFormat

    wire = json.dumps(data) if serde == SerdeFormat.OPAQUE else data

    router_port = _free_port()
    router_proc = mp.Process(target=_proc_router, args=(HOST, router_port), daemon=True)
    worker_proc = mp.Process(target=_proc_worker, args=(HOST, router_port), daemon=True)

    router_proc.start()
    try:
        _wait_for_port(router_port)
        worker_proc.start()
        await asyncio.sleep(0.4)

        client = AsyncClient(app_name="perf-router-caller-aio", host=HOST, port=router_port)
        conn = await client.connect()
        c = conn.rpc(timeout=TIMEOUT, serde=serde)

        print(f"    [router/{label}] warming up ({WARMUP} calls)…", end="", flush=True)
        for _ in range(WARMUP):
            await c.echo(wire)
        print(" done")

        print(f"    [router/{label}] measuring {N} calls…", end="", flush=True)
        latencies: list[float] = []
        for _ in range(N):
            t0 = time.perf_counter()
            await c.echo(wire)
            latencies.append((time.perf_counter() - t0) * 1_000)
        print(" done")

        await client.stop()
        return latencies
    finally:
        _quiet_teardown(worker_proc.terminate)
        worker_proc.join(timeout=5)
        _quiet_teardown(router_proc.terminate)
        router_proc.join(timeout=5)


# ── main ──────────────────────────────────────────────────────────────────────

async def _async_main() -> None:
    data: dict = json.loads(_DATA_FILE.read_text())
    payload_bytes = len(json.dumps(data).encode())

    modes = _serde_modes()

    print(f"\ndaffi.aio performance benchmark  —  {N} sequential await rpc() calls per layout × serde")
    print(f"host: {HOST}   warmup: {WARMUP} calls   timeout: {TIMEOUT}s")
    print(f"payload: {_DATA_FILE.name}  ({payload_bytes} bytes JSON)\n")

    results: dict[str, tuple[list[float], list[float]]] = {}

    for serde, label in modes:
        print(f"── {label} ─────────────────────────────────────────")
        print(f"  Layout 1: Direct (AsyncClient → AsyncService)")
        direct_lat = await bench_direct(serde, data, label)
        _report(f"Direct/{label}", direct_lat)

        print(f"  Layout 2: Via Router (AsyncClient → AsyncRouter → AsyncWorker)")
        router_lat = await bench_via_router(serde, data, label)
        _report(f"Router/{label}", router_lat)

        d_avg_s = sum(direct_lat) / len(direct_lat) / 1_000
        r_avg_s = sum(router_lat) / len(router_lat) / 1_000
        overhead_ms = (r_avg_s - d_avg_s) * 1_000
        print(f"    Router overhead: {overhead_ms:+.3f} ms / call\n")

        results[label] = (direct_lat, router_lat)

    # ── summary table ─────────────────────────────────────────────────────────
    print("── Summary ──────────────────────────────────────────")
    print(f"  {'Format':<10}  {'Direct (calls/s)':>18}  {'Router (calls/s)':>18}")
    print(f"  {'-'*10}  {'-'*18}  {'-'*18}")
    for label, (dl, rl) in results.items():
        d_s = sum(dl) / 1_000
        r_s = sum(rl) / 1_000
        print(f"  {label:<10}  {len(dl) / d_s:>18.0f}  {len(rl) / r_s:>18.0f}")
    print()


def main() -> None:
    logging.disable(logging.INFO)

    devnull = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)

    try:
        asyncio.run(_async_main())
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
