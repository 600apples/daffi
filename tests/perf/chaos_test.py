"""
daffi chaos test — randomised RPC stress test (default 30 minutes).

Topology
--------
  Router  (1 subprocess, permanent)
  ├── Worker-0..W-1   (W subprocesses, Client + @callback: worker_echo/add/ping)
  └── CallerThread-0..N-1  (in-process, random rpc/rpc_nowait/cast/cast_nowait)

  Service-0..S-1  (S subprocesses, Service + @callback: svc_echo/svc_double)
  └── ServiceCallerThread-0..M-1  (in-process, random rpc/rpc_nowait)

All caller threads share a global stop event.  On the first unexpected error
(wrong result, exception from an RPC call, or any OS/network problem) the
thread records a BUG report, sets the stop event, and exits.  The main thread
collects all reports and exits with code 1.

Usage
-----
  python tests/perf/chaos_test.py            # 30-minute full run
  python tests/perf/chaos_test.py --short    # 60-second smoke test
  python tests/perf/chaos_test.py --duration 300
"""

from __future__ import annotations

import argparse
import logging
import multiprocessing as mp
import os
import random
import socket
import sys
import threading
import time
from queue import Empty, Queue

# ─── tunables (overridden by CLI args before threads start) ──────────────────

DURATION           = 30 * 60    # seconds (default 30 min)
N_WORKERS          = 3          # worker subprocesses (router topology)
N_SERVICES         = 2          # service subprocesses (direct topology)
N_ROUTER_CALLERS   = 8          # in-process threads calling workers via router
N_SERVICE_CALLERS  = 4          # in-process threads calling services directly
CALL_TIMEOUT       = 10.0       # RPC timeout for blocking calls
RECONNECT_EVERY    = 500        # reconnect after this many calls per thread
REPORT_INTERVAL    = 10.0       # stats print interval (seconds)
HOST               = "127.0.0.1"

# rpc mode weights — (mode, weight); must sum to 100
_MODE_TABLE = [
    ("rpc",         40),
    ("rpc_nowait",  20),
    ("cast",        20),
    ("cast_nowait", 20),
]
_MODES      = [m for m, _ in _MODE_TABLE]
_WEIGHTS    = [w for _, w in _MODE_TABLE]

# ─── shared state ─────────────────────────────────────────────────────────────

_stop   = threading.Event()          # set on error or timeout
_errors: "Queue[tuple]" = Queue()    # (thread_name, exc, context, traceback_str)

_counts      = {m: 0 for m in _MODES}
_counts_lock = threading.Lock()

# ─── infrastructure helpers ───────────────────────────────────────────────────

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
    raise TimeoutError(f"{HOST}:{port} did not open within {timeout}s")


def _silence() -> None:
    """Redirect stdout/stderr to /dev/null and kill logging.  Called in every
    subprocess at startup so Zig native prints don't pollute the terminal."""
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)
    try:
        from daffi.registry._executor_registry import EXECUTOR_REGISTRY
        EXECUTOR_REGISTRY.subscribers.clear()
        EXECUTOR_REGISTRY.registry.clear()
    except Exception:
        pass


def _quiet_kill(proc: mp.Process, timeout: float = 5.0) -> None:
    devnull = os.open(os.devnull, os.O_WRONLY)
    saved = (os.dup(1), os.dup(2))
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    try:
        proc.terminate()
    finally:
        os.dup2(saved[0], 1)
        os.dup2(saved[1], 2)
        os.close(saved[0])
        os.close(saved[1])
    proc.join(timeout=timeout)


def _probe_wait(port: int, members: set[str], timeout: float = 30.0) -> None:
    """Open a throw-away client, wait for *members*, disconnect."""
    from daffi import Client
    c = Client(app_name=f"chaos-probe-{os.getpid()}-{id(members)}", host=HOST, port=port)
    conn = c.connect()
    try:
        conn.wait_for_members(*members, timeout=timeout)
    finally:
        c.stop()


# ─── subprocess entry points (must import daffi lazily after _silence) ────────

def _proc_router(port: int) -> None:
    _silence()
    from daffi import Router
    r = Router(app_name="chaos-router", host=HOST, port=port)
    r.start()
    r.join()


