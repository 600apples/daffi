"""
TCP_NODELAY latency benchmark — sequential round-trip latency for tiny payloads.

Nagle's algorithm introduces the largest latency penalty on small, interactive
payloads (1–16 bytes) sent sequentially — exactly the pattern of a terminal
keystroke.  This benchmark measures that specific case so the impact of
TCP_NODELAY can be quantified before/after the fix.

Layouts
-------
1. Direct  — Client → Service          (1 TCP hop)
2. Router  — Client → Router → Worker  (2 TCP hops; Nagle on both legs)

Payloads
--------
  TINY   — 1 byte   (single keypress)
  SMALL  — 16 bytes (short shell command)
  MEDIUM — 1 KiB    (paste / short output; Nagle usually doesn't fire here)

Metrics
-------
  avg, p50, p95, p99, max — all in milliseconds

Run::

    python3 tests/perf/latency_nodelay_bench.py
"""
from __future__ import annotations

import logging
import multiprocessing as mp
import os
import socket
import statistics
import sys
import time
from pathlib import Path

# ── path bootstrap ────────────────────────────────────────────────────────────
_PROJECT_ROOT = str(Path(__file__).resolve().parents[2])
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

# ── constants ─────────────────────────────────────────────────────────────────

HOST   = "127.0.0.1"
N      = 3_000   # measured calls per (layout × payload) cell
WARMUP = 100     # discarded calls before measurement
TIMEOUT = 30

PAYLOADS: list[tuple[str, bytes]] = [
    ("1 B  (keystroke)", b"x"),
    ("16 B (command)",   b"x" * 16),
    ("1 KiB",            b"x" * 1024),
]

# ── silence helpers ───────────────────────────────────────────────────────────

def _silence() -> None:
    fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(fd, 1); os.dup2(fd, 2); os.close(fd)
    logging.disable(logging.CRITICAL)


def _quiet(fn, *args, **kwargs) -> None:
    fd = os.open(os.devnull, os.O_WRONLY)
    saved = os.dup(1), os.dup(2)
    os.dup2(fd, 1); os.dup2(fd, 2); os.close(fd)
    try:
        fn(*args, **kwargs)
    finally:
        os.dup2(saved[0], 1); os.dup2(saved[1], 2)
        os.close(saved[0]); os.close(saved[1])

# ── port helpers ──────────────────────────────────────────────────────────────

def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, 0))
        return s.getsockname()[1]


def _wait(port: int, timeout: float = 15.0) -> None:
    dl = time.monotonic() + timeout
    while time.monotonic() < dl:
        try:
            with socket.create_connection((HOST, port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"{HOST}:{port} not ready after {timeout}s")

# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_service(port: int) -> None:
    _silence()
    from daffi import Service, callback

    @callback
    def echo(payload: bytes) -> bytes:
        return payload

    svc = Service(app_name="lat-service", host=HOST, port=port)
    svc.start()
    svc.join()


def _proc_router(port: int) -> None:
    _silence()
    from daffi import Router
    r = Router(app_name="lat-router", host=HOST, port=port)
    r.start()
    r.join()


def _proc_worker(port: int) -> None:
    _silence()
    from daffi import Client, callback
    import time as _t

    @callback
    def echo(payload: bytes) -> bytes:
        return payload

    c = Client(app_name="lat-worker", host=HOST, port=port)
    c.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        c.stop()

# ── measurement ───────────────────────────────────────────────────────────────

def _measure(proxy, payload: bytes) -> list[float]:
    for _ in range(WARMUP):
        proxy.echo(payload)
    lats: list[float] = []
    for _ in range(N):
        t0 = time.perf_counter()
        proxy.echo(payload)
        lats.append((time.perf_counter() - t0) * 1_000)
    return lats


def _stats(lats: list[float]) -> dict[str, float]:
    s = sorted(lats)
    n = len(s)
    return {
        "avg": statistics.mean(s),
        "p50": s[int(n * 0.50)],
        "p95": s[int(n * 0.95)],
        "p99": s[int(n * 0.99)],
        "max": s[-1],
    }


def _row(label: str, stats: dict[str, float]) -> str:
    return (
        f"  {label:<22}"
        f"  avg={stats['avg']:>6.3f} ms"
        f"  p50={stats['p50']:>6.3f} ms"
        f"  p95={stats['p95']:>6.3f} ms"
        f"  p99={stats['p99']:>6.3f} ms"
        f"  max={stats['max']:>6.3f} ms"
    )

# ── layout runners ────────────────────────────────────────────────────────────

def run_direct() -> dict[str, dict]:
    from daffi import Client
    port = _free_port()
    proc = mp.Process(target=_proc_service, args=(port,), daemon=True)
    proc.start()
    results = {}
    try:
        _wait(port)
        time.sleep(0.15)
        client = Client(app_name="lat-direct-caller", host=HOST, port=port)
        conn = client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)
        for label, payload in PAYLOADS:
            print(f"    direct  {label} … ", end="", flush=True)
            lats = _measure(proxy, payload)
            results[label] = _stats(lats)
            print("done")
        _quiet(client.stop)
    finally:
        _quiet(proc.terminate); proc.join(timeout=5)
    return results


def run_router() -> dict[str, dict]:
    from daffi import Client
    rport = _free_port()
    rproc = mp.Process(target=_proc_router, args=(rport,), daemon=True)
    wproc = mp.Process(target=_proc_worker, args=(rport,), daemon=True)
    rproc.start()
    results = {}
    try:
        _wait(rport)
        wproc.start()
        time.sleep(0.5)
        client = Client(app_name="lat-router-caller", host=HOST, port=rport)
        conn = client.connect()
        proxy = conn.rpc(timeout=TIMEOUT)
        for label, payload in PAYLOADS:
            print(f"    router  {label} … ", end="", flush=True)
            lats = _measure(proxy, payload)
            results[label] = _stats(lats)
            print("done")
        _quiet(client.stop)
    finally:
        _quiet(wproc.terminate); wproc.join(timeout=5)
        _quiet(rproc.terminate); rproc.join(timeout=5)
    return results

# ── main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    logging.disable(logging.CRITICAL)
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved_err = os.dup(2)
    os.dup2(devnull, 2); os.close(devnull)

    try:
        print(f"\ndaffi TCP_NODELAY latency benchmark")
        print(f"host={HOST}  N={N} calls/cell  warmup={WARMUP}")
        print(f"payload sizes: {', '.join(l for l, _ in PAYLOADS)}\n")

        print("── Direct (1 TCP hop) ────────────────────────────────────────────")
        direct = run_direct()
        print()
        print("── Router (2 TCP hops) ───────────────────────────────────────────")
        router = run_router()

        print()
        print("── Results ───────────────────────────────────────────────────────")
        print(f"  {'payload':<22}  {'avg':>10}  {'p50':>10}  {'p95':>10}  {'p99':>10}  {'max':>10}")
        print(f"  {'-'*22}  {'-'*10}  {'-'*10}  {'-'*10}  {'-'*10}  {'-'*10}")
        print("  Direct:")
        for label, _ in PAYLOADS:
            print(_row(label, direct[label]))
        print("  Router:")
        for label, _ in PAYLOADS:
            print(_row(label, router[label]))
        print()

    finally:
        os.dup2(saved_err, 2); os.close(saved_err)


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
