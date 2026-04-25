"""
daffi concurrency benchmark — many clients hitting one service/router simultaneously.

Scenarios
---------
1. N_CLIENTS clients → 1 Service (direct, SERVICE_WORKERS threads)
   All clients connect concurrently then simultaneously fire CALLS_PER_CLIENT
   rpc() calls each.

2. N_CLIENTS clients → 1 Router → 1 Worker (1 thread)
   Same load, but routed through an intermediate Router (one extra hop).

3. N_CALLERS callers → 1 Router → N_WORKERS Workers  (cast broadcast)
   Each caller issues CASTS_PER_CALLER cast() calls that fan out to all workers.
   N_WORKERS is kept modest (50) because each worker is a separate OS process;
   200+ processes saturate the system before the Python GIL becomes the limit.

4. N_CLIENTS clients → 1 Router → 1 Worker (HEAVY_WORKERS threads)
   Same topology as scenario 2 but the single worker process runs a large
   thread pool.  Measures how call throughput scales with handler concurrency
   when routing is in the mix.

5. N_CLIENTS clients → 1 Service (HEAVY_WORKERS workers)
   Same topology as scenario 1 but with a much larger thread pool.  Direct
   apples-to-apples comparison against scenario 4 (service vs router hop).

Measurement
-----------
All client threads synchronise on an Event before the first call so every
thread starts at the same instant.  Wall time is measured from event release
to the last thread finishing.

Run::

    python3 tests/perf/concurrency_benchmark.py
"""

from __future__ import annotations

import logging
import multiprocessing as mp
import os
import socket
import sys
import time
import threading
from typing import Optional

# ── constants ─────────────────────────────────────────────────────────────────

N_CLIENTS        = 200   # scenario 1 & 2 — concurrent callers
CALLS_PER_CLIENT = 1_000 # rpc() calls per client

N_WORKERS        = 50    # scenario 3 — concurrent workers (separate processes)
N_CALLERS        = 3     # scenario 3 — callers issuing casts
CASTS_PER_CALLER = 100   # cast() calls per caller

HEAVY_WORKERS    = 200   # scenario 4 & 5 — handler threads inside one worker/service

LEAK_CALLERS      = 100  # scenario 6 — concurrent callers for leak/resource test
LEAK_WORKERS      = 100  # scenario 6 — worker thread pool size (must be ≥ LEAK_CALLERS)
LEAK_DURATION     = 720  # scenario 6 — total run time in seconds (12 min default)
LEAK_INTERVAL     = 30   # scenario 6 — RSS sampling interval in seconds
LEAK_CALL_DELAY_S = 0.01 # scenario 6 — min sleep between calls per caller (10 ms)

WARMUP_CALLS  = 3        # warm-up calls per client before measurement
TIMEOUT       = 60       # per-call timeout (seconds) — generous for heavy load
CAST_TIMEOUT  = 120      # per-cast timeout
HOST          = "127.0.0.1"

PAYLOAD = {"x": 42, "msg": "hello"}   # small, fast payload — we measure concurrency

# ── silence helpers ───────────────────────────────────────────────────────────

def _silence_subprocess() -> None:
    devnull_fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull_fd, 1)
    os.dup2(devnull_fd, 2)
    os.close(devnull_fd)
    logging.disable(logging.CRITICAL)


def _quiet_kill(proc: mp.Process) -> None:
    try:
        devnull = os.open(os.devnull, os.O_WRONLY)
        saved = (os.dup(1), os.dup(2))
        os.dup2(devnull, 1); os.dup2(devnull, 2); os.close(devnull)
        proc.terminate()
    finally:
        os.dup2(saved[0], 1); os.dup2(saved[1], 2)
        os.close(saved[0]); os.close(saved[1])
    proc.join(timeout=5)

# ── port helpers ──────────────────────────────────────────────────────────────

def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, 0))
        return s.getsockname()[1]


def _wait_for_port(port: int, timeout: float = 20.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"Server {HOST}:{port} did not become ready in {timeout}s")

# ── subprocess entry points ───────────────────────────────────────────────────

SERVICE_WORKERS = 10   # thread-pool size for the Service in scenarios 1