def _proc_worker(port: int, worker_id: int) -> None:
    """Client-worker subprocess: registers callbacks and keeps running."""
    _silence()
    import time as _t
    from daffi import Client, callback

    @callback
    def worker_echo(payload: bytes) -> bytes:
        return payload

    @callback
    def worker_add(a: int, b: int) -> int:
        return a + b

    @callback
    def worker_ping() -> str:
        return "pong"

    client = Client(
        app_name=f"chaos-worker-{worker_id}",
        host=HOST,
        port=port,
        workers=4,
    )
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def _proc_service(port: int, service_id: int) -> None:
    _silence()
    from daffi import Service, callback

    @callback
    def svc_echo(payload: bytes) -> bytes:
        return payload

    @callback
    def svc_double(n: int) -> int:
        return n * 2

    svc = Service(
        app_name=f"chaos-service-{service_id}",
        host=HOST,
        port=port,
        workers=4,
    )
    svc.start()
    svc.join()


# ─── RPC action helpers (called from within caller threads) ───────────────────

def _do_rpc(conn, rng: random.Random, worker_names: list[str]) -> None:
    method   = rng.choice(("worker_echo", "worker_add", "worker_ping"))
    receiver = rng.choice(worker_names) if rng.random() < 0.5 else None
    kwargs   = {"timeout": CALL_TIMEOUT}
    if receiver:
        kwargs["receiver"] = receiver
    proxy = conn.rpc(**kwargs)

    if method == "worker_echo":
        payload = bytes(rng.getrandbits(8) for _ in range(rng.randint(10, 200)))
        result = proxy.worker_echo(payload)
        if result != payload:
            raise AssertionError(
                f"worker_echo: result mismatch (got {len(result)} bytes, "
                f"expected {len(payload)} bytes)"
            )
    elif method == "worker_add":
        a, b = rng.randint(0, 10_000), rng.randint(0, 10_000)
        result = proxy.worker_add(a, b)
        if result != a + b:
            raise AssertionError(f"worker_add({a},{b}): expected {a+b}, got {result!r}")
    else:
        result = proxy.worker_ping()
        if result != "pong":
            raise AssertionError(f"worker_ping: expected 'pong', got {result!r}")


def _do_rpc_nowait(conn, rng: random.Random, worker_names: list[str]) -> None:
    method   = rng.choice(("worker_echo", "worker_add", "worker_ping"))
    receiver = rng.choice(worker_names) if rng.random() < 0.5 else None
    kwargs   = {"receiver": receiver} if receiver else {}
    proxy    = conn.rpc_nowait(**kwargs)

    if method == "worker_echo":
        proxy.worker_echo(bytes(rng.getrandbits(8) for _ in range(rng.randint(1, 50))))
    elif method == "worker_add":
        proxy.worker_add(rng.randint(0, 100), rng.randint(0, 100))
    else:
        proxy.worker_ping()


def _do_cast(conn, rng: random.Random, n_workers: int) -> None:
    method = rng.choice(("worker_echo", "worker_add", "worker_ping"))
    proxy  = conn.cast(timeout=CALL_TIMEOUT)

    if method == "worker_echo":
        payload = bytes(rng.getrandbits(8) for _ in range(rng.randint(10, 100)))
        results = proxy.worker_echo(payload)
        if len(results) != n_workers:
            raise AssertionError(
                f"cast worker_echo: expected {n_workers} results, got {len(results)}"
            )
        for name, val in results.items():
            if isinstance(val, Exception):
                raise AssertionError(f"cast worker_echo from {name!r} raised: {val}") from val
            if val != payload:
                raise AssertionError(
                    f"cast worker_echo from {name!r}: result mismatch "
                    f"(got {len(val)} bytes, expected {len(payload)} bytes)"
                )
    elif method == "worker_add":
        a, b = rng.randint(0, 1000), rng.randint(0, 1000)
        results = proxy.worker_add(a, b)
        if len(results) != n_workers:
            raise AssertionError(
                f"cast worker_add: expected {n_workers} results, got {len(results)}"
            )
        for name, val in results.items():
            if isinstance(val, Exception):
                raise AssertionError(f"cast worker_add from {name!r} raised: {val}") from val
            if val != a + b:
                raise AssertionError(
                    f"cast worker_add({a},{b}) from {name!r}: expected {a+b}, got {val!r}"
                )
    else:
        results = proxy.worker_ping()
        if len(results) != n_workers:
            raise AssertionError(
                f"cast worker_ping: expected {n_workers} results, got {len(results)}"
            )
        for name, val in results.items():
            if isinstance(val, Exception):
                raise AssertionError(f"cast worker_ping from {name!r} raised: {val}") from val
            if val != "pong":
                raise AssertionError(
                    f"cast worker_ping from {name!r}: expected 'pong', got {val!r}"
                )


