"""
Process-level RSS / CPU helpers for daffi resource tests.

Measures the **native Service / Router process** (Zig core), not the pytest
interpreter — that is where connection state and event-loop threads live.

Used by:
  * ``tests/perf/runtime_resources.py``  (threads vs evented table)
  * ``tests/integration/test_memory_leaks.py``   (steady-state leak asserts)
"""

from __future__ import annotations
from tests.conftest import active_runtime

import logging
import multiprocessing as mp
import os
import socket
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from typing import Callable, Optional

HOST = "127.0.0.1"
PAYLOAD = {"order": 42, "items": [{"sku": f"item-{i}", "qty": i} for i in range(10)]}
KiB = 1024
MiB = 1024 * KiB

# Linux clock ticks / second for /proc/<pid>/stat CPU accounting.
try:
    _CLK_TCK = os.sysconf(os.sysconf_names["SC_CLK_TCK"])
except (AttributeError, ValueError, KeyError):
    _CLK_TCK = 100


# ── process metrics ───────────────────────────────────────────────────────────


def rss_kb(pid: int) -> Optional[int]:
    """Resident set size in KiB, or None if the process is gone."""
    try:
        if sys.platform == "darwin":
            out = subprocess.check_output(
                ["ps", "-o", "rss=", "-p", str(pid)], stderr=subprocess.DEVNULL
            )
            return int(out.strip())
        with open(f"/proc/{pid}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1])
    except (OSError, ValueError, subprocess.CalledProcessError):
        return None
    return None


def _cpu_jiffies(pid: int) -> Optional[int]:
    """utime + stime in clock ticks (Linux), or None."""
    if not sys.platform.startswith("linux"):
        return None
    try:
        with open(f"/proc/{pid}/stat") as f:
            parts = f.read().split()
        # fields 14/15 are utime/stime (1-indexed); list index 13/14
        return int(parts[13]) + int(parts[14])
    except (OSError, IndexError, ValueError):
        return None


def thread_count(pid: int) -> int:
    if sys.platform.startswith("linux"):
        try:
            return len(os.listdir(f"/proc/{pid}/task"))
        except OSError:
            return 0
    out = subprocess.run(
        ["ps", "-M", "-p", str(pid)], capture_output=True, text=True
    ).stdout
    return max(0, len(out.strip().splitlines()) - 1)


@dataclass
class Sample:
    rss_kb: int
    threads: int
    cpu_pct: Optional[float]  # % of one core over the sample window; None on macOS


def sample_window(pid: int, seconds: float = 1.0) -> Sample:
    """RSS/threads snapshot with average CPU% over *seconds* (Linux)."""
    j0 = _cpu_jiffies(pid)
    t0 = time.perf_counter()
    time.sleep(seconds)
    j1 = _cpu_jiffies(pid)
    elapsed = time.perf_counter() - t0
    rss = rss_kb(pid) or 0
    threads = thread_count(pid)
    cpu_pct = None
    if j0 is not None and j1 is not None and elapsed > 0:
        cpu_pct = 100.0 * (j1 - j0) / (_CLK_TCK * elapsed)
    return Sample(rss_kb=rss, threads=threads, cpu_pct=cpu_pct)


# ── topology helpers ──────────────────────────────────────────────────────────


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOST, 0))
        return s.getsockname()[1]


def wait_for_port(port: int, timeout: float = 15.0) -> None:
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


def proc_service(runtime: str, port: int) -> None:
    _silence(runtime)
    from daffi import Service, callback, TCPTransport

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="res-service", transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def proc_router(runtime: str, port: int) -> None:
    _silence(runtime)
    from daffi import Router, TCPTransport

    router = Router(app_name="res-router", transport=TCPTransport(HOST, port), runtime=runtime)
    router.start()
    router.join()


def proc_worker(runtime: str, port: int) -> None:
    _silence(runtime)
    from daffi import Client, callback, TCPTransport

    @callback
    def echo(payload):
        return payload

    client = Client(app_name="res-worker", transport=TCPTransport(HOST, port), runtime=runtime)
    client.connect()
    while True:
        time.sleep(1)


def stop(*procs: mp.Process) -> None:
    for p in procs:
        if p.is_alive():
            p.terminate()
        p.join(timeout=5)


# ── load generators ───────────────────────────────────────────────────────────


def _connect_clients(port: int, n: int, peer: str) -> tuple[list, list]:
    from daffi import Client, TCPTransport

    clients, conns = [], []
    for i in range(n):
        client = Client(app_name=f"res-c{i}", transport=TCPTransport(HOST, port), runtime=active_runtime())
        conn = client.connect()
        conn.wait_for_members(peer, timeout=15)
        clients.append(client)
        conns.append(conn)
    return clients, conns


def _rpc_burst(conns: list, calls_per_client: int) -> None:
    def run(conn):
        rpc = conn.rpc(timeout=30)
        for _ in range(calls_per_client):
            rpc.echo(PAYLOAD)

    threads = [threading.Thread(target=run, args=(c,)) for c in conns]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=60)


