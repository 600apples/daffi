"""
daffi.aio big-message benchmark — serde format comparison for large payloads.

Mirror of ``tests/perf/big_message_benchmark.py`` using the async interface.
All RPC calls use ``await conn.rpc()`` inside a single asyncio event loop.

Background
----------
The wire format stores ``data + metadata`` length in a ``u25`` field (25-bit
unsigned integer), capping the maximum payload at::

    MAX_BYTES_MESSAGE = 2**25 - 1 = 33_554_431 bytes  ≈ 32 MiB

Serialisation formats
---------------------
OPAQUE  — zero-copy bytes pass-through; no marshal/unmarshal overhead.
PICKLE  — pickle.dumps(bytes); cheap for bytes objects (just a header + memcpy).
MSGPACK — msgpack.packb(bytes, use_bin_type=True); compact binary format.
JSON    — json.dumps(str); capped at 4 MiB (Python json is slow for large str).

Payload
-------
OPAQUE / PICKLE / MSGPACK : bytes(N)  — N zero-bytes echoed back unchanged
JSON                       : "x" * N  — N-char ASCII string echoed back

Key differences vs. the sync version
--------------------------------------
* Subprocess servers/workers run ``asyncio.run()`` with ``Async*`` classes.
* ``_bench_size`` is an ``async def`` — each round-trip is ``await``ed.
* Both layouts use a single event loop in the measurement process.

Run::

    python3 tests/perf/aio/big_message_benchmark.py
"""
from __future__ import annotations

import asyncio
import logging
import multiprocessing as mp
import os
import socket
import sys
import time
from pathlib import Path
from typing import Callable

# ── path bootstrap ─────────────────────────────────────────────────────────────
_PROJECT_ROOT = str(Path(__file__).resolve().parents[3])
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

# ── constants ──────────────────────────────────────────────────────────────────

HOST    = "127.0.0.1"
TIMEOUT = 120

MAX_BYTES_MESSAGE = (1 << 25) - 1

SIZES: list[tuple[str, int]] = [
    ("1 KiB",   1 << 10),
    ("64 KiB",  1 << 16),
    ("1 MiB",   1 << 20),
    ("4 MiB",   1 << 22),
    ("8 MiB",   8 * (1 << 20)),
    ("16 MiB", 16 * (1 << 20)),
    ("28 MiB", 28 * (1 << 20)),
]

JSON_SIZES: list[tuple[str, int]] = [s for s in SIZES if s[1] <= 4 * (1 << 20)]

N_CALLS = 5
WARMUP  = 2

# ── serde configs ─────────────────────────────────────────────────────────────

def _json_payload(n: int) -> str:
    return "x" * n


SERDE_CONFIGS: list[tuple[str, str, Callable[[int], object], list, str]] = [
    ("OPAQUE",  "OPAQUE",  bytes,         SIZES,      "bytes, zero-copy pass-through"),
    ("PICKLE",  "PICKLE",  bytes,         SIZES,      "bytes object via pickle"),
    ("MSGPACK", "MSGPACK", bytes,         SIZES,      "bytes via msgpack (bin type)"),
    ("JSON",    "JSON",    _json_payload, JSON_SIZES, "str of N chars (bytes unsupported by JSON)"),
]


def _msgpack_available() -> bool:
    try:
        import msgpack  # noqa: F401
        return True
    except ImportError:
        return False


# ── silence helpers ───────────────────────────────────────────────────────────

def _silence_subprocess() -> None:
    devnull_fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull_fd, 1)
    os.dup2(devnull_fd, 2)
    os.close(devnull_fd)
    logging.disable(logging.CRITICAL)


def _quiet_teardown(fn, *args, **kwargs) -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved   = (os.dup(1), os.dup(2))
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


# ── port helpers ──────────────────────────────────────────────────────────────

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


# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_service(host: str, port: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        @callback
        async def echo(payload):
            return payload

        svc = AsyncService(app_name="bigmsg-svc-aio", host=host, port=port)
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_router(host: str, port: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter

        r = AsyncRouter(app_name="bigmsg-router-aio", host=host, port=port)
        await r.start()
        await r.join()

    asyncio.run(_main())


def _proc_worker(host: str, port: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def echo(payload):
            return payload

        client = AsyncClient(app_name="bigmsg-worker-aio", host=host, port=port)
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── measurement helpers ───────────────────────────────────────────────────────

def _mib(n_bytes: int) -> str:
    return f"{n_bytes / (1 << 20):.2f} MiB"


def _throughput(n_bytes: int, elapsed_s: float) -> str:
    mib_per_s = (n_bytes * 2) / (1 << 20) / elapsed_s
    return f"{mib_per_s:.2f} MiB/s"


async def _bench_size(proxy, payload, n_bytes: int) -> dict[str, float | str]:
    """Run WARMUP + N_CALLS round-trips; return latency / throughput stats."""
    for _ in range(WARMUP):
        result = await proxy.echo(payload)
        assert result == payload, "echo round-trip corrupted data"

    latencies_ms: list[float] = []
    for _ in range(N_CALLS):
        t0 = time.perf_counter()
        result = await proxy.echo(payload)
        elapsed_s = time.perf_counter() - t0
        assert result == payload, "echo round-trip corrupted data"
        latencies_ms.append(elapsed_s * 1_000)

    avg_ms = sum(latencies_ms) / len(latencies_ms)
    return {
        "avg_ms": avg_ms,
        "min_ms": min(latencies_ms),
        "max_ms": max(latencies_ms),
        "throughput": _throughput(n_bytes, avg_ms / 1_000),
    }


# ── output helpers ────────────────────────────────────────────────────────────

_COL_W = 82

def _print_layout_header(layout_name: str) -> None:
    print(f"\n  Layout: {layout_name}")
    print(f"  {'format':<8}  {'size':<8}  "
          f"{'avg':>14}  {'min':>14}  {'max':>14}  {'throughput':>14}")
    print("  " + "─" * _COL_W)


def _print_sep() -> None:
    print("  " + "─" * _COL_W)


def _print_row(fmt_label: str, size_label: str, stats: dict) -> None:
    print(
        f"  {fmt_label:<8}  {size_label:<8}  "
        f"avg={stats['avg_ms']:>8.1f} ms  "
        f"min={stats['min_ms']:>8.1f} ms  "
        f"max={stats['max_ms']:>8.1f} ms  "
        f"{stats['throughput']:>14}"
    )


# ── core benchmark loop ───────────────────────────────────────────────────────

async def _run_all_formats(conn, layout_name: str) -> None:
    from daffi import SerdeFormat

    _print_layout_header(layout_name)

    first_format = True
    for fmt_name, serde_attr, payload_fn, sizes, _note in SERDE_CONFIGS:
        if fmt_name == "MSGPACK" and not _msgpack_available():
            print(f"  {'msgpack':<8}  (skipped — msgpack not installed; "
                  "run: pip install 'daffi[msgpack]')")
            continue

        if not first_format:
            _print_sep()
        first_format = False

        serde = getattr(SerdeFormat, serde_attr)
        proxy = conn.rpc(timeout=TIMEOUT, serde=serde)

        for size_label, n_bytes in sizes:
            payload = payload_fn(n_bytes)
            try:
                stats = await _bench_size(proxy, payload, n_bytes)
                _print_row(fmt_name.lower(), size_label, stats)
            except Exception as exc:
                print(f"  {fmt_name.lower():<8}  {size_label:<8}  ERROR: {exc}")


# ── layout entry points ───────────────────────────────────────────────────────

async def bench_direct() -> None:
    from daffi.aio import AsyncClient

    port = _free_port()
    proc = mp.Process(target=_proc_service, args=(HOST, port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        await asyncio.sleep(0.15)

        client = AsyncClient(app_name="bigmsg-direct-caller-aio", host=HOST, port=port)
        conn   = await client.connect()
        try:
            await _run_all_formats(conn, "Direct (AsyncClient → AsyncService)")
        finally:
            await client.stop()
    finally:
        _quiet_teardown(proc.terminate)
        proc.join(timeout=5)


async def bench_via_router() -> None:
    from daffi.aio import AsyncClient

    port  = _free_port()
    rproc = mp.Process(target=_proc_router, args=(HOST, port), daemon=True)
    wproc = mp.Process(target=_proc_worker, args=(HOST, port), daemon=True)

    rproc.start()
    try:
        _wait_for_port(port)
        wproc.start()
        await asyncio.sleep(0.5)

        client = AsyncClient(app_name="bigmsg-router-caller-aio", host=HOST, port=port)
        conn   = await client.connect()
        try:
            await _run_all_formats(
                conn, "Via Router (AsyncClient → AsyncRouter → AsyncWorker)"
            )
        finally:
            await client.stop()
    finally:
        _quiet_teardown(wproc.terminate)
        wproc.join(timeout=5)
        _quiet_teardown(rproc.terminate)
        rproc.join(timeout=5)


# ── main ──────────────────────────────────────────────────────────────────────

async def _async_main() -> None:
    print("\ndaffi.aio big-message benchmark — serde format comparison")
    print(f"host      : {HOST}")
    print(f"max legal : {_mib(MAX_BYTES_MESSAGE)}"
          f"  (u25 field = 2²⁵ − 1 = {MAX_BYTES_MESSAGE:,} bytes)")
    print(f"calls     : {N_CALLS} measured + {WARMUP} warmup per (format × layout × size)")
    print(f"throughput: (payload × 2) / avg_latency  (request + response)")
    print()
    print(f"  {'Format':<8}  {'Payload type':<38}  Max size")
    print("  " + "─" * 62)
    for fmt_name, _, _, sizes, note in SERDE_CONFIGS:
        avail = ""
        if fmt_name == "MSGPACK" and not _msgpack_available():
            avail = "  ← not installed"
        print(f"  {fmt_name:<8}  {note:<38}  {sizes[-1][0]}{avail}")

    await bench_direct()
    await bench_via_router()

    print("\n── Done ──────────────────────────────────────────────────────────────\n")


def main() -> None:
    logging.disable(logging.CRITICAL)

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
