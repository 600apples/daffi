"""
Shared helpers and fixtures for daffi integration tests.

All integration tests use the current public API:
  Router / Service / Client / callback / alias
instead of the removed Global / FG / BG / PERIOD / fetcher layer.
"""
from __future__ import annotations

import logging
import multiprocessing as mp
import os
import socket
import time

import pytest

# Use "spawn" so each subprocess starts from a clean, freshly-loaded Python
# interpreter.  This avoids two classes of macOS-specific bugs:
#
#   * The native ``daffi.dfcore`` extension (and its Zig-allocated mutexes,
#     libcrypto contexts, background threads, etc.) gets imported in the
#     pytest parent as soon as any test creates a Client / Service / Router.
#     A forked child inherits that half-initialised native state and
#     segfaults on first use.  With ``spawn`` the child loads dfcore fresh.
#
#   * Objective-C runtime fork-safety.  Anything that pulls in CoreFoundation
#     in the parent (most stdlib HTTP, DNS, logging on macOS) aborts the
#     child on first ObjC call unless OBJC_DISABLE_INITIALIZE_FORK_SAFETY is
#     set.  ``spawn`` sidesteps this entirely.
#
# All mp.Process targets in the integration suite are module-level functions
# (picklable) so spawn works on every platform we target — macOS, Linux, and
# Python 3.14+ which is moving away from fork as the default.
mp.set_start_method("spawn", force=True)

# ── constants available to all test modules ────────────────────────────────────

HOST    = "127.0.0.1"
TIMEOUT = 30   # per-call RPC timeout in seconds


# ── low-level helpers (importable by test modules) ─────────────────────────────

def wait_for_port(port: int, timeout: float = 15.0) -> None:
    """Block until the TCP port on HOST is accepting connections."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"Port {HOST}:{port} did not open within {timeout}s")


def wait_for_members(
    port: int,
    expected: set[str],
    *,
    timeout: float = 15.0,
    probe_name: str = "_fx-probe",
) -> None:
    """Open a throw-away Client, wait until every name in *expected* is
    registered with the router/service on *port*, and disconnect.

    Deterministic replacement for ``time.sleep(N)`` in fixtures that spawn
    multiple worker subprocesses and need all of them registered before the
    test body issues a cast() / rpc() call.  Critical under the ``spawn``
    start method, where per-subprocess startup can easily exceed a second
    on macOS.
    """
    from daffi import Client  # noqa: PLC0415 — import lazily so fresh spawned
                              # children don't pull daffi in during fixture
                              # import.
    client = Client(app_name=probe_name, host=HOST, port=port)
    conn = client.connect()
    try:
        conn.wait_for_members(*expected, timeout=timeout)
    finally:
        client.stop()


def silence_subprocess() -> None:
    """Redirect stdout/stderr to /dev/null and disable Python logging.

    Called at the very start of every subprocess target so that Zig native
    prints and daffi logs don't pollute pytest output.

    Also clears ``EXECUTOR_REGISTRY`` — harmless under ``spawn`` (the child
    starts with an empty registry anyway) but keeps behaviour identical if
    someone switches the start method back to fork for debugging.
    """
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)
    logging.disable(logging.CRITICAL)

    from daffi.registry._executor_registry import EXECUTOR_REGISTRY  # noqa: PLC0415
    EXECUTOR_REGISTRY.subscribers.clear()
    EXECUTOR_REGISTRY.registry.clear()


def quiet_kill(proc: mp.Process, timeout: float = 5.0) -> None:
    """Terminate *proc* while suppressing any fd-level output it produces."""
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


# ── common subprocess entry points ─────────────────────────────────────────────

def proc_service(port: int, app_name: str = "integ-service", workers: int = 4) -> None:
    """Service subprocess: registers echo + add callbacks, then joins."""
    silence_subprocess()
    from daffi import Service, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    svc = Service(app_name=app_name, host=HOST, port=port, workers=workers)
    svc.start()
    svc.join()


def proc_router(port: int, app_name: str = "integ-router") -> None:
    """Router subprocess: pure message broker, no callbacks."""
    silence_subprocess()
    from daffi import Router

    r = Router(app_name=app_name, host=HOST, port=port)
    r.start()
    r.join()


def proc_worker(port: int, app_name: str, workers: int = 4) -> None:
    """Client+callback worker subprocess: registers echo + add, keeps running."""
    silence_subprocess()
    import time as _time
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    @callback
    def add(a: int, b: int) -> int:
        return a + b

    client = Client(app_name=app_name, host=HOST, port=port, workers=workers)
    client.connect()
    try:
        while True:
            _time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── pytest fixtures ────────────────────────────────────────────────────────────

@pytest.fixture
def free_port() -> int:
    """Return an unused TCP port on HOST."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, 0))
        return s.getsockname()[1]


@pytest.fixture
def direct_service(free_port):
    """Start a Service subprocess; yield its port; terminate on teardown."""
    proc = mp.Process(
        target=proc_service, args=(free_port,), daemon=True
    )
    proc.start()
    wait_for_port(free_port)
    wait_for_members(free_port, {"integ-service"})
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def router_with_worker(free_port):
    """Start Router + one Worker subprocess; yield the router port."""
    rproc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(
        target=proc_worker, args=(free_port, "integ-worker"), daemon=True
    )
    wproc.start()
    wait_for_members(free_port, {"integ-worker"})
    yield free_port
    quiet_kill(wproc)
    quiet_kill(rproc)