def _rpc_for(conns: list, seconds: float) -> None:
    """Fire RPCs from every connection until *seconds* elapse (for CPU sampling)."""
    stop_at = time.perf_counter() + seconds
    barrier = threading.Barrier(len(conns) + 1)

    def run(conn):
        rpc = conn.rpc(timeout=30)
        barrier.wait(timeout=30)
        while time.perf_counter() < stop_at:
            rpc.echo(PAYLOAD)

    threads = [threading.Thread(target=run, args=(c,)) for c in conns]
    for t in threads:
        t.start()
    barrier.wait(timeout=30)
    for t in threads:
        t.join(timeout=seconds + 60)


def _stop_clients(clients: list) -> None:
    for client in clients:
        try:
            client.stop()
        except Exception:
            pass


# ── scenarios ─────────────────────────────────────────────────────────────────


@dataclass
class ScenarioResult:
    name: str
    target: str  # which process was measured ("service" | "router")
    idle: Sample
    under_load: Sample
    after: Sample  # after clients disconnected / load stopped


def scenario_many_clients(
    n_clients: int = 64,
    calls_per_client: int = 200,
    sample_s: float = 1.0,
) -> ScenarioResult:
    """N clients → Service; measure the Service process."""
    port = free_port()
    svc = mp.Process(target=proc_service, args=(active_runtime(), port,), daemon=True)
    svc.start()
    try:
        wait_for_port(port)
        time.sleep(0.3)
        idle = sample_window(svc.pid, sample_s)

        clients, conns = _connect_clients(port, n_clients, "res-service")
        time.sleep(0.3)

        # Keep the Service busy for the whole sample window so CPU% is meaningful.
        # Extra burst afterward exercises call volume without extending wall time much.
        load_s = max(sample_s + 0.5, 1.5)
        loader = threading.Thread(target=_rpc_for, args=(conns, load_s))
        loader.start()
        time.sleep(0.15)
        under = sample_window(svc.pid, sample_s)
        loader.join(timeout=load_s + 60)
        if calls_per_client > 0:
            _rpc_burst(conns, min(calls_per_client, 50))

        _stop_clients(clients)
        time.sleep(0.5)
        after = sample_window(svc.pid, sample_s)
        return ScenarioResult("many_clients", "service", idle, under, after)
    finally:
        stop(svc)


def scenario_router(
    n_clients: int = 32,
    calls_per_client: int = 200,
    sample_s: float = 1.0,
) -> ScenarioResult:
    """N clients → Router → worker; measure the Router process."""
    port = free_port()
    router = mp.Process(target=proc_router, args=(active_runtime(), port,), daemon=True)
    worker = mp.Process(target=proc_worker, args=(active_runtime(), port,), daemon=True)
    router.start()
    try:
        wait_for_port(port)
        worker.start()
        time.sleep(0.5)
        idle = sample_window(router.pid, sample_s)

        clients, conns = _connect_clients(port, n_clients, "res-worker")
        time.sleep(0.3)

        load_s = max(sample_s + 0.5, 1.5)
        loader = threading.Thread(target=_rpc_for, args=(conns, load_s))
        loader.start()
        time.sleep(0.15)
        under = sample_window(router.pid, sample_s)
        loader.join(timeout=load_s + 60)
        if calls_per_client > 0:
            _rpc_burst(conns, min(calls_per_client, 50))

        _stop_clients(clients)
        time.sleep(0.5)
        after = sample_window(router.pid, sample_s)
        return ScenarioResult("router", "router", idle, under, after)
    finally:
        stop(worker, router)


def scenario_connection_churn(
    rounds: int = 8,
    clients_per_round: int = 20,
    sample_s: float = 0.5,
) -> list[int]:
    """Connect/disconnect batches; return per-round Service RSS (KiB) after each round.

    Used by the leak test: RSS must not climb every round.
    """
    port = free_port()
    svc = mp.Process(target=proc_service, args=(active_runtime(), port,), daemon=True)
    svc.start()
    samples: list[int] = []
    try:
        wait_for_port(port)
        time.sleep(0.3)
        for r in range(rounds):
            clients, conns = _connect_clients(port, clients_per_round, "res-service")
            _rpc_burst(conns, calls_per_client=20)
            _stop_clients(clients)
            time.sleep(0.4)
            s = sample_window(svc.pid, sample_s)
            samples.append(s.rss_kb)
        return samples
    finally:
        stop(svc)


# ── steady-state assert (vast-csi style) ──────────────────────────────────────


def assert_rss_steady_state(
    step: Callable[[], None],
    measure: Callable[[], int],
    *,
    label: str,
    warmup: int = 2,
    rounds: int = 6,
    tolerance_kb: int = 2 * MiB // KiB,  # 2 MiB per round
) -> list[int]:
    """Run *step* repeatedly; fail if RSS grows by more than *tolerance_kb* every
    one of the last three rounds (same idea as vast-csi ``assert_steady_state``).
    """
    for _ in range(warmup):
        step()
    prev = measure()
    deltas: list[int] = []
    for _ in range(rounds):
        step()
        cur = measure()
        deltas.append(cur - prev)
        prev = cur

    report = (
        f"{label}: RSS deltas per round ["
        + ", ".join(f"{d / KiB:+.1f} MiB" for d in deltas)
        + f"]  (tolerance ±{tolerance_kb / KiB:.1f} MiB)"
    )
    print(report)
    tail = deltas[-3:]
    assert not all(d > tolerance_kb for d in tail), f"RSS keeps growing. {report}"
    return deltas