def _proc_service(port: int) -> None:
    _silence_subprocess()
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="conc-service", host=HOST, port=port, workers=SERVICE_WORKERS)
    svc.start()
    svc.join()


def _proc_router(port: int) -> None:
    _silence_subprocess()
    from daffi import Router

    router = Router(app_name="conc-router", host=HOST, port=port)
    router.start()
    router.join()


def _proc_worker(port: int, worker_id: int) -> None:
    _silence_subprocess()
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    client = Client(app_name=f"worker-{worker_id:03d}", host=HOST, port=port)
    client.connect()
    try:
        while True:
            time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def _proc_heavy_worker(port: int, n_threads: int) -> None:
    """Single worker process with a large thread-pool (scenario 4)."""
    _silence_subprocess()
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    client = Client(app_name="heavy-worker", host=HOST, port=port, workers=n_threads)
    client.connect()
    try:
        while True:
            time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def _proc_heavy_service(port: int, n_threads: int) -> None:
    """Single Service with a large thread-pool (scenario 5)."""
    _silence_subprocess()
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="heavy-service", host=HOST, port=port, workers=n_threads)
    svc.start()
    svc.join()



# ── stats helper ──────────────────────────────────────────────────────────────

def _stats(label: str, wall_s: float, total_calls: int,
           per_thread_times: list[float], n_threads: int) -> None:
    if not per_thread_times:
        print(f"\n  ── {label}  [no results — all threads failed]")
        return
    avg_ms  = sum(per_thread_times) / len(per_thread_times) * 1_000
    min_ms  = min(per_thread_times) * 1_000
    max_ms  = max(per_thread_times) * 1_000
    cps     = total_calls / wall_s if wall_s > 0 else 0

    print(f"\n  ── {label}")
    print(f"     threads  : {n_threads}")
    print(f"     calls    : {total_calls:,}")
    print(f"     wall time: {wall_s:.3f} s")
    print(f"     calls/s  : {cps:,.0f}")
    print(f"     per-thread  avg={avg_ms:.1f} ms  min={min_ms:.1f} ms  max={max_ms:.1f} ms")

# ── Client-load subprocess helpers ────────────────────────────────────────────
# Each scenario runs its Python clients in a dedicated subprocess so that the
# 256-slot Zig clientEntries table starts fresh for every scenario.

def _rpc_load_proc(port: int, n_clients: int, n_calls: int, q: "mp.Queue") -> None:
    """RPC measurement subprocess for scenarios 1 & 2.

    Connects all clients sequentially (see _run_rpc_scenario docstring for
    rationale), then releases all threads simultaneously and measures.
    Results are sent back through *q* as a dict.
    """
    import threading, time, os, logging
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 2)     # suppress Zig teardown noise on stderr
    os.close(devnull)
    logging.disable(logging.CRITICAL)

    from daffi import Client

    connected: list[tuple] = []
    connect_errors = 0
    for i in range(n_clients):
        print(f"\r  Connecting clients… {i + 1}/{n_clients}", end="", flush=True)
        try:
            client = Client(app_name=f"caller-{i:03d}", host=HOST, port=port)
            conn = client.connect()
            connected.append((client, conn))
        except Exception as exc:
            connect_errors += 1
            if connect_errors <= 3:
                print(f"\n  [!] client {i} connect failed: {exc}", end="")

    print(f"\r  Connected {len(connected)}/{n_clients} ({connect_errors} failed)   ")

    if not connected:
        q.put({"wall": 0, "per_thread": [], "n_connected": 0, "n_errors": 0})
        return

    actual      = len(connected)
    results     = [None] * actual
    errors: list = []
    start_event = threading.Event()
    ready_count = [0]
    lock        = threading.Lock()

    def _measure(client, conn, idx):
        try:
            rpc = conn.rpc(timeout=TIMEOUT)
            for _ in range(WARMUP_CALLS):
                rpc.echo(PAYLOAD)
            with lock:
                ready_count[0] += 1
            start_event.wait(timeout=120)
            t0 = time.perf_counter()
            for _ in range(n_calls):
                rpc.echo(PAYLOAD)
            results[idx] = time.perf_counter() - t0
        except Exception as exc:
            errors.append((idx, exc))
            with lock:
                ready_count[0] += 1
        finally:
            try:
                client.stop()
            except Exception:
                pass

    threads = [
        threading.Thread(target=_measure, args=(cl, conn, i), daemon=True)
        for i, (cl, conn) in enumerate(connected)
    ]
    for t in threads:
        t.start()

    deadline = time.perf_counter() + 120
    while True:
        time.sleep(1)
        with lock:
            r = ready_count[0]
        print(f"\r  Warming up… {r}/{actual} ready", end="", flush=True)
        if r >= actual or time.perf_counter() > deadline:
            break
    print()

    t0_wall = time.perf_counter()
    start_event.set()
    for t in threads:
        t.join(timeout=TIMEOUT + 60)
    wall = time.perf_counter() - t0_wall

    if errors:
        print(f"  [!] {len(errors)} measurement errors:")
        for tid, exc in errors[:5]:
            print(f"      thread {tid}: {exc}")

    per_thread = [r for r in results if r is not None]
    q.put({"wall": wall, "per_thread": per_thread,
           "n_connected": actual, "n_errors": len(errors)})


