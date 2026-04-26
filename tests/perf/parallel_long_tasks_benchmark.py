"""
parallel_long_tasks_benchmark — verify true concurrent execution of long-running handlers.

Topology
--------
  5 caller threads  →  Router  →  Worker (workers=5)

Scenario
--------
The worker registers a single ``slow_job`` callback that sleeps for SLEEP_SECONDS
(default 120 s) before returning.  The worker is started with ``workers=N_TASKS``
which gives exactly N_TASKS concurrent handler threads — enough to execute all five
incoming calls at the same time.

The caller fires exactly 5 rpc() calls simultaneously (all threads release at the
same instant via a threading.Barrier) and waits for every result.  If the worker is
truly parallel the total wall time should be just over SLEEP_SECONDS.  If the calls
were serialised it would be close to 5 × SLEEP_SECONDS ≈ 10 minutes.

Assertion
---------
  SLEEP_SECONDS  ≤  wall_time  ≤  SLEEP_SECONDS + SLACK_SECONDS

  SLACK_SECONDS = 1.0  (covers scheduling jitter, connection overhead, etc.)

Run
---
    python3 tests/perf/parallel_long_tasks_benchmark.py
"""

from __future__ import annotations

import logging
import multiprocessing as mp
import os
import socket
import sys
import threading
import time

# ── tunables ──────────────────────────────────────────────────────────────────

N_TASKS        = 5           # number of concurrent calls / worker threads
SLEEP_SECONDS  = 120.0       # simulated long job duration (seconds)
SLACK_SECONDS  = 2.0         # acceptable overshoot beyond SLEEP_SECONDS
RPC_TIMEOUT    = SLEEP_SECONDS + 60   # per-call timeout — generous headroom
HOST           = "127.0.0.1"

# ── subprocess silence helpers ────────────────────────────────────────────────

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
        os.dup2(devnull, 1)
        os.dup2(devnull, 2)
        os.close(devnull)
        proc.terminate()
    finally:
        os.dup2(saved[0], 1)
        os.dup2(saved[1], 2)
        os.close(saved[0])
        os.close(saved[1])
    proc.join(timeout=10)

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

def _proc_router(port: int) -> None:
    _silence_subprocess()
    from daffi import Router

    router = Router(app_name="longtask-router", host=HOST, port=port)
    router.start()
    router.join()


def _proc_worker(port: int, sleep_s: float, n_workers: int) -> None:
    """Worker with *n_workers* handler threads and a slow ``slow_job`` callback."""
    _silence_subprocess()
    import time as _time
    from daffi import Client, callback

    @callback
    def slow_job(task_id: int) -> dict:
        _time.sleep(sleep_s)
        return {"task_id": task_id, "slept_s": sleep_s}

    client = Client(
        app_name="longtask-worker",
        host=HOST,
        port=port,
        workers=n_workers,
    )
    client.connect()
    try:
        while True:
            _time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()

# ── worker readiness probe ────────────────────────────────────────────────────

def _wait_for_worker(port: int, timeout: float = 30.0) -> None:
    """Block until the longtask-worker is visible with its 'slow_job' callback."""
    from daffi import Client
    from daffi._bindings import get_available_members

    probe = Client(app_name="longtask-probe", host=HOST, port=port)
    probe.connect()
    conn_num = probe._conn_num

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        members = get_available_members(conn_num)
        ready = any(
            "slow_job" in (m.get("methods") or [])
            for m in members
            if m.get("name") != probe.app_name
        )
        if ready:
            probe.stop()
            time.sleep(0.1)
            return
        time.sleep(0.2)

    probe.stop()
    raise TimeoutError(f"longtask-worker did not register 'slow_job' within {timeout}s")

# ── caller load (runs in-process) ─────────────────────────────────────────────

