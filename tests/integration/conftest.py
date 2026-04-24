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

# Python 3.14+ changed the default start method on Linux from "fork" to
# "forkserver".  Integration tests define their subprocess targets as
# module-level functions in test files, which are not importable from the
# forkserver's fresh interpreter.  "fork" is simpler, safe in our single-
# threaded-at-fork test harness, and works on every POSIX platform we target.
mp.set_start_method("fork", force=True)

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


def silence_subprocess() -> None:
    """Redirect stdout/stderr to /dev/null and disable Python logging.

    Called at the very start of every subprocess target so that Zig native
    prints and daffi logs don't pollute pytest output.

    Also clears ``EXECUTOR_REGISTRY`` state inherited via ``os.fork()``.
    When the pytest runner (parent) creates a Client or Service in a test,
    that object appends a ``registry_subscriber`` closure to
    ``EXECUTOR_REGISTRY.subscribers``.  A forked child inherits this list.
    Any subsequent ``@callback`` application in the child fires those stale
    closures, which try to call ``_process_client_handshake`` on a
    non-existent native connection and raise ``ClientNotInitialized``.
    Clearing both ``subscribers`` and ``registry`` at fork gives each
    subprocess a clean slate before it registers its own callbacks.
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
    time.sleep(0.15)   # let callbacks register
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
    time.sleep(0.4)   # let worker connect and register callbacks
    yield free_port
    quiet_kill(wproc)
    quiet_kill(rproc)