def _do_cast_nowait(conn, rng: random.Random) -> None:
    method = rng.choice(("worker_echo", "worker_add", "worker_ping"))
    proxy  = conn.cast_nowait()
    if method == "worker_echo":
        proxy.worker_echo(bytes(rng.getrandbits(8) for _ in range(rng.randint(1, 50))))
    elif method == "worker_add":
        proxy.worker_add(rng.randint(0, 100), rng.randint(0, 100))
    else:
        proxy.worker_ping()


# ─── caller thread loops ──────────────────────────────────────────────────────

def _router_caller_loop(
    caller_id:    int,
    router_port:  int,
    worker_names: list[str],
) -> None:
    """Fire randomised RPCs to workers via the router until _stop is set."""
    from daffi import Client
    from daffi.exceptions import (
        CallTimeout, Disconnected, Evicted, RemoteCallError, TransmissionFailure,
    )

    thread_name = f"RouterCaller-{caller_id}"
    rng         = random.Random(caller_id)
    call_count  = 0
    attempt     = 0

    def _connect():
        nonlocal attempt
        attempt += 1
        c    = Client(
            app_name=f"chaos-rcaller-{caller_id}-r{attempt}",
            host=HOST,
            port=router_port,
        )
        conn = c.connect()
        conn.wait_for_members(*worker_names, timeout=30)
        return c, conn

    def _bug(exc: Exception, ctx: str) -> None:
        import traceback
        _errors.put((thread_name, exc, ctx, traceback.format_exc()))
        _stop.set()

    try:
        client, conn = _connect()
    except Exception as e:
        _bug(e, "initial connect")
        return

    try:
        while not _stop.is_set():
            # Periodic reconnect to exercise client lifecycle.
            if call_count > 0 and call_count % RECONNECT_EVERY == 0:
                try:
                    client.stop()
                except Exception:
                    pass
                time.sleep(rng.uniform(0.02, 0.15))
                if _stop.is_set():
                    break
                try:
                    client, conn = _connect()
                except Exception as e:
                    _bug(e, f"reconnect after {call_count} calls")
                    return

            mode = rng.choices(_MODES, weights=_WEIGHTS, k=1)[0]
            call_count += 1
            ctx = f"{mode} call #{call_count}"

            try:
                if mode == "rpc":
                    _do_rpc(conn, rng, worker_names)
                elif mode == "rpc_nowait":
                    _do_rpc_nowait(conn, rng, worker_names)
                elif mode == "cast":
                    _do_cast(conn, rng, len(worker_names))
                else:
                    _do_cast_nowait(conn, rng)

                with _counts_lock:
                    _counts[mode] += 1

            except AssertionError as e:
                _bug(e, f"WRONG RESULT: {ctx}")
                return
            except (CallTimeout, TransmissionFailure, RemoteCallError,
                    Disconnected, Evicted) as e:
                _bug(e, f"RPC ERROR: {ctx}")
                return
            except Exception as e:
                _bug(e, f"UNEXPECTED: {ctx}")
                return

    finally:
        try:
            client.stop()
        except Exception:
            pass


