"""
Long-running soak / memory-leak test under heavy load.

Inspired by vast-csi ``ResourceSampler``: periodic RSS + CPU samples, live
window reports, baseline Δ, and a growth-rate verdict at the end.

Topology
--------
    N callers  →  Router  →  1 Worker

Both the Router and the Worker (and the loader) are sampled for the whole run.
Choose the native runtime with ``--model`` (or run ``both``).
When both models run, which one goes first is chosen at random.

Examples
--------
    # Full 3-hour soak, both models (default) — overnight / weekend box
    python tests/perf/soak_leak_test.py

    # Shorter smoke of the same harness
    python tests/perf/soak_leak_test.py --hours 0.1 --clients 32 --model evented

    # threads only, 3 h, sample every 30 s, live row every 60 s
    python tests/perf/soak_leak_test.py --hours 3 --model threads

Exit code is non-zero if any sampled process trends above ``--leak-mb-per-min``
(default 1.0 MB/min) after warmup.
"""

from __future__ import annotations
import argparse
import json
import logging
import multiprocessing as mp
import os
import random
import socket
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests._resource_sampler import ProcessResourceSampler  # noqa: E402

HOST = "127.0.0.1"
PAYLOAD = {"order": 42, "items": [{"sku": f"i-{i}", "qty": i} for i in range(20)]}
MODELS = ("threads", "evented")


# ── process helpers ───────────────────────────────────────────────────────────


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOST, 0))
        return s.getsockname()[1]


def _wait_for_port(port: int, timeout: float = 30.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, port), timeout=0.2):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"{HOST}:{port} not ready")


def _silence(runtime: str) -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)

    import tests.conftest as _runtime_state
    _runtime_state.SELECTED_RUNTIME = runtime
    from daffi import dfcore
    dfcore.setRuntime(runtime)


def _proc_router(runtime: str, port: int) -> None:
    _silence(runtime)
    from daffi import Router, TCPTransport

    r = Router(app_name="soak-router", transport=TCPTransport(HOST, port), runtime=runtime)
    r.start()
    r.join()


def _proc_worker(runtime: str, port: int, workers: int) -> None:
    _silence(runtime)
    from daffi import Client, callback, TCPTransport

    @callback
    def echo(payload):
        return payload

    client = Client(
        app_name="soak-worker", workers=workers, transport=TCPTransport(HOST, port),
        runtime=runtime,
    )
    client.connect()
    try:
        while True:
            time.sleep(1)
    finally:
        client.stop()


def _proc_loader(runtime: str, 
    port: int,
    n_clients: int,
    duration_s: float,
    call_delay_s: float,
    q: "mp.Queue",
) -> None:
    """Sustain RPC load from *n_clients* for *duration_s* seconds."""
    _silence(runtime)
    from daffi import Client, TCPTransport

    connected = []
    for i in range(n_clients):
        try:
            client = Client(
                app_name=f"soak-c{i:04d}", transport=TCPTransport(HOST, port),
                runtime=runtime,
            )
            conn = client.connect()
            conn.wait_for_members("soak-worker", timeout=60)
            connected.append((client, conn))
        except Exception:
            pass

    if not connected:
        q.put({"calls": 0, "errors": 0, "n_connected": 0})
        return

    # Warmup
    rpc0 = connected[0][1].rpc(timeout=60)
    for _ in range(50):
        try:
            rpc0.echo(PAYLOAD)
        except Exception:
            pass

    total_calls = [0]
    total_errors = [0]
    lock = threading.Lock()
    stop = threading.Event()

    def run(client, conn):
        rpc = conn.rpc(timeout=60)
        lc = le = 0
        while not stop.is_set():
            try:
                rpc.echo(PAYLOAD)
                lc += 1
                if call_delay_s > 0:
                    time.sleep(call_delay_s)
            except Exception:
                le += 1
                time.sleep(0.05)
        with lock:
            total_calls[0] += lc
            total_errors[0] += le
        try:
            client.stop()
        except Exception:
            pass

    threads = [
        threading.Thread(target=run, args=(c, conn), daemon=True)
        for c, conn in connected
    ]
    for t in threads:
        t.start()
    time.sleep(duration_s)
    stop.set()
    for t in threads:
        t.join(timeout=120)
    q.put(
        {
            "calls": total_calls[0],
            "errors": total_errors[0],
            "n_connected": len(connected),
        }
    )


def _quiet_kill(proc: mp.Process, timeout: float = 10.0) -> None:
    if proc.pid is None:
        return
    if proc.is_alive():
        proc.terminate()
    proc.join(timeout=timeout)


# ── one model soak ────────────────────────────────────────────────────────────


