"""
daffi.aio parallel long-tasks benchmark — async concurrent slow callbacks.

Mirror of ``tests/perf/parallel_long_tasks_benchmark.py`` using the async
interface.  This version demonstrates a key advantage of asyncio over threads:

  * The worker registers an **``async def slow_job``** that calls
    ``await asyncio.sleep(SLEEP_SECONDS)`` instead of ``time.sleep()``.
  * With ``workers=N_TASKS`` the worker runs N_TASKS asyncio *tasks* in
    parallel — each task yields at ``await asyncio.sleep`` so the event loop
    remains responsive throughout.
  * The callers fire N_TASKS simultaneous RPCs via ``asyncio.gather`` (no OS
    threads at all on the caller side).

Topology
--------
  N_TASKS async callers  →  AsyncRouter  →  AsyncWorker (workers=N_TASKS)

Expected behaviour
------------------
All N_TASKS ``slow_job`` calls execute *concurrently* inside a single OS
thread on the worker (no GIL contention, no thread overhead).  The wall time
should be just over SLEEP_SECONDS, not N_TASKS × SLEEP_SECONDS.

Assertion
---------
  SLEEP_SECONDS  ≤  wall_time  ≤  SLEEP_SECONDS + SLACK_SECONDS

Run::

    python3 tests/perf/aio/parallel_long_tasks_benchmark.py
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

# ── path bootstrap ─────────────────────────────────────────────────────────────
_PROJECT_ROOT = str(Path(__file__).resolve().parents[3])
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

# ── tunables ──────────────────────────────────────────────────────────────────

N_TASKS        = 5
SLEEP_SECONDS  = 120.0
SLACK_SECONDS  = 2.0
RPC_TIMEOUT    = SLEEP_SECONDS + 60
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

    async def _main():
        from daffi.aio import AsyncRouter

        router = AsyncRouter(app_name="longtask-router-aio", host=HOST, port=port)
        await router.start()
        await router.join()

    asyncio.run(_main())


def _proc_worker(port: int, sleep_s: float, n_workers: int) -> None:
    """AsyncWorker with *n_workers* concurrent asyncio tasks and an async slow_job."""
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def slow_job(task_id: int) -> dict:
            # ``await asyncio.sleep`` yields the event loop so other tasks
            # can run concurrently — no OS threads needed for parallelism.
            await asyncio.sleep(sleep_s)
            return {"task_id": task_id, "slept_s": sleep_s}

        client = AsyncClient(
            app_name="longtask-worker-aio",
            host=HOST,
            port=port,
            workers=n_workers,
        )
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── worker readiness probe ─────────────────────────────────────────────────────

def _wait_for_worker(port: int, timeout: float = 30.0) -> None:
    """Block (sync) until the longtask-worker-aio is visible with 'slow_job'."""
    from daffi import Client
    from daffi._bindings import get_available_members

    probe = Client(app_name="longtask-probe-aio", host=HOST, port=port)
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
    raise TimeoutError(f"longtask-worker-aio did not register 'slow_job' within {timeout}s")


# ── caller load ───────────────────────────────────────────────────────────────

async def _run_callers(port: int, n_tasks: int) -> float:
    """Connect *n_tasks* AsyncClients, fire one slow_job each simultaneously.

    Uses ``asyncio.gather`` — all RPCs are in flight at the same time in one
    event loop thread.  Returns wall-clock seconds from start to last result.
    """
    from daffi.aio import AsyncClient

    # Connect all callers before the measurement window.
    callers: list[tuple] = []
    for i in range(n_tasks):
        c = AsyncClient(app_name=f"longtask-caller-{i}-aio", host=HOST, port=port)
        conn = await c.connect()
        callers.append((c, conn))

    results: list = [None] * n_tasks
    errors:  list = []

    # asyncio.Barrier synchronises all tasks at the same instant (Python ≥ 3.11).
    barrier = asyncio.Barrier(n_tasks)

    async def _call(idx: int, client, conn) -> None:
        try:
            await barrier.wait()              # all tasks released together
            rpc = conn.rpc(timeout=RPC_TIMEOUT)
            result = await rpc.slow_job(idx)
            results[idx] = result
        except Exception as exc:
            errors.append((idx, exc))
        finally:
            try:
                await client.stop()
            except Exception:
                pass

    t0 = time.perf_counter()
    await asyncio.gather(*[
        _call(i, c, conn) for i, (c, conn) in enumerate(callers)
    ])
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

async def run_scenario() -> None:
    label = (
        f"Parallel long tasks (async) — {N_TASKS} callers → AsyncRouter → AsyncWorker "
        f"(workers={N_TASKS}, job={SLEEP_SECONDS:.0f}s, await asyncio.sleep)"
    )
    sep = "=" * 78
    print(f"\n{sep}")
    print(f"  {label}")
    print(f"  All {N_TASKS} jobs run concurrently via asyncio — zero OS threads on caller/worker.")
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

        print(
            f"  Connecting {N_TASKS} async callers and firing "
            f"jobs simultaneously via asyncio.gather…",
            flush=True,
        )
        wall = await _run_callers(port, N_TASKS)

        lo = SLEEP_SECONDS
        hi = SLEEP_SECONDS + SLACK_SECONDS
        status = "PASS" if lo <= wall <= hi else "FAIL"

        print(f"\n  ── Result")
        print(f"     tasks        : {N_TASKS}")
        print(f"     job sleep    : {SLEEP_SECONDS:.0f} s  (await asyncio.sleep — no OS thread)")
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
                f"jobs appear to have been serialised. "
                f"Expected ~{lo:.0f}s; got +{wall - lo:.1f}s overshoot."
            )
    finally:
        _quiet_kill(worker_proc)
        _quiet_kill(router_proc)


# ── main ──────────────────────────────────────────────────────────────────────

async def _async_main() -> None:
    print("\ndaffi.aio — parallel long-tasks benchmark  (asyncio.gather, no OS threads)")
    print(
        f"host: {HOST}  tasks: {N_TASKS}  "
        f"sleep: {SLEEP_SECONDS:.0f}s  slack: {SLACK_SECONDS:.1f}s"
    )
    await run_scenario()
    print("\n── Done ─────────────────────────────────────────────\n")


def main() -> None:
    logging.disable(logging.CRITICAL)

    devnull    = os.open(os.devnull, os.O_WRONLY)
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
    except (AssertionError, RuntimeError) as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
