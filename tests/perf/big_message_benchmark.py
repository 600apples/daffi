"""
daffi big-message benchmark — serde format comparison for large payloads.

Background
----------
The wire format stores ``data + metadata`` length in a ``u25`` field (25-bit
unsigned integer), capping the maximum payload at::

    MAX_BYTES_MESSAGE = 2**25 - 1 = 33_554_431 bytes  ≈ 32 MiB

This benchmark sweeps message sizes from 1 KiB up to 28 MiB across all four
wire serialisation formats and both network layouts.

Serialisation formats
---------------------
OPAQUE  — zero-copy bytes pass-through; no marshal/unmarshal overhead.
PICKLE  — pickle.dumps(bytes); cheap for bytes objects (just a header + memcpy).
MSGPACK — msgpack.packb(bytes, use_bin_type=True); compact binary format.
JSON    — json.dumps(str); bytes are not supported → str payload used instead.
           Capped at 4 MiB because Python's json module is significantly slower
           than the binary formats for large strings.

Payload
-------
OPAQUE / PICKLE / MSGPACK : bytes(N)  — N zero-bytes echoed back unchanged
JSON                       : "x" * N  — N-char ASCII string echoed back

Throughput formula
------------------
throughput = (payload_size × 2) / avg_round_trip_latency
(request + response both carry the payload, hence ×2)

Run::

    python3 tests/perf/big_message_benchmark.py
"""
from __future__ import annotations

import logging
import multiprocessing as mp
import os
import socket
import sys
import time
from pathlib import Path
from typing import Callable

# ── path bootstrap ────────────────────────────────────────────────────────────
# When the script is run directly (`python3 tests/perf/big_message_benchmark.py`),
# Python sets sys.path[0] to the script's own directory, not the project root.
# daffi is a local package (not pip-installed), so we must add the project root.
_PROJECT_ROOT = str(Path(__file__).resolve().parents[2])
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

# ── constants ──────────────────────────────────────────────────────────────────

HOST    = "127.0.0.1"
TIMEOUT = 120   # generous: transferring 28 MiB can take several seconds

MAX_BYTES_MESSAGE = (1 << 25) - 1   # 33_554_431

# Full sweep for binary-efficient formats (OPAQUE, PICKLE, MSGPACK).
SIZES: list[tuple[str, int]] = [
    ("1 KiB",   1 << 10),           #  1_024
    ("64 KiB",  1 << 16),           # 65_536
    ("1 MiB",   1 << 20),           #  1_048_576
    ("4 MiB",   1 << 22),           #  4_194_304
    ("8 MiB",   8 * (1 << 20)),     #  8_388_608
    ("16 MiB", 16 * (1 << 20)),     # 16_777_216
    ("28 MiB", 28 * (1 << 20)),     # 29_360_128  (safety margin below 32 MiB)
]

# JSON is Python-slow for large strings; cap to keep total benchmark time sane.
JSON_SIZES: list[tuple[str, int]] = [s for s in SIZES if s[1] <= 4 * (1 << 20)]

# Number of measured round-trips per (format × layout × size).
N_CALLS = 5
WARMUP  = 2


# ── serde configs ─────────────────────────────────────────────────────────────
# Each entry: (display_name, SerdeFormat attr, payload_factory, sizes, note)
# payload_factory(n_bytes: int) → payload  (what gets passed to echo())

def _json_payload(n: int) -> str:
    return "x" * n


SERDE_CONFIGS: list[tuple[str, str, Callable[[int], object], list, str]] = [
    ("OPAQUE",  "OPAQUE",  bytes,         SIZES,      "bytes, zero-copy pass-through"),
    ("PICKLE",  "PICKLE",  bytes,         SIZES,      "bytes object via pickle"),
    ("MSGPACK", "MSGPACK", bytes,         SIZES,      "bytes via msgpack (bin type)"),
    ("JSON",    "JSON",    _json_payload, JSON_SIZES, "str of N chars (bytes unsupported by JSON)"),
]