def run_soak(
    *,
    model: str,
    hours: float,
    clients: int,
    workers: int,
    sample_interval: float,
    live_interval: float,
    call_delay_s: float,
    leak_mb_per_min: float,
    json_out: Path | None,
) -> int:
    duration_s = hours * 3600.0
    print(f"\n{'=' * 72}")
    print(f"  SOAK  model={model}  duration={hours:g} h ({duration_s:.0f} s)")
    print(f"  load: {clients} callers → Router → Worker(workers={workers})")
    print(f"  sample every {sample_interval:.0f}s   live every {live_interval:.0f}s")
    print(f"  call delay {call_delay_s*1000:.1f} ms/call/client")
    print(f"  leak threshold: {leak_mb_per_min:g} MB/min")
    print(f"{'=' * 72}", flush=True)

    # Spawned children do not inherit an in-process lock. Pass the model in.
    port = _free_port()
    ctx = mp.get_context("spawn")
    router = ctx.Process(target=_proc_router, args=(model, port,), daemon=True)
    worker = ctx.Process(target=_proc_worker, args=(model, port, workers), daemon=True)
    q: mp.Queue = ctx.Queue()
    loader = ctx.Process(
        target=_proc_loader,
        args=(model, port, clients, duration_s, call_delay_s, q),
        daemon=True,
    )

    router.start()
    try:
        try:
            _wait_for_port(port)
        except TimeoutError:
            print(
                f"  [!] router did not listen on {HOST}:{port} "
                f"(alive={router.is_alive()} exit={router.exitcode})",
                flush=True,
            )
            return 2
        worker.start()
        time.sleep(1.0)
        loader.start()
        # Let callers connect before sampling.
        time.sleep(min(15.0, max(5.0, clients * 0.05)))

        if not router.is_alive() or not worker.is_alive() or not loader.is_alive():
            print("  [!] a subprocess died during startup — aborting", flush=True)
            return 2

        sampler = ProcessResourceSampler(
            targets={
                "router": router.pid,
                "worker": worker.pid,
                "loader": loader.pid,
            },
            interval_sec=sample_interval,
            line_writer=lambda s: print(s, flush=True),
        )
        sampler.start()
        sampler.start_live_reporting(interval_sec=live_interval)

        t0 = time.monotonic()
        while loader.is_alive():
            if time.monotonic() - t0 > duration_s + 120:
                print("  [!] loader overrun — stopping", flush=True)
                break
            if not router.is_alive() or not worker.is_alive():
                print("  [!] router/worker exited early — stopping", flush=True)
                break
            time.sleep(2.0)

        sampler.stop()
        loader.join(timeout=180)
        stats = {}
        try:
            stats = q.get(timeout=10)
        except Exception:
            pass

        summary = sampler.report(
            title=f"soak summary  model={model}  {hours:g}h  clients={clients}"
        )
        calls = stats.get("calls", 0)
        errors = stats.get("errors", 0)
        n_conn = stats.get("n_connected", 0)
        cps = calls / duration_s if duration_s else 0
        print(f"\n── Throughput")
        print(
            f"  connected={n_conn}  calls={calls:,}  errors={errors:,}  "
            f"avg={cps:,.1f} calls/s"
        )

        if json_out is not None:
            payload = {
                "model": model,
                "hours": hours,
                "clients": clients,
                "workers": workers,
                "throughput": stats,
                "summary": summary,
                "samples": [
                    {
                        "elapsed_s": s.ts - sampler._t0,
                        "name": s.name,
                        "rss_kb": s.rss_kb,
                        "threads": s.threads,
                        "cpu_pct": s.cpu_pct,
                    }
                    for s in sampler.all_samples()
                ],
            }
            json_out.parent.mkdir(parents=True, exist_ok=True)
            json_out.write_text(json.dumps(payload, indent=2))
            print(f"  wrote {json_out}")

        leak = False
        for name, info in summary.items():
            rate = info.get("trend_mb_per_min", 0.0)
            if rate > leak_mb_per_min:
                leak = True
                print(
                    f"  ⚠  {name}: trend {rate:+.3f} MB/min exceeds "
                    f"{leak_mb_per_min:g} MB/min"
                )
        if leak:
            print("\n  FAIL: sustained memory growth detected.")
            return 1
        print("\n  OK: no sustained memory growth above threshold.")
        return 0
    finally:
        _quiet_kill(loader)
        _quiet_kill(worker)
        _quiet_kill(router)


def main() -> None:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--hours", type=float, default=3.0, help="soak duration in hours (default: 3)"
    )
    p.add_argument(
        "--clients",
        type=int,
        default=100,
        help="concurrent caller clients (default: 100)",
    )
    p.add_argument(
        "--workers",
        type=int,
        default=8,
        help="Python worker threads on the worker process (default: 8)",
    )
    p.add_argument(
        "--sample-interval",
        type=float,
        default=30.0,
        help="RSS/CPU sample period seconds (default: 30)",
    )
    p.add_argument(
        "--live-interval",
        type=float,
        default=60.0,
        help="live console report period seconds (default: 60)",
    )
    p.add_argument(
        "--call-delay",
        type=float,
        default=0.01,
        help="sleep between RPCs per caller (default: 0.01 s)",
    )
    p.add_argument(
        "--leak-mb-per-min",
        type=float,
        default=1.0,
        help="fail if any process trends above this MB/min (default: 1.0)",
    )
    p.add_argument(
        "--model",
        choices=("threads", "evented", "both"),
        default="both",
        help="native runtime (default: both — run twice)",
    )
    p.add_argument(
        "--json-dir",
        type=Path,
        default=None,
        help="optional directory for per-model JSON sample dumps",
    )
    args = p.parse_args()

    if args.model == "both":
        models = list(MODELS)
        random.shuffle(models)
        print(f"model order: {' then '.join(models)}", flush=True)
    else:
        models = (args.model,)
    rc = 0
    for model in models:
        json_out = None
        if args.json_dir is not None:
            json_out = args.json_dir / f"soak_{model}_{args.hours:g}h.json"
        # Each model is passed into spawned children as an argument.
        code = run_soak(
            model=model,
            hours=args.hours,
            clients=args.clients,
            workers=args.workers,
            sample_interval=args.sample_interval,
            live_interval=args.live_interval,
            call_delay_s=args.call_delay,
            leak_mb_per_min=args.leak_mb_per_min,
            json_out=json_out,
        )
        if code and rc == 0:
            rc = code
    sys.exit(rc)


if __name__ == "__main__":
    # spawn children need picklable top-level targets; set method early.
    try:
        mp.set_start_method("spawn")
    except RuntimeError:
        pass
    main()
