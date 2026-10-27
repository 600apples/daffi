"""
Compare daffi's native runtimes: ``threads`` vs ``evented``.

Every scenario runs once per model in a fresh interpreter. That
interpreter locks the runtime with ``dfcore.setRuntime`` and passes the
same value into every spawned Service, Router, and worker.

Scenarios
---------
1. Sequential RPC latency, Client → Service          (one hop)
2. Sequential RPC latency, Client → Router → worker  (two hops)
3. Throughput with many concurrent clients → Service, plus the number of
   native threads the Service process needs to serve them.

Run::

    python tests/perf/runtime_benchmark.py [--calls 20000] [--clients 64] [--seconds 5] [--repeats 5]

Each scenario is repeated ``--repeats`` times; the table reports the **median**
with ``[min–max]`` so run-to-run noise is visible instead of a lucky best run.
Which model runs first is chosen at random.
"""

from __future__ import annotations
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
from tests.conftest import active_runtime

import argparse
import json
import logging
import multiprocessing as mp
import os
import random
import socket
import statistics
import subprocess
import sys
import threading
import time

HOST = "127.0.0.1"
MODELS = ("threads", "evented")
PAYLOAD = {"order": 42, "items": [{"sku": f"item-{i}", "qty": i} for i in range(20)]}


# ── helpers ───────────────────────────────────────────────────────────────────


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
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
    raise TimeoutError(f"{HOST}:{port} not ready after {timeout}s")


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


def _thread_count(pid: int) -> int:
    if sys.platform.startswith("linux"):
        return len(os.listdir(f"/proc/{pid}/task"))
    out = subprocess.run(
        ["ps", "-M", "-p", str(pid)], capture_output=True, text=True
    ).stdout
    return max(0, len(out.strip().splitlines()) - 1)


# ── subprocess entry points ───────────────────────────────────────────────────


def _proc_service(runtime: str, port: int) -> None:
    _silence(runtime)
    from daffi import Service, callback, TCPTransport

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="bench-service", transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def _proc_router(runtime: str, port: int) -> None:
    _silence(runtime)
    from daffi import Router, TCPTransport

    router = Router(app_name="bench-router", transport=TCPTransport(HOST, port), runtime=runtime)
    router.start()
    router.join()


def _proc_worker(runtime: str, port: int) -> None:
    _silence(runtime)
    from daffi import Client, callback, TCPTransport

    @callback
    def echo(payload):
        return payload

    client = Client(app_name="bench-worker", transport=TCPTransport(HOST, port), runtime=runtime)
    client.connect()
    while True:
        time.sleep(1)


def _stop(*procs: mp.Process) -> None:
    for p in procs:
        p.terminate()
        p.join(timeout=5)


# ── scenarios (run inside the per-model interpreter) ──────────────────────────