def _cast_load_proc(port: int, n_callers: int, n_casts: int, n_workers: int,
                    result_file: str) -> None:
    """Cast broadcast measurement subprocess for scenario 3."""
    import threading, time, os, logging, json
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)

    def _send(data: dict) -> None:
        with open(result_file, "w") as f:
            json.dump(data, f)

    from daffi import Client

    callers: list[tuple] = []
    connect_errors = 0
    for i in range(n_callers):
        print(f"\r  Connecting {n_callers} callers… {i + 1}/{n_callers}", end="", flush=True)
        try:
            c = Client(app_name=f"caller-{i:03d}", host=HOST, port=port)
            callers.append((c, c.connect()))
        except Exception as exc:
            connect_errors += 1
            print(f"\n  [!] caller {i} failed: {exc}")

    if not callers:
        _send({"wall": 0, "per_caller": [], "responses": 0, "casts_done": 0})
        return
    print(f"\r  Connected {len(callers)}/{n_callers} callers ({connect_errors} failed)   ")

    results: list = [None] * len(callers)
    errors: list = []
    # Use a barrier with a 30-second timeout so a failing thread can't block others.
    barrier = threading.Barrier(len(callers), timeout=30)

    def _cast_thread(client, conn, idx):
        import traceback as _tb
        try:
            for _ in range(2):
                conn.cast(timeout=CAST_TIMEOUT).echo(PAYLOAD)
            barrier.wait()
            t0 = time.perf_counter()
            total_resp = 0
            for _ in range(n_casts):
                res = conn.cast(timeout=CAST_TIMEOUT).echo(PAYLOAD)
                total_resp += len(res)
            elapsed = time.perf_counter() - t0
            client.stop()
            results[idx] = (elapsed, total_resp)
        except Exception as exc:
            print(f"  [!] cast thread {idx}: {exc}", flush=True)
            _tb.print_exc()
            errors.append((idx, exc))

    threads = [
        threading.Thread(target=_cast_thread, args=(c, conn, i), daemon=False)
        for i, (c, conn) in enumerate(callers)
    ]
    for t in threads:
        t.start()

    t0_wall = time.perf_counter()
    for t in threads:
        t.join(timeout=CAST_TIMEOUT * n_casts + 120)
    wall = time.perf_counter() - t0_wall

    if errors:
        print(f"  [!] {len(errors)} callers failed: {[str(e[1]) for e in errors[:3]]}")

    per_caller = [r[0] for r in results if r is not None]
    responses  = sum(r[1] for r in results if r is not None)
    casts_done = len(per_caller) * n_casts
    _send({"wall": wall, "per_caller": per_caller,
           "responses": responses, "casts_done": casts_done})


def _run_rpc_scenario(label: str, port: int, n_clients: int, n_calls: int) -> None:
    """Launch the RPC load in its own subprocess and print results."""
    q: mp.Queue = mp.Queue()
    p = mp.Process(target=_rpc_load_proc, args=(port, n_clients, n_calls, q), daemon=True)
    p.start()
    p.join()
    try:
        r = q.get(timeout=10)
        per_thread = r["per_thread"]
        successful = len(per_thread)
        _stats(label, r["wall"], successful * n_calls, per_thread, successful)
    except Exception:
        pass


