"""
daffi workers benchmark — thread pool vs process pool, sequential & concurrent.

Compares three execution modes side by side:

  baseline      workers=1 (inline, single-threaded)
  threads ×4    workers=4, use_processes=False
  processes ×4  workers=4, use_processes=True

Two topologies:
  Direct     — Client → Service
  Via Router — Client → Router → Worker

Two callback types:
  echo       (I/O-bound proxy: negligible compute, measures pure RPC overhead)
  cpu_work   (CPU-bound: sum-of-squares loop, exercises GIL contention)

Two load patterns per combination:
  sequential   — single caller, one call at a time  (baseline latency)
  concurrent   — N threads fire calls simultaneously (throughput under load)

Output
------
  Summary table printed to stdout.
  Bar chart saved to workers_benchmark.png (requires matplotlib; skipped if absent).

Run::

    python3 tests/perf/workers_benchmark.py
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
from typing import NamedTuple

HOST    = "127.0.0.1"
TIMEOUT = 30
N_SEQ   = 2_000     # sequential calls per (mode × serde × callback) cell
N_CONC  = 200       # concurrent calls per burst
N_BURST = 5         # bursts per (mode × serde × callback) cell
N_THREADS = 16      # caller threads per burst
CPU_N   = 500       # argument passed to cpu_work(n)


# ── result container ──────────────────────────────────────────────────────────

class BenchResult(NamedTuple):
    mode: str        # "baseline" | "threads×4" | "processes×4"
    topology: str    # "direct" | "router"
    callback: str    # "echo" | "cpu_work"
    serde: str       # "PICKLE" | "JSON" | "OPAQUE"
    seq_cps: float   # sequential calls / second
    conc_cps: float  # concurrent calls / second


# ── helpers ───────────────────────────────────────────────────────────────────

def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, 0))
        return s.getsockname()[1]


def _wait(port: int, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"port {HOST}:{port} not ready within {timeout}s")


def _silence() -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)
    from daffi.registry._executor_registry import EXECUTOR_REGISTRY
    EXECUTOR_REGISTRY.subscribers.clear()
    EXECUTOR_REGISTRY.registry.clear()


def _quiet_stop(fn, *args) -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved = (os.dup(1), os.dup(2))
    os.dup2(devnull, 1); os.dup2(devnull, 2); os.close(devnull)
    try:
        fn(*args)
    finally:
        os.dup2(saved[0], 1); os.dup2(saved[1], 2)
        os.close(saved[0]); os.close(saved[1])


# ── subprocess targets ────────────────────────────────────────────────────────

def _proc_service(port: int, workers: int, use_processes: bool) -> None:
    _silence()
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def cpu_work(n: int) -> int:
        return sum(i * i for i in range(n))

    svc = Service(
        app_name="bench-svc",
        host=HOST, port=port,
        workers=workers,
        use_processes=use_processes,
    )
    svc.start()
    svc.join()


def _proc_router(port: int) -> None:
    _silence()
    from daffi import Router
    r = Router(app_name="bench-router", host=HOST, port=port)
    r.start()
    r.join()


def _proc_worker(port: int, workers: int, use_processes: bool) -> None:
    _silence()
    import time as _t
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def cpu_work(n: int) -> int:
        return sum(i * i for i in range(n))

    client = Client(
        app_name="bench-worker",
        host=HOST, port=port,
        workers=workers,
        use_processes=use_processes,
    )
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── benchmark kernel ──────────────────────────────────────────────────────────

def _bench(
    port: int,
    cb_name: str,
    serde_int: int,
    serde_name: str,
    label: str,
) -> tuple[float, float]:
    """
    Measure sequential and concurrent throughput for *cb_name* at *port*.

    Returns ``(seq_cps, conc_cps)``.
    """
    import threading
    from daffi import Client
    from daffi._serialization import SerdeFormat

    wire = json.dumps({}) if serde_name == "OPAQUE" else {}
    cpu_arg = CPU_N
    arg = wire if cb_name == "echo" else cpu_arg

    client = Client(app_name=f"bench-caller-{label}", host=HOST, port=port)
    conn = client.connect()
    proxy = conn.rpc(timeout=TIMEOUT, serde=serde_int)

    # warm up
    for _ in range(10):
        getattr(proxy, cb_name)(arg)

    # sequential
    t0 = time.perf_counter()
    for _ in range(N_SEQ):
        getattr(proxy, cb_name)(arg)
    seq_elapsed = time.perf_counter() - t0
    seq_cps = N_SEQ / seq_elapsed

    # concurrent: N_BURST bursts of N_THREADS simultaneous callers
    total_calls = 0
    conc_elapsed = 0.0
    for _ in range(N_BURST):
        errors: list = []
        lock = threading.Lock()
        barrier = threading.Barrier(N_THREADS)

        def _task():
            barrier.wait(timeout=30)
            n_local = N_CONC // N_THREADS
            try:
                for _ in range(n_local):
                    getattr(proxy, cb_name)(arg)
            except Exception as exc:
                with lock:
                    errors.append(exc)

        threads = [threading.Thread(target=_task, daemon=True) for _ in range(N_THREADS)]
        burst_t0 = time.perf_counter()
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=TIMEOUT + 10)
        conc_elapsed += time.perf_counter() - burst_t0
        total_calls += N_CONC - len(errors) * (N_CONC // N_THREADS)

    conc_cps = total_calls / conc_elapsed if conc_elapsed > 0 else 0

    _quiet_stop(client.stop)
    return seq_cps, conc_cps


# ── topology runners ──────────────────────────────────────────────────────────

def run_direct(
    workers: int,
    use_processes: bool,
    mode_label: str,
    serde_int: int,
    serde_name: str,
    cb_name: str,
) -> BenchResult:
    port = _free_port()
    proc = mp.Process(
        target=_proc_service,
        args=(port, workers, use_processes),
        daemon=True,
    )
    proc.start()
    try:
        _wait(port)
        # extra settle time for process-pool fork
        time.sleep(0.3 if use_processes else 0.15)
        seq_cps, conc_cps = _bench(port, cb_name, serde_int, serde_name, mode_label)
    finally:
        _quiet_stop(proc.terminate)
        proc.join(timeout=5)

    return BenchResult(mode_label, "direct", cb_name, serde_name, seq_cps, conc_cps)


def run_router(
    workers: int,
    use_processes: bool,
    mode_label: str,
    serde_int: int,
    serde_name: str,
    cb_name: str,
) -> BenchResult:
    port = _free_port()
    rproc = mp.Process(target=_proc_router, args=(port,), daemon=True)
    rproc.start()
    wproc = mp.Process(
        target=_proc_worker,
        args=(port, workers, use_processes),
        daemon=True,
    )
    try:
        _wait(port)
        wproc.start()
        time.sleep(0.5 if use_processes else 0.35)
        seq_cps, conc_cps = _bench(port, cb_name, serde_int, serde_name, mode_label)
    finally:
        _quiet_stop(wproc.terminate)
        wproc.join(timeout=5)
        _quiet_stop(rproc.terminate)
        rproc.join(timeout=5)

    return BenchResult(mode_label, "router", cb_name, serde_name, seq_cps, conc_cps)


# ── main ──────────────────────────────────────────────────────────────────────

def _serde_modes():
    from daffi._serialization import SerdeFormat
    modes = [
        (SerdeFormat.PICKLE, "PICKLE"),
        (SerdeFormat.JSON,   "JSON"),
        (SerdeFormat.OPAQUE, "OPAQUE"),
    ]
    try:
        import msgpack as _  # noqa: F401
        modes.insert(2, (SerdeFormat.MSGPACK, "MSGPACK"))
    except ImportError:
        print("  [note] msgpack not installed — MSGPACK skipped")
    return modes


WORKER_MODES = [
    (1,  False, "baseline  "),
    (4,  False, "threads×4 "),
    (4,  True,  "processes×4"),
]

CALLBACKS = ["echo", "cpu_work"]


def main() -> None:
    logging.disable(logging.INFO)

    # Silence Zig teardown noise on stderr.
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)

    results: list[BenchResult] = []

    try:
        serde_modes = _serde_modes()

        print(f"\ndaffi workers benchmark")
        print(f"  sequential: {N_SEQ} calls/cell  |  "
              f"concurrent: {N_BURST}×{N_CONC} calls with {N_THREADS} threads")
        print(f"  cpu_work argument n={CPU_N}  |  host: {HOST}\n")

        for serde_int, serde_name in serde_modes:
            # OPAQUE sends raw bytes without type info — typed callbacks like
            # cpu_work(n: int) would receive a string/bytes and fail.  Only
            # test OPAQUE with echo, which is type-agnostic.
            callbacks = ["echo"] if serde_name == "OPAQUE" else CALLBACKS
            for cb_name in callbacks:
                print(f"── {serde_name} / {cb_name} ───────────────────────────────")
                for workers, use_proc, mode_label in WORKER_MODES:
                    tag = f"{mode_label.strip()}/{serde_name}/{cb_name}"
                    print(f"  [{tag}] direct …", end="", flush=True)
                    r_dir = run_direct(workers, use_proc, mode_label.strip(), serde_int, serde_name, cb_name)
                    print(f" seq={r_dir.seq_cps:>7.0f} c/s  conc={r_dir.conc_cps:>7.0f} c/s", end="")

                    print(f"  | router …", end="", flush=True)
                    r_rtr = run_router(workers, use_proc, mode_label.strip(), serde_int, serde_name, cb_name)
                    print(f" seq={r_rtr.seq_cps:>7.0f} c/s  conc={r_rtr.conc_cps:>7.0f} c/s")

                    results.append(r_dir)
                    results.append(r_rtr)
                print()

        # ── summary table ──────────────────────────────────────────────────────
        print("=" * 90)
        print(f"  SUMMARY  (calls/s, higher is better)")
        print("=" * 90)

        for topology in ("direct", "router"):
            for cb_name in CALLBACKS:
                for serde_int, serde_name in serde_modes:
                    row_results = [
                        r for r in results
                        if r.topology == topology
                        and r.callback == cb_name
                        and r.serde == serde_name
                    ]
                    if not row_results:
                        continue
                    header = f"  {topology:<7} / {cb_name:<9} / {serde_name:<8}"
                    print(f"\n{header}")
                    print(f"    {'mode':<14}  {'sequential':>12}  {'concurrent':>12}")
                    print(f"    {'-'*14}  {'-'*12}  {'-'*12}")
                    for r in row_results:
                        print(f"    {r.mode:<14}  {r.seq_cps:>12.0f}  {r.conc_cps:>12.0f}")

        print()
        _render_chart(results)

    finally:
        os.dup2(saved_stderr, 2)
        os.close(saved_stderr)


# ── optional chart ────────────────────────────────────────────────────────────

def _render_chart(results: list[BenchResult]) -> None:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        import numpy as np
    except ImportError:
        print("[chart] matplotlib not installed — skipping chart generation")
        return

    from daffi._serialization import SerdeFormat
    serde_modes = _serde_modes()
    serde_labels = [s for _, s in serde_modes]

    mode_labels = [m for _, _, m in WORKER_MODES]
    mode_short = [m.strip() for m in mode_labels]
    colours = ["#4C72B0", "#55A868", "#C44E52"]   # blue, green, red

    fig, axes = plt.subplots(
        nrows=2, ncols=4,
        figsize=(20, 9),
        sharey="row",
    )
    fig.suptitle(
        f"daffi workers benchmark — concurrent throughput (calls/s)\n"
        f"{N_BURST}×{N_CONC} calls, {N_THREADS} threads, cpu_work n={CPU_N}",
        fontsize=12,
    )

    col_map = {sn: i for i, (_, sn) in enumerate(serde_modes)}
    # Fill to 4 columns even if MSGPACK is missing
    while len(serde_labels) < 4:
        serde_labels.append(None)

    for row_idx, cb_name in enumerate(CALLBACKS):
        for col_idx, serde_name in enumerate(serde_labels):
            ax = axes[row_idx][col_idx]
            if serde_name is None:
                ax.set_visible(False)
                continue

            x = np.arange(2)  # direct, router
            width = 0.25

            for mi, (_, _, mlabel) in enumerate(WORKER_MODES):
                vals = []
                for topology in ("direct", "router"):
                    match = [
                        r.conc_cps for r in results
                        if r.topology == topology
                        and r.callback == cb_name
                        and r.serde == serde_name
                        and r.mode == mlabel.strip()
                    ]
                    vals.append(match[0] if match else 0)

                offset = (mi - 1) * width
                bars = ax.bar(
                    x + offset, vals, width,
                    label=mlabel.strip(),
                    color=colours[mi],
                    alpha=0.85,
                )
                for bar, v in zip(bars, vals):
                    if v > 0:
                        ax.text(
                            bar.get_x() + bar.get_width() / 2,
                            bar.get_height() * 1.01,
                            f"{v:.0f}",
                            ha="center", va="bottom",
                            fontsize=6,
                        )

            ax.set_title(f"{serde_name} / {cb_name}", fontsize=9)
            ax.set_xticks(x)
            ax.set_xticklabels(["direct", "router"], fontsize=8)
            ax.set_ylabel("calls/s" if col_idx == 0 else "", fontsize=8)
            ax.yaxis.set_tick_params(labelsize=7)
            if row_idx == 0 and col_idx == 0:
                ax.legend(fontsize=7, loc="upper right")

    plt.tight_layout()
    out = Path(__file__).parent / "workers_benchmark.png"
    plt.savefig(out, dpi=130)
    print(f"[chart] saved → {out}")


if __name__ == "__main__":
    # Use "fork" (same as the integration tests) so that:
    # (a) subprocess targets don't need to be picklable, and
    # (b) TaskDispatcher's internal pre-fork of worker processes works
    #     correctly from inside a subprocess that was itself forked.
    mp.set_start_method("fork", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