def _sequential(conn, calls: int) -> dict:
    rpc = conn.rpc(timeout=30)
    for _ in range(200):
        rpc.echo(PAYLOAD)
    lat = []
    for _ in range(calls):
        t0 = time.perf_counter()
        rpc.echo(PAYLOAD)
        lat.append((time.perf_counter() - t0) * 1e6)
    lat.sort()
    return {
        "calls_per_s": calls / (sum(lat) / 1e6),
        "p50_us": lat[len(lat) // 2],
        "p99_us": lat[int(len(lat) * 0.99)],
    }


def bench_direct(calls: int) -> dict:
    from daffi import Client, TCPTransport

    port = _free_port()
    svc = mp.Process(target=_proc_service, args=(active_runtime(), port,), daemon=True)
    svc.start()
    try:
        _wait_for_port(port)
        client = Client(app_name="bench-direct", transport=TCPTransport(HOST, port), runtime=active_runtime())
        conn = client.connect()
        conn.wait_for_members("bench-service", timeout=10)
        result = _sequential(conn, calls)
        client.stop()
        return result
    finally:
        _stop(svc)


def bench_router(calls: int) -> dict:
    from daffi import Client, TCPTransport

    port = _free_port()
    router = mp.Process(target=_proc_router, args=(active_runtime(), port,), daemon=True)
    router.start()
    worker = mp.Process(target=_proc_worker, args=(active_runtime(), port,), daemon=True)
    try:
        _wait_for_port(port)
        worker.start()
        client = Client(app_name="bench-caller", transport=TCPTransport(HOST, port), runtime=active_runtime())
        conn = client.connect()
        conn.wait_for_members("bench-worker", timeout=10)
        result = _sequential(conn, calls)
        client.stop()
        return result
    finally:
        _stop(worker, router)


def bench_concurrent(n_clients: int, seconds: float) -> dict:
    from daffi import Client, TCPTransport

    port = _free_port()
    svc = mp.Process(target=_proc_service, args=(active_runtime(), port,), daemon=True)
    svc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.3)
        idle_threads = _thread_count(svc.pid)

        print(f"concurrent: connecting {n_clients} clients", flush=True)
        clients, conns = [], []
        connect_started = time.perf_counter()
        for i in range(n_clients):
            client = Client(app_name=f"bench-c{i}", transport=TCPTransport(HOST, port), runtime=active_runtime())
            conn = client.connect()
            conn.wait_for_members("bench-service", timeout=10, interval=0.05)
            clients.append(client)
            conns.append(conn)
            if (i + 1) % 200 == 0 or i + 1 == n_clients:
                print(
                    f"concurrent: connected {i + 1}/{n_clients} "
                    f"in {time.perf_counter() - connect_started:.1f}s",
                    flush=True,
                )
        time.sleep(0.5)
        connected_threads = _thread_count(svc.pid)

        counts = [0] * n_clients
        start = threading.Event()
        deadline = [0.0]

        def run(idx: int) -> None:
            rpc = conns[idx].rpc(timeout=30)
            start.wait()
            n = 0
            while time.perf_counter() < deadline[0]:
                rpc.echo(PAYLOAD)
                n += 1
            counts[idx] = n

        # Daemon threads so a failure while starting them cannot leave the
        # process stuck in interpreter shutdown, waiting on threads that
        # never saw start.set().
        threads = [
            threading.Thread(target=run, args=(i,), daemon=True)
            for i in range(n_clients)
        ]
        print(f"concurrent: starting {n_clients} callers", flush=True)
        try:
            for started, t in enumerate(threads, start=1):
                t.start()
                if started % 200 == 0 or started == n_clients:
                    print(f"concurrent: callers started {started}/{n_clients}", flush=True)
            deadline[0] = time.perf_counter() + seconds
            start.set()
            print(f"concurrent: load for {seconds:.0f}s", flush=True)
            time.sleep(seconds / 2)
            busy_threads = _thread_count(svc.pid)
            for t in threads:
                t.join()
        finally:
            start.set()
            deadline[0] = time.perf_counter()
            print("concurrent: stopping clients", flush=True)
            for client in clients:
                client.stop()

        print(
            f"concurrent: done {sum(counts) / seconds:,.0f} calls/s",
            flush=True,
        )
        return {
            "calls_per_s": sum(counts) / seconds,
            "fairness_min_max": min(counts) / max(1, max(counts)),
            "service_threads_idle": idle_threads,
            "service_threads_connected": connected_threads,
            "service_threads_busy": busy_threads,
        }
    finally:
        _stop(svc)


def _summarize(runs: list[dict]) -> dict:
    """Collapse repeated scenario runs into ``{key: {median, min, max}}``."""
    keys = runs[0].keys()
    out = {}
    for key in keys:
        values = sorted(float(r[key]) for r in runs)
        out[key] = {
            "median": statistics.median(values),
            "min": values[0],
            "max": values[-1],
        }
    return out


def run_model(calls: int, n_clients: int, seconds: float, repeats: int) -> dict:
    from daffi import dfcore, TCPTransport

    model = dfcore.getRuntime()

    def repeated(fn, *args):
        print(f"{model}: {fn.__name__} x{repeats}", flush=True)
        summary = _summarize([fn(*args) for _ in range(repeats)])
        print(f"{model}: {fn.__name__} done", flush=True)
        return summary

    return {
        "model": model,
        "direct": repeated(bench_direct, calls),
        "router": repeated(bench_router, calls),
        "concurrent": repeated(bench_concurrent, n_clients, seconds),
        "repeats": repeats,
    }


# ── driver ────────────────────────────────────────────────────────────────────