def run_scenario_1() -> None:
    """200 clients → 1 Service (direct)."""
    label = f"Scenario 1 — {N_CLIENTS} clients → Service (direct, workers={SERVICE_WORKERS})"
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"  {CALLS_PER_CLIENT} rpc() calls per client  (total: {N_CLIENTS * CALLS_PER_CLIENT:,})")
    print(f"{'='*60}")

    port = _free_port()
    svc_proc = mp.Process(target=_proc_service, args=(port,), daemon=True)
    svc_proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.3)
        _run_rpc_scenario(label, port, N_CLIENTS, CALLS_PER_CLIENT)
    finally:
        _quiet_kill(svc_proc)


def run_scenario_2() -> None:
    """200 clients → 1 Router → 1 Worker."""
    label = f"Scenario 2 — {N_CLIENTS} clients → Router → 1 Worker"
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"  {CALLS_PER_CLIENT} rpc() calls per client  (total: {N_CLIENTS * CALLS_PER_CLIENT:,})")
    print(f"{'='*60}")

    port = _free_port()
    router_proc = mp.Process(target=_proc_router, args=(port,), daemon=True)
    worker_proc = mp.Process(target=_proc_worker, args=(port, 0), daemon=True)
    router_proc.start()
    try:
        _wait_for_port(port)
        worker_proc.start()
        time.sleep(0.5)
        _run_rpc_scenario(label, port, N_CLIENTS, CALLS_PER_CLIENT)
    finally:
        _quiet_kill(worker_proc)
        _quiet_kill(router_proc)


def run_scenario_3() -> None:
    """3 callers → 1 Router → 200 Workers (cast broadcast)."""
    total_casts    = N_CALLERS * CASTS_PER_CALLER
    total_messages = total_casts * N_WORKERS
    label = (
        f"Scenario 3 — {N_CALLERS} callers → Router → {N_WORKERS} Workers (cast)"
    )
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"  {CASTS_PER_CALLER} cast() calls per caller")
    print(f"  Total fan-out messages: {total_messages:,}  ({total_casts} casts × {N_WORKERS} workers)")
    print(f"{'='*60}")

    port = _free_port()
    router_proc = mp.Process(target=_proc_router, args=(port,), daemon=True)
    router_proc.start()
    worker_procs: list[mp.Process] = []
    try:
        _wait_for_port(port)

        print(f"  Starting {N_WORKERS} workers…", end="", flush=True)
        for i in range(N_WORKERS):
            p = mp.Process(target=_proc_worker, args=(port, i), daemon=True)
            p.start()
            worker_procs.append(p)
        print(" done")

        # Wait for all workers to connect and register their callbacks.
        print(f"  Waiting for {N_WORKERS} workers to register…", end="", flush=True)
        _wait_for_workers(port, N_WORKERS, timeout=120)
        print(" done")

        import tempfile, json, os as _os
        result_fd, result_path = tempfile.mkstemp(suffix=".json")
        _os.close(result_fd)
        cast_proc = mp.Process(
            target=_cast_load_proc,
            args=(port, N_CALLERS, CASTS_PER_CALLER, N_WORKERS, result_path),
            daemon=True,
        )
        cast_proc.start()
        cast_proc.join(timeout=CAST_TIMEOUT * CASTS_PER_CALLER + 300)
        if cast_proc.exitcode is None:
            cast_proc.terminate()
            print("  [!] cast subprocess timed out and was killed")
        elif cast_proc.exitcode != 0:
            print(f"  [!] cast subprocess exited with code {cast_proc.exitcode}")

        r: dict = {}
        try:
            with open(result_path) as f:
                r = json.load(f)
        except Exception:
            print("  [!] no results from cast subprocess", flush=True)
        finally:
            try:
                _os.unlink(result_path)
            except Exception:
                pass

        per_caller       = r.get("per_caller", [])
        actual_responses = r.get("responses", 0)
        casts_done       = r.get("casts_done", 0)
        wall             = r.get("wall", 0)

        print(f"\n  ── {label}")
        print(f"     callers      : {N_CALLERS}")
        print(f"     workers      : {N_WORKERS}")
        print(f"     casts done   : {casts_done:,}")
        print(f"     responses    : {actual_responses:,}  (expected {total_messages:,})")
        print(f"     wall time    : {wall:.3f} s")
        if wall > 0 and casts_done:
            print(f"     casts/s      : {casts_done / wall:,.1f}")
            print(f"     messages/s   : {actual_responses / wall:,.0f}")
        avg_ms = sum(per_caller) / len(per_caller) * 1_000 if per_caller else 0
        print(f"     per-caller   : avg {avg_ms:.1f} ms total")
    finally:
        for p in worker_procs:
            _quiet_kill(p)
        _quiet_kill(router_proc)


