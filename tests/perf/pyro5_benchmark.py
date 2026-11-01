"""
Pyro5 performance benchmark — comparable to perf_benchmark.py / rpyc_benchmark.py.

Layout
------
Direct — Client Proxy → Daemon  (one TCP hop)

Also runs a daffi Client → Service baseline (PICKLE) on the same payload so the
script is a self-contained comparison.

Payload: ``data.json`` (~2 KB nested order record), echoed unchanged.

Requires::

    pip install Pyro5

Run::

    python3 tests/perf/pyro5_benchmark.py
"""

from __future__ import annotations

import json
import logging
import multiprocessing as mp
import os
import socket
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
from tests.conftest import active_runtime

_DATA_FILE = Path(__file__).parent / "data.json"

N = 100_000
WARMUP = 20
TIMEOUT = 30
HOST = "127.0.0.1"


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
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
    raise TimeoutError(f"Server on {HOST}:{port} did not become ready within {timeout}s")


def _silence() -> None:
    dn = os.open(os.devnull, os.O_WRONLY)
    os.dup2(dn, 1)
    os.dup2(dn, 2)
    os.close(dn)
    logging.disable(logging.CRITICAL)


def _silence_daffi(runtime: str) -> None:
    _silence()
    import tests.conftest as _runtime_state

    _runtime_state.SELECTED_RUNTIME = runtime
    from daffi import dfcore

    dfcore.setRuntime(runtime)


def _report(label: str, latencies_ms: list[float]) -> float:
    n = len(latencies_ms)
    total_s = sum(latencies_ms) / 1_000
    rate = n / total_s
    print(f"  {label}: {total_s:.3f} s for {n} calls  ({rate:.0f} calls/s)")
    return rate


def _measure(tag: str, call) -> list[float]:
    print(f"  [{tag}] warming up ({WARMUP} calls)…", end="", flush=True)
    for _ in range(WARMUP):
        call()
    print(" done")
    print(f"  [{tag}] measuring {N} calls…", end="", flush=True)
    latencies: list[float] = []
    for _ in range(N):
        t0 = time.perf_counter()
        call()
        latencies.append((time.perf_counter() - t0) * 1_000)
    print(" done")
    return latencies


# ── Pyro5 ─────────────────────────────────────────────────────────────────────


def _proc_pyro5(port: int) -> None:
    _silence()
    import Pyro5.api

    @Pyro5.api.expose
    class Echo:
        def echo(self, payload):
            return payload

    # Serpent is the default serializer (JSON-like); fine for nested dicts.
    daemon = Pyro5.api.Daemon(host=HOST, port=port)
    daemon.register(Echo, objectId="echo")
    daemon.requestLoop()


def bench_pyro5(data: dict) -> list[float]:
    import Pyro5.api

    port = _free_port()
    proc = mp.Process(target=_proc_pyro5, args=(port,), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.1)
        proxy = Pyro5.api.Proxy(f"PYRO:echo@{HOST}:{port}")
        proxy._pyroTimeout = TIMEOUT
        try:
            return _measure("pyro5", lambda: proxy.echo(data))
        finally:
            proxy._pyroRelease()
    finally:
        proc.terminate()
        proc.join(timeout=5)


# ── daffi baseline ────────────────────────────────────────────────────────────


def _proc_daffi(runtime: str, port: int) -> None:
    _silence_daffi(runtime)
    from daffi import Service, TCPTransport, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="pyro-cmp-svc", transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def bench_daffi_pickle(data: dict) -> list[float]:
    from daffi import Client, TCPTransport
    from daffi._serialization import SerdeFormat

    port = _free_port()
    proc = mp.Process(target=_proc_daffi, args=(active_runtime(), port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)
        client = Client(
            app_name="pyro-cmp-cli",
            transport=TCPTransport(HOST, port),
            runtime=active_runtime(),
        )
        c = client.connect().rpc(timeout=TIMEOUT, serde=SerdeFormat.PICKLE)
        try:
            return _measure("daffi-pickle", lambda: c.echo(data))
        finally:
            client.stop()
    finally:
        proc.terminate()
        proc.join(timeout=5)


def main() -> None:
    logging.disable(logging.INFO)
    try:
        import Pyro5
    except ImportError:
        print("Pyro5 not installed — pip install Pyro5", file=sys.stderr)
        sys.exit(1)

    data = json.loads(_DATA_FILE.read_text())
    payload_bytes = len(json.dumps(data).encode())

    print(f"\nPyro5 {Pyro5.__version__} vs daffi  —  {N} sequential rpc calls")
    print(f"host: {HOST}   warmup: {WARMUP}   payload: {_DATA_FILE.name} ({payload_bytes} bytes JSON)")
    print("layout: Direct (one TCP hop); daffi serde=PICKLE (object RPC peer)\n")

    print("── Pyro5 ────────────────────────────────────────────────")
    pyro_rate = _report("Pyro5", bench_pyro5(data))

    print("\n── daffi (PICKLE) ──────────────────────────────────────")
    daffi_rate = _report("daffi PICKLE", bench_daffi_pickle(data))

    print("\n── Summary (calls/s) ───────────────────────────────────")
    print(f"  {'stack':<16}  {'calls/s':>10}")
    print(f"  {'----------------':<16}  {'----------':>10}")
    print(f"  {'Pyro5':<16}  {pyro_rate:>10.0f}")
    print(f"  {'daffi PICKLE':<16}  {daffi_rate:>10.0f}")
    if pyro_rate > 0:
        print(f"\n  daffi vs Pyro5: {daffi_rate / pyro_rate:.2f}×\n")


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