def _print_table(results: dict) -> None:
    t, e = results["threads"], results["evented"]
    repeats = results["threads"].get("repeats", "?")

    def _faster(a: float, b: float, *, higher_is_better: bool) -> str:
        """``evented faster +12.3%`` or ``threads faster +6.0%`` (medians)."""
        if not a or not b:
            return "n/a"
        if higher_is_better:
            if b >= a:
                return f"evented faster +{(b - a) / a * 100:.1f}%"
            return f"threads faster +{(a - b) / b * 100:.1f}%"
        if b <= a:
            return f"evented faster +{(a - b) / a * 100:.1f}%"
        return f"threads faster +{(b - a) / b * 100:.1f}%"

    def _fmt(stat: dict, fmt: str) -> str:
        med = fmt.format(stat["median"])
        lo = fmt.format(stat["min"])
        hi = fmt.format(stat["max"])
        if lo == hi:
            return med
        return f"{med} [{lo}–{hi}]"

    def row(
        label, a: dict, b: dict, fmt="{:,.0f}", *, higher_is_better=True, compare=True
    ):
        cmp = (
            _faster(a["median"], b["median"], higher_is_better=higher_is_better)
            if compare
            else ""
        )
        print(f"  {label:<38}{_fmt(a, fmt):>22}{_fmt(b, fmt):>22}   {cmp}")

    print(f"\n  median [min–max] over {repeats} repeats; comparison uses medians")
    print(f"\n  {'metric':<38}{'threads':>22}{'evented':>22}   comparison")
    print("  " + "-" * 106)
    for scenario, title in (("direct", "direct"), ("router", "via router")):
        row(f"{title}: calls/s", t[scenario]["calls_per_s"], e[scenario]["calls_per_s"])
        row(
            f"{title}: p50 latency (µs)",
            t[scenario]["p50_us"],
            e[scenario]["p50_us"],
            "{:,.1f}",
            higher_is_better=False,
        )
        row(
            f"{title}: p99 latency (µs)",
            t[scenario]["p99_us"],
            e[scenario]["p99_us"],
            "{:,.1f}",
            higher_is_better=False,
        )
    c_t, c_e = t["concurrent"], e["concurrent"]
    row("concurrent: calls/s", c_t["calls_per_s"], c_e["calls_per_s"])
    row(
        "concurrent: fairness (min/max client)",
        c_t["fairness_min_max"],
        c_e["fairness_min_max"],
        "{:.2f}",
    )
    # Thread counts are a resource metric, not speed — no "faster" label.
    row(
        "service threads, idle",
        c_t["service_threads_idle"],
        c_e["service_threads_idle"],
        "{:.0f}",
        compare=False,
    )
    row(
        "service threads, clients connected",
        c_t["service_threads_connected"],
        c_e["service_threads_connected"],
        "{:.0f}",
        compare=False,
    )
    row(
        "service threads, under load",
        c_t["service_threads_busy"],
        c_e["service_threads_busy"],
        "{:.0f}",
        compare=False,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--calls",
        type=int,
        default=20_000,
        help="sequential calls per latency scenario",
    )
    parser.add_argument("--clients", type=int, default=64, help="concurrent clients")
    parser.add_argument(
        "--seconds", type=float, default=5.0, help="duration of the concurrent scenario"
    )
    parser.add_argument(
        "--repeats",
        type=int,
        default=5,
        help="runs per scenario; table shows median [min–max] (default: 5)",
    )
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--runtime", choices=MODELS, help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.worker:
        if args.runtime is None:
            sys.exit("--runtime is required in worker mode")
        import tests.conftest as _runtime_state
        from daffi import dfcore

        _runtime_state.SELECTED_RUNTIME = args.runtime
        dfcore.setRuntime(args.runtime)
        logging.disable(logging.CRITICAL)
        result = run_model(args.calls, args.clients, args.seconds, args.repeats)
        print("RESULT " + json.dumps(result))
        return

    order = list(MODELS)
    random.shuffle(order)
    print(f"model order: {' then '.join(order)}", flush=True)
    results = {}
    for model in order:
        print(f"running {model} model…", flush=True)
        proc = subprocess.Popen(
            [
                sys.executable,
                __file__,
                "--worker",
                "--runtime",
                model,
                "--calls",
                str(args.calls),
                "--clients",
                str(args.clients),
                "--seconds",
                str(args.seconds),
                "--repeats",
                str(args.repeats),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        captured: list[str] = []
        assert proc.stdout is not None
        for line in proc.stdout:
            captured.append(line)
            print(line, end="", flush=True)
        proc.wait()
        text = "".join(captured)
        line = next(
            (l for l in text.splitlines() if l.startswith("RESULT ")), None
        )
        if line is None:
            print(f"{model} run failed (exit {proc.returncode})", flush=True)
            results[model] = None
            continue
        result = json.loads(line[len("RESULT ") :])
        assert (
            result["model"] == model
        ), f"expected {model}, core reports {result['model']}"
        results[model] = result
    if None in results.values() or set(results) != set(MODELS):
        sys.exit("benchmark failed")
    _print_table(results)


if __name__ == "__main__":
    main()