def run_scenario_4() -> None:
    """N_CLIENTS clients → Router → 1 Worker with HEAVY_WORKERS threads."""
    label = (
        f"Scenario 4 — {N_CLIENTS} clients → Router → 1 Worker ({HEAVY_WORKERS} threads)"
    )
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  {CALLS_PER_CLIENT} rpc() calls per client  (total: {N_CLIENTS * CALLS_PER_CLIENT:,})")
    print(f"  (compare: scenario 2 uses 1 worker thread — this shows thread-pool scaling)")
    print(f"{'='*70}")

    port        = _free_port()
    router_proc = mp.Process(target=_proc_router, args=(port,), daemon=True)
    worker_proc = mp.Process(
        target=_proc_heavy_worker, args=(port, HEAVY_WORKERS), daemon=True
    )
    router_proc.start()
    try:
        _wait_for_port(port)
        worker_proc.start()
        print("  Waiting for heavy-worker to register…", end="", flush=True)
        _wait_for_workers(port, 1, timeout=30)
        print(" done")
        _run_rpc_scenario(label, port, N_CLIENTS, CALLS_PER_CLIENT)
    finally:
        _quiet_kill(worker_proc)
        _quiet_kill(router_proc)


def run_scenario_5() -> None:
    """N_CLIENTS clients → Service with HEAVY_WORKERS workers."""
    label = (
        f"Scenario 5 — {N_CLIENTS} clients → Service ({HEAVY_WORKERS} workers)"
    )
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  {CALLS_PER_CLIENT} rpc() calls per client  (total: {N_CLIENTS * CALLS_PER_CLIENT:,})")
    print(f"  (compare: scenario 1 uses {SERVICE_WORKERS} workers — this shows thread-pool scaling)")
    print(f"{'='*70}")

    port     = _free_port()
    svc_proc = mp.Process(
        target=_proc_heavy_service, args=(port, HEAVY_WORKERS), daemon=True
    )
    svc_proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.5)   # let the service register its callbacks
        _run_rpc_scenario(label, port, N_CLIENTS, CALLS_PER_CLIENT)
    finally:
        _quiet_kill(svc_proc)


def _sample_rss_kb(pid: int) -> Optional[int]:
    """Return RSS in KiB for *pid*, or None if the process is gone / unavailable."""
    try:
        if sys.platform == "darwin":
            import subprocess as _sp
            out = _sp.check_output(
                ["ps", "-o", "rss=", "-p", str(pid)],
                stderr=_sp.DEVNULL,
            )
            return int(out.strip())
        else:
            with open(f"/proc/{pid}/status") as f:
                for line in f:
                    if line.startswith("VmRSS:"):
                        return int(line.split()[1])
    except Exception:
        return None
    return None