def _run_callers(port: int, n_tasks: int) -> float:
    """Connect *n_tasks* clients, fire one slow_job each simultaneously.

    Returns the wall-clock seconds from releasing all threads to the last
    response arriving.
    """
    from daffi import Client

    # Connect all callers before the measurement window.
    callers: list[tuple] = []
    for i in range(n_tasks):
        c = Client(app_name=f"longtask-caller-{i}", host=HOST, port=port)
        conn = c.connect()
        callers.append((c, conn))

    results: list = [None] * n_tasks
    errors:  list = []
    barrier = threading.Barrier(n_tasks)          # synchronise all threads at start
    lock    = threading.Lock()

    def _call(idx: int, client, conn) -> None:
        try:
            barrier.wait(timeout=30)              # all threads start together
            rpc = conn.rpc(timeout=RPC_TIMEOUT)
            result = rpc.slow_job(idx)
            with lock:
                results[idx] = result
        except Exception as exc:
            with lock:
                errors.append((idx, exc))
        finally:
            try:
                client.stop()
            except Exception:
                pass

    threads = [
        threading.Thread(target=_call, args=(i, c, conn), daemon=True)
        for i, (c, conn) in enumerate(callers)
    ]

    for t in threads:
        t.start()

    # The barrier above synchronises the threads themselves.  We measure wall
    # time from just before the first thread could release the barrier.
    t0 = time.perf_counter()
    for t in threads:
        t.join(timeout=RPC_TIMEOUT + 60)
    wall = time.perf_counter() - t0

    if errors:
        for idx, exc in errors:
            print(f"  [!] caller {idx} failed: {exc}", flush=True)
        raise RuntimeError(f"{len(errors)} of {n_tasks} calls failed")

    missing = [i for i, r in enumerate(results) if r is None]
    if missing:
        raise RuntimeError(f"No result received for task(s): {missing}")

    return wall

# ── scenario ──────────────────────────────────────────────────────────────────

def run_scenario() -> None:
    label = (
        f"Parallel long tasks — {N_TASKS} callers → Router → Worker "
        f"(workers={N_TASKS}, job={SLEEP_SECONDS:.0f}s)"
    )
    sep = "=" * 68
    print(f"\n{sep}")
    print(f"  {label}")
    print(f"  Expected wall time: ~{SLEEP_SECONDS:.0f}s  (max: {SLEEP_SECONDS + SLACK_SECONDS:.0f}s)")
    print(sep, flush=True)

    port        = _free_port()
    router_proc = mp.Process(target=_proc_router, args=(port,), daemon=True)
    worker_proc = mp.Process(
        target=_proc_worker,
        args=(port, SLEEP_SECONDS, N_TASKS),
        daemon=True,
    )

    router_proc.start()
    try:
        _wait_for_port(port)
        worker_proc.start()

        print("  Waiting for worker to register 'slow_job'…", end="", flush=True)
        _wait_for_worker(port)
        print(" done")

        print(f"  Connecting {N_TASKS} callers and firing jobs simultaneously…", flush=True)
        wall = _run_callers(port, N_TASKS)

        lo = SLEEP_SECONDS
        hi = SLEEP_SECONDS + SLACK_SECONDS
        status = "PASS" if lo <= wall <= hi else "FAIL"

        print(f"\n  ── Result")
        print(f"     tasks        : {N_TASKS}")
        print(f"     job sleep    : {SLEEP_SECONDS:.0f} s")
        print(f"     wall time    : {wall:.3f} s")
        print(f"     expected     : [{lo:.0f} s … {hi:.0f} s]")
        print(f"     verdict      : {status}")

        if status == "FAIL":
            if wall < lo:
                raise AssertionError(
                    f"Wall time {wall:.3f}s < {lo:.0f}s — "
                    "jobs finished suspiciously fast (bug or clock skew?)"
                )
            raise AssertionError(
                f"Wall time {wall:.3f}s > {hi:.0f}s — "
                f"jobs appear to have been serialised or queued instead of run concurrently. "
                f"Expected ~{lo:.0f}s; got +{wall - lo:.1f}s overshoot."
            )
    finally:
        _quiet_kill(worker_proc)
        _quiet_kill(router_proc)


# ── main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    logging.disable(logging.CRITICAL)

    # Suppress Zig native teardown noise on stderr.
    devnull    = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)

    try:
        print("\ndaffi — parallel long-tasks benchmark")
        print(f"host: {HOST}  tasks: {N_TASKS}  sleep: {SLEEP_SECONDS:.0f}s  slack: {SLACK_SECONDS:.1f}s")
        run_scenario()
        print("\n── Done ─────────────────────────────────────────────\n")
    finally:
        os.dup2(saved_stderr, 2)
        os.close(saved_stderr)


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except (AssertionError, RuntimeError) as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
