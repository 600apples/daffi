"""
daffi.aio concurrency benchmark — many async callers hitting one service/router.

Mirror of ``tests/perf/concurrency_benchmark.py`` using the async interface.
Uses ``asyncio.gather`` instead of ``threading.Thread`` for callers, which
means all concurrent calls share a single OS thread — the event loop.

Scenarios
---------
1. N_CLIENTS async callers → AsyncService  (direct, no router)
   All tasks connect concurrently then simultaneously fire CALLS_PER_CLIENT
   ``await conn.rpc()`` calls each via ``asyncio.gather``.

2. N_CLIENTS async callers → AsyncRouter → Async-Worker  (two hops)
   Same load routed through an AsyncRouter.

3. N_CALLERS callers → AsyncRouter → N_WORKERS Async-Workers  (cast broadcast)
   Each caller issues CASTS_PER_CALLER ``await conn.cast()`` calls that fan
   out to all workers simultaneously.

4. N_CLIENTS callers → AsyncRouter → Async-Worker (workers=HEAVY_WORKERS tasks)
   Single worker process with a large pool of asyncio worker tasks.

5. N_CLIENTS callers → AsyncService  (workers=HEAVY_WORKERS)
   Same but direct (no router), apples-to-apples vs scenario 4.

Key differences vs. the sync version
--------------------------------------
* All client callers are ``asyncio.Task`` objects — no OS threads.
* A single event loop handles N_CLIENTS concurrent RPCs.
* Synchronisation uses ``asyncio.Barrier`` (Python 3.11+) instead of
  ``threading.Barrier``.
* Worker subprocesses register ``async def echo`` callbacks.

Run::

    python3 tests/perf/aio/concurrency_benchmark.py
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
from typing import Optional

# ── path bootstrap ─────────────────────────────────────────────────────────────
_PROJECT_ROOT = str(Path(__file__).resolve().parents[3])
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

# ── constants ─────────────────────────────────────────────────────────────────

N_CLIENTS        = 200
CALLS_PER_CLIENT = 1_000  # rpc() calls per client

N_WORKERS        = 50
N_CALLERS        = 3
CASTS_PER_CALLER = 100

HEAVY_WORKERS    = 200    # asyncio worker tasks in scenarios 4 & 5

WARMUP_CALLS  = 3
TIMEOUT       = 60
CAST_TIMEOUT  = 120
HOST          = "127.0.0.1"

PAYLOAD = {"x": 42, "msg": "hello"}

SERVICE_WORKERS = 10   # asyncio tasks for the Service in scenario 1

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

def _proc_service(port: int, n_workers: int = SERVICE_WORKERS) -> None:
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        @callback
        async def echo(payload):
            return payload

        svc = AsyncService(
            app_name="conc-service-aio", host=HOST, port=port, workers=n_workers
        )
        await svc.start()
        await svc.join()

    asyncio.run(_main())


def _proc_router(port: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi.aio import AsyncRouter

        router = AsyncRouter(app_name="conc-router-aio", host=HOST, port=port)
        await router.start()
        await router.join()

    asyncio.run(_main())


def _proc_worker(port: int, worker_id: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def echo(payload):
            return payload

        client = AsyncClient(
            app_name=f"worker-{worker_id:03d}", host=HOST, port=port
        )
        await client.connect()
        await client.join()

    asyncio.run(_main())


def _proc_heavy_worker(port: int, n_workers: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def echo(payload):
            return payload

        client = AsyncClient(
            app_name="heavy-worker-aio", host=HOST, port=port, workers=n_workers
        )
        await client.connect()
        await client.join()

    asyncio.run(_main())


def _proc_heavy_service(port: int, n_workers: int) -> None:
    _silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncService

        @callback
        async def echo(payload):
            return payload

        svc = AsyncService(
            app_name="heavy-service-aio", host=HOST, port=port, workers=n_workers
        )
        await svc.start()
        await svc.join()

    asyncio.run(_main())


# ── stats helper ──────────────────────────────────────────────────────────────

def _stats(label: str, wall_s: float, total_calls: int,
           per_task_times: list[float], n_tasks: int) -> None:
    if not per_task_times:
        print(f"\n  ── {label}  [no results — all tasks failed]")
        return
    avg_ms = sum(per_task_times) / len(per_task_times) * 1_000
    min_ms = min(per_task_times) * 1_000
    max_ms = max(per_task_times) * 1_000
    cps    = total_calls / wall_s if wall_s > 0 else 0

    print(f"\n  ── {label}")
    print(f"     tasks    : {n_tasks}")
    print(f"     calls    : {total_calls:,}")
    print(f"     wall time: {wall_s:.3f} s")
    print(f"     calls/s  : {cps:,.0f}")
    print(f"     per-task  avg={avg_ms:.1f} ms  min={min_ms:.1f} ms  max={max_ms:.1f} ms")


# ── async load subprocess ─────────────────────────────────────────────────────
# Uses asyncio.gather so all N_CLIENTS callers run in a single event loop.

def _rpc_load_proc(port: int, n_clients: int, n_calls: int, q: "mp.Queue") -> None:
    """RPC measurement subprocess: all callers as asyncio Tasks."""

    async def _run() -> dict:
        import os as _os, logging as _log
        devnull = _os.open(_os.devnull, _os.O_WRONLY)
        _os.dup2(devnull, 2)
        _os.close(devnull)
        _log.disable(_log.CRITICAL)

        from daffi.aio import AsyncClient

        # Connect all clients sequentially to avoid a stampede.
        connected: list[tuple] = []
        connect_errors = 0
        for i in range(n_clients):
            print(f"\r  Connecting clients… {i + 1}/{n_clients}", end="", flush=True)
            try:
                client = AsyncClient(
                    app_name=f"caller-{i:03d}", host=HOST, port=port
                )
                conn = await client.connect()
                connected.append((client, conn))
            except Exception as exc:
                connect_errors += 1
                if connect_errors <= 3:
                    print(f"\n  [!] client {i} connect failed: {exc}", end="")

        print(f"\r  Connected {len(connected)}/{n_clients} ({connect_errors} failed)   ")

        if not connected:
            return {"wall": 0, "per_task": [], "n_connected": 0, "n_errors": 0}

        actual  = len(connected)
        results = [None] * actual
        errors: list = []

        # Use asyncio.Barrier (Python ≥ 3.11) to synchronise all tasks.
        barrier = asyncio.Barrier(actual)

        async def _warmup_and_measure(client, conn, idx: int) -> None:
            try:
                rpc = conn.rpc(timeout=TIMEOUT)
                for _ in range(WARMUP_CALLS):
                    await rpc.echo(PAYLOAD)
                await barrier.wait()
                t0 = time.perf_counter()
                for _ in range(n_calls):
                    await rpc.echo(PAYLOAD)
                results[idx] = time.perf_counter() - t0
            except Exception as exc:
                errors.append((idx, exc))
            finally:
                try:
                    await client.stop()
                except Exception:
                    pass

        # Warmup and synchronisation happen inside each task.
        # The barrier ensures all callers begin measuring at the same instant.
        print(f"  Warming up {actual} async callers…", flush=True)
        t0_wall = time.perf_counter()
        await asyncio.gather(*[
            _warmup_and_measure(cl, conn, i)
            for i, (cl, conn) in enumerate(connected)
        ])
        wall = time.perf_counter() - t0_wall

        if errors:
            print(f"  [!] {len(errors)} task errors:")
            for tid, exc in errors[:5]:
                print(f"      task {tid}: {exc}")

        per_task = [r for r in results if r is not None]
        return {
            "wall": wall,
            "per_task": per_task,
            "n_connected": actual,
            "n_errors": len(errors),
        }

    result = asyncio.run(_run())
    q.put(result)


def _run_rpc_scenario(label: str, port: int, n_clients: int, n_calls: int) -> None:
    q: mp.Queue = mp.Queue()
    p = mp.Process(target=_rpc_load_proc, args=(port, n_clients, n_calls, q), daemon=True)
    p.start()
    p.join()
    try:
        r = q.get(timeout=10)
        per_task = r["per_task"]
        successful = len(per_task)
        _stats(label, r["wall"], successful * n_calls, per_task, successful)
    except Exception:
        pass


# ── cast load subprocess ───────────────────────────────────────────────────────

def _cast_load_proc(port: int, n_callers: int, n_casts: int,
                    n_workers: int, result_file: str) -> None:
    """Cast broadcast subprocess: all callers as asyncio Tasks."""

    async def _run() -> dict:
        import os as _os, logging as _log, json as _json
        devnull = _os.open(_os.devnull, _os.O_WRONLY)
        _os.dup2(devnull, 2)
        _os.close(devnull)
        _log.disable(_log.CRITICAL)

        from daffi.aio import AsyncClient

        callers: list[tuple] = []
        for i in range(n_callers):
            print(f"\r  Connecting {n_callers} callers… {i + 1}/{n_callers}", end="", flush=True)
            try:
                c = AsyncClient(app_name=f"caller-{i:03d}", host=HOST, port=port)
                callers.append((c, await c.connect()))
            except Exception as exc:
                print(f"\n  [!] caller {i} failed: {exc}")

        if not callers:
            return {"wall": 0, "per_caller": [], "responses": 0, "casts_done": 0}

        print(f"\r  Connected {len(callers)}/{n_callers} callers   ")

        results: list = [None] * len(callers)
        barrier = asyncio.Barrier(len(callers))

        async def _cast_task(client, conn, idx: int) -> None:
            try:
                for _ in range(2):
                    await conn.cast(timeout=CAST_TIMEOUT).echo(PAYLOAD)
                await barrier.wait()
                t0 = time.perf_counter()
                total_resp = 0
                for _ in range(n_casts):
                    res = await conn.cast(timeout=CAST_TIMEOUT).echo(PAYLOAD)
                    total_resp += len(res)
                elapsed = time.perf_counter() - t0
                await client.stop()
                results[idx] = (elapsed, total_resp)
            except Exception as exc:
                print(f"  [!] cast task {idx}: {exc}", flush=True)

        t0_wall = time.perf_counter()
        await asyncio.gather(*[
            _cast_task(c, conn, i) for i, (c, conn) in enumerate(callers)
        ])
        wall = time.perf_counter() - t0_wall

        per_caller = [r[0] for r in results if r is not None]
        responses  = sum(r[1] for r in results if r is not None)
        casts_done = len(per_caller) * n_casts
        return {
            "wall": wall, "per_caller": per_caller,
            "responses": responses, "casts_done": casts_done,
        }

    import json
    r = asyncio.run(_run())
    with open(result_file, "w") as f:
        json.dump(r, f)


# ── worker readiness probe ─────────────────────────────────────────────────────

async def _wait_for_workers_async(port: int, n: int, timeout: float = 60) -> None:
    from daffi.aio import AsyncClient
    from daffi._bindings import get_available_members

    probe = AsyncClient(app_name="probe-aio", host=HOST, port=port)
    await probe.connect()
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
            await probe.stop()
            await asyncio.sleep(0.1)
            return
        await asyncio.sleep(0.2)

    await probe.stop()
    raise TimeoutError(f"Only {ready}/{n} workers registered after {timeout}s")


def _wait_for_workers(port: int, n: int, timeout: float = 60) -> None:
    """Sync wrapper — used from the main process before asyncio.run."""
    from daffi import Client
    from daffi._bindings import get_available_members

    probe = Client(app_name="probe-sync", host=HOST, port=port)
    probe.connect()
    conn_num = probe._conn_num
    ready = 0

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
            time.sleep(0.1)
            return
        time.sleep(0.2)

    probe.stop()
    raise TimeoutError(f"Only {ready}/{n} workers registered after {timeout}s")


# ── scenario runners ──────────────────────────────────────────────────────────

def run_scenario_1() -> None:
    """200 async callers → AsyncService (direct)."""
    label = (
        f"Scenario 1 — {N_CLIENTS} async callers → AsyncService "
        f"(direct, workers={SERVICE_WORKERS})"
    )
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  {CALLS_PER_CLIENT} await rpc() per caller  (total: {N_CLIENTS * CALLS_PER_CLIENT:,})")
    print(f"{'='*70}")

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
    """200 async callers → AsyncRouter → Async-Worker."""
    label = f"Scenario 2 — {N_CLIENTS} async callers → AsyncRouter → 1 AsyncWorker"
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  {CALLS_PER_CLIENT} await rpc() per caller  (total: {N_CLIENTS * CALLS_PER_CLIENT:,})")
    print(f"{'='*70}")

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
    """3 async callers → AsyncRouter → N_WORKERS Async-Workers (cast broadcast)."""
    total_casts    = N_CALLERS * CASTS_PER_CALLER
    total_messages = total_casts * N_WORKERS
    label = (
        f"Scenario 3 — {N_CALLERS} async callers → AsyncRouter → "
        f"{N_WORKERS} AsyncWorkers (cast)"
    )
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  {CASTS_PER_CALLER} cast() calls per caller")
    print(f"  Total fan-out messages: {total_messages:,}  ({total_casts} casts × {N_WORKERS} workers)")
    print(f"{'='*70}")

    port = _free_port()
    router_proc = mp.Process(target=_proc_router, args=(port,), daemon=True)
    router_proc.start()
    worker_procs: list[mp.Process] = []
    try:
        _wait_for_port(port)

        print(f"  Starting {N_WORKERS} async workers…", end="", flush=True)
        for i in range(N_WORKERS):
            p = mp.Process(target=_proc_worker, args=(port, i), daemon=True)
            p.start()
            worker_procs.append(p)
        print(" done")

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
    """N_CLIENTS callers → AsyncRouter → 1 AsyncWorker (HEAVY_WORKERS tasks)."""
    label = (
        f"Scenario 4 — {N_CLIENTS} callers → AsyncRouter → "
        f"1 AsyncWorker ({HEAVY_WORKERS} tasks)"
    )
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  {CALLS_PER_CLIENT} await rpc() per caller  (total: {N_CLIENTS * CALLS_PER_CLIENT:,})")
    print(f"  (compare: scenario 2 uses 1 worker task — shows task-pool scaling)")
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
    """N_CLIENTS callers → AsyncService (HEAVY_WORKERS tasks)."""
    label = (
        f"Scenario 5 — {N_CLIENTS} callers → AsyncService ({HEAVY_WORKERS} tasks)"
    )
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  {CALLS_PER_CLIENT} await rpc() per caller  (total: {N_CLIENTS * CALLS_PER_CLIENT:,})")
    print(f"  (compare: scenario 1 uses {SERVICE_WORKERS} tasks — shows task-pool scaling)")
    print(f"{'='*70}")

    port     = _free_port()
    svc_proc = mp.Process(
        target=_proc_heavy_service, args=(port, HEAVY_WORKERS), daemon=True
    )
    svc_proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.5)
        _run_rpc_scenario(label, port, N_CLIENTS, CALLS_PER_CLIENT)
    finally:
        _quiet_kill(svc_proc)


# ── main ──────────────────────────────────────────────────────────────────────

def main(argv: Optional[list] = None) -> None:
    logging.disable(logging.CRITICAL)

    devnull = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)

    try:
        print("\ndaffi.aio concurrency benchmark  (asyncio.gather — no OS threads for callers)")
        print(f"host: {HOST}")
        print(f"payload: {PAYLOAD}")
        print(f"scenarios:")
        print(f"  1. {N_CLIENTS} async callers → AsyncService (tasks={SERVICE_WORKERS}),  {CALLS_PER_CLIENT} calls each")
        print(f"  2. {N_CLIENTS} async callers → AsyncRouter → 1 AsyncWorker,  {CALLS_PER_CLIENT} calls each")
        print(f"  3. {N_CALLERS} async callers → AsyncRouter → {N_WORKERS} AsyncWorkers,  {CASTS_PER_CALLER} casts each")
        print(f"  4. {N_CLIENTS} async callers → AsyncRouter → 1 AsyncWorker ({HEAVY_WORKERS} tasks),  {CALLS_PER_CLIENT} calls each")
        print(f"  5. {N_CLIENTS} async callers → AsyncService ({HEAVY_WORKERS} tasks),  {CALLS_PER_CLIENT} calls each")

        run_scenario_1()
        run_scenario_2()
        run_scenario_3()
        run_scenario_4()
        run_scenario_5()

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