def _proc_leak_loader(port: int, n_callers: int, duration_s: float,
                      q: "mp.Queue") -> None:
    """Continuous RPC load for the leak/resource scenario (scenario 6).

    Connects *n_callers* independent clients and runs each in its own thread,
    firing ``echo`` calls as fast as possible for *duration_s* seconds.
    Aggregated call counts and error counts are sent back through *q*.
    """
    import threading, time, os, logging
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)

    from daffi import Client

    connected: list[tuple] = []
    for i in range(n_callers):
        try:
            client = Client(app_name=f"leak-{i:03d}", host=HOST, port=port)
            conn = client.connect()
            connected.append((client, conn))
        except Exception as exc:
            if i < 5:
                print(f"  [!] leak caller {i} connect failed: {exc}")

    if not connected:
        q.put({"calls": 0, "errors": 0, "n_connected": 0})
        return

    # Brief warmup before measurement starts.
    rpc0 = connected[0][1].rpc(timeout=TIMEOUT)
    for _ in range(WARMUP_CALLS):
        try:
            rpc0.echo(PAYLOAD)
        except Exception:
            pass

    total_calls  = [0]
    total_errors = [0]
    lock         = threading.Lock()
    stop_event   = threading.Event()

    def _run(client, conn):
        rpc = conn.rpc(timeout=TIMEOUT)
        lc = le = 0
        while not stop_event.is_set():
            try:
                rpc.echo(PAYLOAD)
                lc += 1
                # Throttle so the worker never gets more than LEAK_WORKERS concurrent
                # in-flight requests — prevents TCP-buffer overflow and write-timeout
                # disconnects while still producing sustained, realistic load.
                time.sleep(LEAK_CALL_DELAY_S)
            except Exception:
                le += 1
                time.sleep(0.1)  # longer back-off on error
        with lock:
            total_calls[0]  += lc
            total_errors[0] += le
        try:
            client.stop()
        except Exception:
            pass

    threads = [
        threading.Thread(target=_run, args=(cl, conn), daemon=True)
        for cl, conn in connected
    ]
    for t in threads:
        t.start()

    time.sleep(duration_s)
    stop_event.set()
    for t in threads:
        t.join(timeout=TIMEOUT + 30)

    q.put({
        "calls":       total_calls[0],
        "errors":      total_errors[0],
        "n_connected": len(connected),
    })