# ── msgpack availability ───────────────────────────────────────────────────────

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
    """Call *fn* with stdout/stderr silenced."""
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
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="bigmsg-service", host=host, port=port)
    svc.start()
    svc.join()


def _proc_router(host: str, port: int) -> None:
    _silence_subprocess()
    from daffi import Router

    r = Router(app_name="bigmsg-router", host=host, port=port)
    r.start()
    r.join()


def _proc_worker(host: str, port: int) -> None:
    _silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    client = Client(app_name="bigmsg-worker", host=host, port=port)
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── measurement helpers ───────────────────────────────────────────────────────

def _mib(n_bytes: int) -> str:
    return f"{n_bytes / (1 << 20):.2f} MiB"


def _throughput(n_bytes: int, elapsed_s: float) -> str:
    """Round-trip throughput: request + response both carry the payload."""
    mib_per_s = (n_bytes * 2) / (1 << 20) / elapsed_s
    return f"{mib_per_s:.2f} MiB/s"


def _bench_size(proxy, payload, n_bytes: int) -> dict[str, float | str]:
    """Run WARMUP + N_CALLS round-trips; return latency / throughput stats."""
    for _ in range(WARMUP):
        result = proxy.echo(payload)
        assert result == payload, "echo round-trip corrupted data"

    latencies_ms: list[float] = []
    for _ in range(N_CALLS):
        t0 = time.perf_counter()
        result = proxy.echo(payload)
        elapsed_s = time.perf_counter() - t0
        assert result == payload, "echo round-trip corrupted data"
        latencies_ms.append(elapsed_s * 1_000)

    avg_ms = sum(latencies_ms) / len(latencies_ms)
    min_ms = min(latencies_ms)
    max_ms = max(latencies_ms)
    return {
        "avg_ms": avg_ms,
        "min_ms": min_ms,
        "max_ms": max_ms,
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

def _run_all_formats(conn, layout_name: str) -> None:
    """Benchmark every serde format using *conn* (already connected)."""
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
                stats = _bench_size(proxy, payload, n_bytes)
                _print_row(fmt_name.lower(), size_label, stats)
            except Exception as exc:
                print(f"  {fmt_name.lower():<8}  {size_label:<8}  ERROR: {exc}")


# ── layout entry points ───────────────────────────────────────────────────────

def bench_direct() -> None:
    """Direct layout: Client → Service."""
    from daffi import Client

    port = _free_port()
    proc = mp.Process(target=_proc_service, args=(HOST, port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)   # let Service fully initialise

        client = Client(app_name="bigmsg-direct-caller", host=HOST, port=port)
        conn   = client.connect()
        try:
            _run_all_formats(conn, "Direct (Client → Service)")
        finally:
            _quiet_teardown(client.stop)
    finally:
        _quiet_teardown(proc.terminate)
        proc.join(timeout=5)


def bench_via_router() -> None:
    """Router layout: Client → Router → Worker."""
    from daffi import Client

    port  = _free_port()
    rproc = mp.Process(target=_proc_router, args=(HOST, port), daemon=True)
    wproc = mp.Process(target=_proc_worker, args=(HOST, port), daemon=True)

    rproc.start()
    try:
        _wait_for_port(port)
        wproc.start()
        time.sleep(0.5)   # let worker register its echo callback

        client = Client(app_name="bigmsg-router-caller", host=HOST, port=port)
        conn   = client.connect()
        try:
            _run_all_formats(conn, "Via Router (Client → Router → Worker)")
        finally:
            _quiet_teardown(client.stop)
    finally:
        _quiet_teardown(wproc.terminate)
        wproc.join(timeout=5)
        _quiet_teardown(rproc.terminate)
        rproc.join(timeout=5)


# ── main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    logging.disable(logging.CRITICAL)

    # Suppress Zig async-teardown noise on stderr.
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)

    try:
        print("\ndaffi big-message benchmark — serde format comparison")
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

        bench_direct()
        bench_via_router()

        print("\n── Done ──────────────────────────────────────────────────────────────\n")
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