def _service_caller_loop(
    caller_id:    int,
    service_port: int,
    service_name: str,
) -> None:
    """Fire randomised rpc / rpc_nowait calls to a Service (direct, no router)."""
    from daffi import Client
    from daffi.exceptions import (
        CallTimeout, Disconnected, Evicted, RemoteCallError, TransmissionFailure,
    )

    thread_name = f"ServiceCaller-{caller_id}"
    rng         = random.Random(10_000 + caller_id)
    call_count  = 0
    attempt     = 0

    def _connect():
        nonlocal attempt
        attempt += 1
        c    = Client(
            app_name=f"chaos-scaller-{caller_id}-r{attempt}",
            host=HOST,
            port=service_port,
        )
        conn = c.connect()
        conn.wait_for_members(service_name, timeout=30)
        return c, conn

    def _bug(exc: Exception, ctx: str) -> None:
        import traceback
        _errors.put((thread_name, exc, ctx, traceback.format_exc()))
        _stop.set()

    try:
        client, conn = _connect()
    except Exception as e:
        _bug(e, "initial connect to service")
        return

    try:
        while not _stop.is_set():
            if call_count > 0 and call_count % RECONNECT_EVERY == 0:
                try:
                    client.stop()
                except Exception:
                    pass
                time.sleep(rng.uniform(0.02, 0.15))
                if _stop.is_set():
                    break
                try:
                    client, conn = _connect()
                except Exception as e:
                    _bug(e, f"reconnect to {service_name} after {call_count} calls")
                    return

            use_nowait = rng.random() < 0.3
            call_count += 1
            ctx = f"{'rpc_nowait' if use_nowait else 'rpc'} call #{call_count} → {service_name}"

            try:
                if use_nowait:
                    proxy = conn.rpc_nowait(receiver=service_name)
                    if rng.random() < 0.5:
                        proxy.svc_echo(bytes(rng.getrandbits(8) for _ in range(rng.randint(1, 50))))
                    else:
                        proxy.svc_double(rng.randint(0, 100))
                    with _counts_lock:
                        _counts["rpc_nowait"] += 1
                else:
                    proxy = conn.rpc(timeout=CALL_TIMEOUT, receiver=service_name)
                    if rng.random() < 0.5:
                        payload = bytes(rng.getrandbits(8) for _ in range(rng.randint(10, 200)))
                        result  = proxy.svc_echo(payload)
                        if result != payload:
                            raise AssertionError(
                                f"svc_echo: result mismatch "
                                f"(got {len(result)} bytes, expected {len(payload)} bytes)"
                            )
                    else:
                        n      = rng.randint(0, 10_000)
                        result = proxy.svc_double(n)
                        if result != n * 2:
                            raise AssertionError(
                                f"svc_double({n}): expected {n*2}, got {result!r}"
                            )
                    with _counts_lock:
                        _counts["rpc"] += 1

            except AssertionError as e:
                _bug(e, f"WRONG RESULT: {ctx}")
                return
            except (CallTimeout, TransmissionFailure, RemoteCallError,
                    Disconnected, Evicted) as e:
                _bug(e, f"RPC ERROR: {ctx}")
                return
            except Exception as e:
                _bug(e, f"UNEXPECTED: {ctx}")
                return

    finally:
        try:
            client.stop()
        except Exception:
            pass


# ─── stats thread ─────────────────────────────────────────────────────────────

def _stats_loop(start: float) -> None:
    while not _stop.wait(REPORT_INTERVAL):
        elapsed   = time.monotonic() - start
        remaining = max(0.0, DURATION - elapsed)
        with _counts_lock:
            c = dict(_counts)
        total = sum(c.values())
        rate  = total / max(elapsed, 1)
        print(
            f"  [{elapsed:6.0f}s / {DURATION}s]  "
            f"calls={total:,}  {rate:.0f}/s  "
            f"rpc={c['rpc']:,}  nowait={c['rpc_nowait']:,}  "
            f"cast={c['cast']:,}  cast_nw={c['cast_nowait']:,}  "
            f"left={remaining:.0f}s",
            flush=True,
        )


# ─── main run ─────────────────────────────────────────────────────────────────