def run_scenario_leak(
    n_callers: int = LEAK_CALLERS,
    duration_s: float = LEAK_DURATION,
    sample_interval_s: float = LEAK_INTERVAL,
) -> None:
    """Scenario 6 — long-running resource / memory-leak detection.

    Topology:  n_callers callers → Router → 1 Worker (LEAK_WORKERS threads).

    Runs for *duration_s* seconds (default 12 min) while sampling the RSS
    (resident set size) of the router, worker and loader processes every
    *sample_interval_s* seconds.  At the end, prints:

    * A time-series table of RSS values (MB).
    * A per-process summary: initial, final, peak RSS and growth rate.
    * A warning if any process grows faster than 1 MB/min.

    Run standalone::

        python3 tests/perf/concurrency_benchmark.py --leak
    """
    label = (
        f"Scenario 6 — {n_callers} callers → Router → Worker ({LEAK_WORKERS} threads)"
        f"  [{duration_s / 60:.0f} min]"
    )
    max_calls_per_s = int(n_callers / LEAK_CALL_DELAY_S)
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  duration: {duration_s:.0f} s   sample every: {sample_interval_s:.0f} s")
    print(f"  throttle: {LEAK_CALL_DELAY_S*1000:.0f} ms/call per caller"
          f"  (≤{max_calls_per_s:,} calls/s total)")
    print(f"{'='*70}", flush=True)

    port        = _free_port()
    router_proc = mp.Process(target=_proc_router, args=(port,), daemon=True)
    worker_proc = mp.Process(
        target=_proc_heavy_worker, args=(port, LEAK_WORKERS), daemon=True
    )
    router_proc.start()
    try:
        _wait_for_port(port)
        worker_proc.start()
        print("  Waiting for worker to register…", end="", flush=True)
        _wait_for_workers(port, 1, timeout=30)
        print(" done")

        q: mp.Queue = mp.Queue()
        load_proc = mp.Process(
            target=_proc_leak_loader,
            args=(port, n_callers, duration_s, q),
            daemon=True,
        )
        load_proc.start()

        # Allow callers to establish connections before first sample.
        time.sleep(5)

        pids = {
            "router": router_proc.pid,
            "worker": worker_proc.pid,
            "loader": load_proc.pid,
        }
        # samples[name] = list of (elapsed_s, rss_kb)
        samples: dict[str, list] = {name: [] for name in pids}

        col = 10
        header = f"  {'Time':>8}  {'router MB':>{col}}  {'worker MB':>{col}}  {'loader MB':>{col}}"
        sep    = f"  {'-'*8}  {'-'*col}  {'-'*col}  {'-'*col}"
        print(f"\n{header}")
        print(sep, flush=True)

        t0          = time.monotonic()
        next_sample = t0

        while True:
            now     = time.monotonic()
            elapsed = now - t0

            if now >= next_sample:
                row_parts = []
                proc_map = {
                    "router": router_proc,
                    "worker": worker_proc,
                    "loader": load_proc,
                }
                for name, pid in pids.items():
                    proc = proc_map[name]
                    if proc.is_alive():
                        rss = _sample_rss_kb(pid)
                    else:
                        rss = None   # process exited — don't record 0-KB zombie
                    if rss is not None:
                        samples[name].append((elapsed, rss))
                        row_parts.append(f"{rss / 1024:>{col}.1f}")
                    else:
                        row_parts.append(f"{'dead' if not proc.is_alive() else '—':>{col}}")
                print(f"  {elapsed:>7.0f}s  {'  '.join(row_parts)}", flush=True)
                next_sample += sample_interval_s

            # Stop once the loader finishes (it exits after duration_s).
            if not load_proc.is_alive():
                break
            if elapsed >= duration_s + 30:
                break

            sleep_for = max(0.5, next_sample - time.monotonic())
            time.sleep(min(sleep_for, 2.0))

        print(sep)

        # Report any unexpected subprocess exits.
        for name, proc in [("router", router_proc), ("worker", worker_proc)]:
            if not proc.is_alive():
                print(f"  [!] {name} process exited early (code={proc.exitcode})")

        # Collect final stats from the loader.
        load_proc.join(timeout=TIMEOUT + 30)
        stats: dict = {}
        try:
            stats = q.get(timeout=5)
        except Exception:
            pass

        calls      = stats.get("calls", 0)
        errors     = stats.get("errors", 0)
        n_conn     = stats.get("n_connected", 0)
        calls_per_s = calls / duration_s if duration_s > 0 else 0

        print(f"\n  ── Throughput")
        print(f"     connected callers : {n_conn}")
        print(f"     total calls       : {calls:,}")
        print(f"     errors            : {errors:,}")
        print(f"     avg throughput    : {calls_per_s:,.1f} calls/s")

        print(f"\n  ── Memory (RSS) growth analysis")
        # Skip the first 2 samples to avoid startup / GC warm-up noise.
        # For a 12-min run with 30 s intervals that's 24 samples, so we still
        # have 22 data points for the trend — plenty for reliable detection.
        SKIP = 2
        leak_suspect = False
        for name, pts in samples.items():
            if not pts:
                print(f"     {name:<8}: no samples")
                continue
            first_mb = pts[0][1]  / 1024
            last_mb  = pts[-1][1] / 1024
            peak_mb  = max(p[1] for p in pts) / 1024

            # Use linear regression on post-warmup samples for the rate.
            trend_pts = pts[SKIP:] if len(pts) > SKIP + 1 else pts
            if len(trend_pts) >= 2:
                xs = [p[0] / 60 for p in trend_pts]   # minutes
                ys = [p[1] / 1024 for p in trend_pts]  # MB
                n  = len(xs)
                xm = sum(xs) / n
                ym = sum(ys) / n
                num = sum((x - xm) * (y - ym) for x, y in zip(xs, ys))
                den = sum((x - xm) ** 2 for x in xs)
                rate = num / den if den > 0 else 0.0
            else:
                rate = 0.0

            warn = " ⚠  possible leak!" if rate > 1.0 else ""
            if rate > 1.0:
                leak_suspect = True
            print(
                f"     {name:<8}: start={first_mb:6.1f} MB  end={last_mb:6.1f} MB"
                f"  peak={peak_mb:6.1f} MB"
                f"  trend={rate:+.3f} MB/min{warn}"
            )

        if not leak_suspect:
            print("\n  ✓  No significant memory growth detected.")
        else:
            print("\n  ⚠  One or more processes show sustained memory growth.")

        if load_proc.exitcode not in (0, None):
            print(f"  [!] loader subprocess exited with code {load_proc.exitcode}")

    finally:
        _quiet_kill(worker_proc)
        _quiet_kill(router_proc)


