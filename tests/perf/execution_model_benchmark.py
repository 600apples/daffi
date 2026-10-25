"""
Compare daffi's native execution models: ``threads`` vs ``evented``.

Every scenario runs once per model in a fresh interpreter with
``DAFFI_EXECUTION_MODEL`` set, so the client side and the spawned
Service/Router/worker processes all use the same model.

Scenarios
---------
1. Sequential RPC latency, Client → Service          (one hop)
2. Sequential RPC latency, Client → Router → worker  (two hops)
3. Throughput with many concurrent clients → Service, plus the number of
   native threads the Service process needs to serve them.

Run::

    python tests/perf/execution_model_benchmark.py [--calls 20000] [--clients 64] [--seconds 5] [--repeats 5]

Each scenario is repeated ``--repeats`` times; the table reports the **median**
with ``[min–max]`` so run-to-run noise is visible instead of a lucky best run.
"""

from __future__ import annotations

import argparse
import json
import logging
import multiprocessing as mp
import os
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


def _silence() -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)


def _thread_count(pid: int) -> int:
    if sys.platform.startswith("linux"):
        return len(os.listdir(f"/proc/{pid}/task"))
    out = subprocess.run(
        ["ps", "-M", "-p", str(pid)], capture_output=True, text=True
    ).stdout
    return max(0, len(out.strip().splitlines()) - 1)


# ── subprocess entry points ───────────────────────────────────────────────────


def _proc_service(port: int) -> None:
    _silence()
    from daffi import Service, callback, TCPTransport

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="bench-service", transports=TCPTransport(HOST, port))
    svc.start()
    svc.join()


def _proc_router(port: int) -> None:
    _silence()
    from daffi import Router, TCPTransport

    router = Router(app_name="bench-router", transports=TCPTransport(HOST, port))
    router.start()
    router.join()


def _proc_worker(port: int) -> None:
    _silence()
    from daffi import Client, callback, TCPTransport

    @callback
    def echo(payload):
        return payload

    client = Client(app_name="bench-worker", transport=TCPTransport(HOST, port))
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
    svc = mp.Process(target=_proc_service, args=(port,), daemon=True)
    svc.start()
    try:
        _wait_for_port(port)
        client = Client(app_name="bench-direct", transport=TCPTransport(HOST, port))
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
    router = mp.Process(target=_proc_router, args=(port,), daemon=True)
    router.start()
    worker = mp.Process(target=_proc_worker, args=(port,), daemon=True)
    try:
        _wait_for_port(port)
        worker.start()
        client = Client(app_name="bench-caller", transport=TCPTransport(HOST, port))
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
    svc = mp.Process(target=_proc_service, args=(port,), daemon=True)
    svc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.3)
        idle_threads = _thread_count(svc.pid)

        clients, conns = [], []
        for i in range(n_clients):
            client = Client(app_name=f"bench-c{i}", transport=TCPTransport(HOST, port))
            conn = client.connect()
            conn.wait_for_members("bench-service", timeout=10)
            clients.append(client)
            conns.append(conn)
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

        threads = [threading.Thread(target=run, args=(i,)) for i in range(n_clients)]
        for t in threads:
            t.start()
        deadline[0] = time.perf_counter() + seconds
        start.set()
        time.sleep(seconds / 2)
        busy_threads = _thread_count(svc.pid)
        for t in threads:
            t.join()

        for client in clients:
            client.stop()
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

    model = dfcore.getExecutionModel()

    def repeated(fn, *args):
        return _summarize([fn(*args) for _ in range(repeats)])

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
    args = parser.parse_args()

    if args.worker:
        logging.disable(logging.CRITICAL)
        result = run_model(args.calls, args.clients, args.seconds, args.repeats)
        print("RESULT " + json.dumps(result))
        return

    results = {}
    for model in MODELS:
        print(f"running {model} model…", flush=True)
        env = dict(os.environ, DAFFI_EXECUTION_MODEL=model)
        proc = subprocess.run(
            [
                sys.executable,
                __file__,
                "--worker",
                "--calls",
                str(args.calls),
                "--clients",
                str(args.clients),
                "--seconds",
                str(args.seconds),
                "--repeats",
                str(args.repeats),
            ],
            env=env,
            capture_output=True,
            text=True,
        )
        line = next(
            (l for l in proc.stdout.splitlines() if l.startswith("RESULT ")), None
        )
        if line is None:
            sys.exit(f"{model} run failed:\n{proc.stdout}\n{proc.stderr}")
        result = json.loads(line[len("RESULT ") :])
        assert (
            result["model"] == model
        ), f"expected {model}, core reports {result['model']}"
        results[model] = result
    _print_table(results)


if __name__ == "__main__":
    main()