def _run() -> None:
    router_port   = _free_port()
    service_ports = [_free_port() for _ in range(N_SERVICES)]
    worker_names  = [f"chaos-worker-{i}" for i in range(N_WORKERS)]
    service_names = [f"chaos-service-{i}" for i in range(N_SERVICES)]

    print(f"\ndaffi — chaos test")
    print(f"  duration     : {DURATION}s  ({DURATION / 60:.1f} min)")
    print(f"  router port  : {router_port}")
    print(f"  workers      : {N_WORKERS}  ({', '.join(worker_names)})")
    print(f"  services     : {N_SERVICES}  ({', '.join(service_names)})")
    print(f"  router-callers: {N_ROUTER_CALLERS}  "
          f"service-callers: {N_SERVICE_CALLERS}")
    print(f"  call timeout : {CALL_TIMEOUT}s  "
          f"reconnect every: {RECONNECT_EVERY} calls")
    print()

    procs:   list[mp.Process]    = []
    threads: list[threading.Thread] = []
    start    = time.monotonic()

    try:
        # ── router ────────────────────────────────────────────────────────────
        rproc = mp.Process(target=_proc_router, args=(router_port,), daemon=True)
        rproc.start()
        procs.append(rproc)
        _wait_for_port(router_port)
        print("  Router ready.")

        # ── workers ───────────────────────────────────────────────────────────
        for i in range(N_WORKERS):
            p = mp.Process(target=_proc_worker, args=(router_port, i), daemon=True)
            p.start()
            procs.append(p)

        print(f"  Waiting for {N_WORKERS} workers…", end="", flush=True)
        _probe_wait(router_port, set(worker_names))
        print(" done.")

        # ── services ──────────────────────────────────────────────────────────
        for i in range(N_SERVICES):
            p = mp.Process(target=_proc_service, args=(service_ports[i], i), daemon=True)
            p.start()
            procs.append(p)
            _wait_for_port(service_ports[i])
        print(f"  {N_SERVICES} services ready.")

        # ── caller threads ────────────────────────────────────────────────────
        for i in range(N_ROUTER_CALLERS):
            t = threading.Thread(
                target=_router_caller_loop,
                args=(i, router_port, worker_names),
                name=f"RouterCaller-{i}",
                daemon=True,
            )
            t.start()
            threads.append(t)

        for i in range(N_SERVICE_CALLERS):
            svc_idx = i % N_SERVICES
            t = threading.Thread(
                target=_service_caller_loop,
                args=(i, service_ports[svc_idx], service_names[svc_idx]),
                name=f"ServiceCaller-{i}",
                daemon=True,
            )
            t.start()
            threads.append(t)

        # ── stats thread ──────────────────────────────────────────────────────
        stats_t = threading.Thread(
            target=_stats_loop, args=(start,), name="stats", daemon=True
        )
        stats_t.start()

        total_threads = len(threads)
        print(f"\n  {total_threads} chaos threads running — press Ctrl+C to abort.\n")

        # ── wait ──────────────────────────────────────────────────────────────
        _stop.wait(timeout=DURATION)

    except KeyboardInterrupt:
        print("\n  Interrupted.", flush=True)
    finally:
        _stop.set()
        for t in threads:
            t.join(timeout=15)
        for p in procs:
            _quiet_kill(p)

    elapsed = time.monotonic() - start
    with _counts_lock:
        c = dict(_counts)
    total = sum(c.values())

    # ── report ────────────────────────────────────────────────────────────────
    if not _errors.empty():
        print("\n" + "!" * 68)
        print("  BUG DETECTED — chaos test FAILED")
        print("!" * 68)
        while True:
            try:
                tname, exc, ctx, tb = _errors.get_nowait()
                print(f"\n  Thread  : {tname}")
                print(f"  Context : {ctx}")
                print(f"  Error   : {type(exc).__name__}: {exc}")
                print(f"  Traceback:\n{tb}")
            except Empty:
                break
        print(f"\n  Calls completed before failure: {total:,}")
        sys.exit(1)

    print("=" * 68)
    print("  chaos test PASSED")
    print("=" * 68)
    print(f"  elapsed      : {elapsed:.0f}s")
    print(f"  total calls  : {total:,}  ({total / max(elapsed, 1):.0f}/s avg)")
    print(f"  rpc          : {c['rpc']:,}")
    print(f"  rpc_nowait   : {c['rpc_nowait']:,}")
    print(f"  cast         : {c['cast']:,}")
    print(f"  cast_nowait  : {c['cast_nowait']:,}")
    print()


def main() -> None:
    logging.disable(logging.CRITICAL)
    # Suppress Zig native teardown noise on stderr for the duration of the run.
    devnull      = os.open(os.devnull, os.O_WRONLY)
    saved_stderr = os.dup(2)
    os.dup2(devnull, 2)
    os.close(devnull)
    try:
        _run()
    finally:
        os.dup2(saved_stderr, 2)
        os.close(saved_stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="daffi chaos test — randomised RPC stress test",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--duration", type=int, default=DURATION,
        help="How long to run (seconds)",
    )
    parser.add_argument(
        "--short", action="store_true",
        help="Quick 60-second smoke test (overrides --duration)",
    )
    parser.add_argument("--workers",  type=int, default=N_WORKERS,  help="Worker subprocesses")
    parser.add_argument("--services", type=int, default=N_SERVICES, help="Service subprocesses")
    parser.add_argument("--callers",  type=int, default=N_ROUTER_CALLERS, help="Router caller threads")
    args = parser.parse_args()

    DURATION          = 60 if args.short else args.duration
    N_WORKERS         = args.workers
    N_SERVICES        = args.services
    N_ROUTER_CALLERS  = args.callers

    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