def _wait_for_workers(port: int, n: int, timeout: float = 60) -> None:
    """Block until at least *n* members with an 'echo' method are visible."""
    from daffi import Client
    from daffi._bindings import get_available_members

    probe = Client(app_name="probe-client", host=HOST, port=port)
    conn = probe.connect()   # noqa: F841 — just need the connection open
    conn_num = probe._conn_num

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        members = get_available_members(conn_num)
        ready = sum(
            1 for m in members
            if "echo" in (m.get("methods") or [])
            and m.get("name", "") != probe.app_name
        )
        if ready >= n:
            probe.stop()
            time.sleep(0.1)   # let Zig dispatcher null the slot before returning
            return
        time.sleep(0.2)

    probe.stop()
    time.sleep(0.1)
    raise TimeoutError(f"Only {ready}/{n} workers registered after {timeout}s")

# ── main ──────────────────────────────────────────────────────────────────────

def main(argv: Optional[list] = None) -> None:
    """Entry point.

    Flags
    -----
    --leak          Run the standard scenarios *and* the leak test (scenario 6).
    --leak-only     Skip the throughput scenarios, run *only* the leak test.
    --duration N    Override LEAK_DURATION to N seconds (default: 720).
    --interval N    Override LEAK_INTERVAL to N seconds (default: 30).
    --callers N     Override LEAK_CALLERS to N (default: 100).
    """
    global LEAK_DURATION, LEAK_INTERVAL, LEAK_CALLERS

    import argparse
    parser = argparse.ArgumentParser(
        description="daffi concurrency / resource benchmark",
        add_help=False,
    )
    parser.add_argument("--leak",       action="store_true",
                        help="also run the long-running resource leak scenario")
    parser.add_argument("--leak-only",  action="store_true",
                        help="run only the leak scenario, skip throughput tests")
    parser.add_argument("--duration",   type=float, default=None, metavar="S",
                        help="leak test duration in seconds (default: 720)")
    parser.add_argument("--interval",   type=float, default=None, metavar="S",
                        help="RSS sampling interval in seconds (default: 30)")
    parser.add_argument("--callers",    type=int,   default=None, metavar="N",
                        help="number of concurrent callers in leak test (default: 100)")
    args, _ = parser.parse_known_args(argv)

    if args.duration is not None:
        LEAK_DURATION = args.duration
    if args.interval is not None:
        LEAK_INTERVAL = args.interval
    if args.callers is not None:
        LEAK_CALLERS = args.callers

    run_leak = args.leak or args.leak_only
    run_throughput = not args.leak_only

    logging.disable(logging.CRITICAL)

    # Redirect stderr so async native teardown noise doesn't corrupt output.
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)

    try:
        print("\ndaffi concurrency benchmark")
        print(f"host: {HOST}")
        print(f"payload: {PAYLOAD}")

        if run_throughput:
            print(f"scenarios:")
            print(f"  1. {N_CLIENTS} clients → Service (workers={SERVICE_WORKERS}),  {CALLS_PER_CLIENT} calls each")
            print(f"  2. {N_CLIENTS} clients → Router → 1 Worker,  {CALLS_PER_CLIENT} calls each")
            print(f"  3. {N_CALLERS} callers → Router → {N_WORKERS} Workers,  {CASTS_PER_CALLER} casts each")
            print(f"  4. {N_CLIENTS} clients → Router → 1 Worker ({HEAVY_WORKERS} threads),  {CALLS_PER_CLIENT} calls each")
            print(f"  5. {N_CLIENTS} clients → Service ({HEAVY_WORKERS} workers),  {CALLS_PER_CLIENT} calls each")

            run_scenario_1()
            run_scenario_2()
            run_scenario_3()
            run_scenario_4()
            run_scenario_5()

            print("\n── Throughput scenarios done ────────────────────────\n")

        if run_leak:
            print(f"leak scenario:")
            print(f"  6. {LEAK_CALLERS} callers → Router → Worker ({LEAK_WORKERS} threads)")
            print(f"     duration={LEAK_DURATION:.0f}s  sample_interval={LEAK_INTERVAL:.0f}s")
            run_scenario_leak(
                n_callers=LEAK_CALLERS,
                duration_s=LEAK_DURATION,
                sample_interval_s=LEAK_INTERVAL,
            )

        print("\n── Done ─────────────────────────────────────────────\n")
    finally:
        os.dup2(saved_stderr, 2)
        os.close(saved_stderr)


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main(sys.argv[1:])
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
