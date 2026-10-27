"""
RPyC vs daffi performance benchmark — comparable to zerorpc_benchmark.py.

Layouts
-------
1. Direct     — Client → Server / Service  (one TCP hop)
2. Via hop    — RPyC Client → Proxy → Worker
                daffi Client → Router → Worker

Payload: ``data.json`` (~2 KB), echoed unchanged.  daffi uses PICKLE (object
RPC peer to RPyC's brine serialization of the same dict).

Requires::

    pip install rpyc

Run::

    python3 tests/perf/rpyc_benchmark.py
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


# ── RPyC ──────────────────────────────────────────────────────────────────────


def _proc_rpyc_server(port: int) -> None:
    _silence()
    import rpyc
    from rpyc.utils.server import ThreadedServer

    class EchoService(rpyc.Service):
        def exposed_echo(self, payload):
            return payload

    ThreadedServer(
        EchoService,
        hostname=HOST,
        port=port,
        protocol_config={"allow_public_attrs": True},
    ).start()


def _proc_rpyc_worker(port: int) -> None:
    _proc_rpyc_server(port)


def _proc_rpyc_proxy(proxy_port: int, worker_port: int) -> None:
    _silence()
    import rpyc
    from rpyc.utils.server import ThreadedServer

    _backend: list = []

    class ProxyService(rpyc.Service):
        def on_connect(self, conn):
            if not _backend:
                _backend.append(
                    rpyc.connect(HOST, worker_port, config={"allow_public_attrs": True})
                )

        def exposed_echo(self, payload):
            return _backend[0].root.echo(payload)

    ThreadedServer(
        ProxyService,
        hostname=HOST,
        port=proxy_port,
        protocol_config={"allow_public_attrs": True},
    ).start()


def bench_rpyc_direct(data: dict) -> list[float]:
    import rpyc

    port = _free_port()
    proc = mp.Process(target=_proc_rpyc_server, args=(port,), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        conn = rpyc.connect(
            HOST,
            port,
            config={"allow_public_attrs": True, "sync_request_timeout": TIMEOUT},
        )
        svc = conn.root
        try:
            return _measure("rpyc-direct", lambda: svc.echo(data))
        finally:
            conn.close()
    finally:
        proc.terminate()
        proc.join(timeout=5)


def bench_rpyc_via_proxy(data: dict) -> list[float]:
    import rpyc

    worker_port = _free_port()
    proxy_port = _free_port()
    worker_proc = mp.Process(target=_proc_rpyc_worker, args=(worker_port,), daemon=True)
    proxy_proc = mp.Process(
        target=_proc_rpyc_proxy, args=(proxy_port, worker_port), daemon=True
    )
    worker_proc.start()
    try:
        _wait_for_port(worker_port)
        proxy_proc.start()
        _wait_for_port(proxy_port)
        time.sleep(0.1)
        conn = rpyc.connect(
            HOST,
            proxy_port,
            config={"allow_public_attrs": True, "sync_request_timeout": TIMEOUT},
        )
        svc = conn.root
        try:
            return _measure("rpyc-proxy", lambda: svc.echo(data))
        finally:
            conn.close()
    finally:
        proxy_proc.terminate()
        proxy_proc.join(timeout=5)
        worker_proc.terminate()
        worker_proc.join(timeout=5)


# ── daffi baselines ───────────────────────────────────────────────────────────


def _proc_daffi_service(runtime: str, port: int) -> None:
    _silence_daffi(runtime)
    from daffi import Service, TCPTransport, callback

    @callback
    def echo(payload):
        return payload

    svc = Service(app_name="rpyc-cmp-svc", transport=TCPTransport(HOST, port), runtime=runtime)
    svc.start()
    svc.join()


def _proc_daffi_router(runtime: str, port: int) -> None:
    _silence_daffi(runtime)
    from daffi import Router, TCPTransport

    router = Router(app_name="rpyc-cmp-router", transport=TCPTransport(HOST, port), runtime=runtime)
    router.start()
    router.join()


def _proc_daffi_worker(runtime: str, port: int) -> None:
    _silence_daffi(runtime)
    from daffi import Client, TCPTransport, callback

    @callback
    def echo(payload):
        return payload

    client = Client(app_name="rpyc-cmp-worker", transport=TCPTransport(HOST, port), runtime=runtime)
    client.connect()
    try:
        while True:
            time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def bench_daffi_direct(data: dict) -> list[float]:
    from daffi import Client, TCPTransport
    from daffi._serialization import SerdeFormat

    port = _free_port()
    proc = mp.Process(target=_proc_daffi_service, args=(active_runtime(), port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)
        client = Client(
            app_name="rpyc-cmp-cli",
            transport=TCPTransport(HOST, port),
            runtime=active_runtime(),
        )
        c = client.connect().rpc(timeout=TIMEOUT, serde=SerdeFormat.PICKLE)
        try:
            return _measure("daffi-direct", lambda: c.echo(data))
        finally:
            client.stop()
    finally:
        proc.terminate()
        proc.join(timeout=5)


def bench_daffi_via_router(data: dict) -> list[float]:
    from daffi import Client, TCPTransport
    from daffi._serialization import SerdeFormat

    port = _free_port()
    router_proc = mp.Process(target=_proc_daffi_router, args=(active_runtime(), port), daemon=True)
    worker_proc = mp.Process(target=_proc_daffi_worker, args=(active_runtime(), port), daemon=True)
    router_proc.start()
    try:
        _wait_for_port(port)
        worker_proc.start()
        time.sleep(0.4)
        client = Client(
            app_name="rpyc-cmp-router-cli",
            transport=TCPTransport(HOST, port),
            runtime=active_runtime(),
        )
        c = client.connect().rpc(timeout=TIMEOUT, serde=SerdeFormat.PICKLE)
        try:
            return _measure("daffi-router", lambda: c.echo(data))
        finally:
            client.stop()
    finally:
        worker_proc.terminate()
        worker_proc.join(timeout=5)
        router_proc.terminate()
        router_proc.join(timeout=5)


def main() -> None:
    logging.disable(logging.INFO)
    try:
        import rpyc as _rpyc
    except ImportError:
        print("rpyc not installed — pip install rpyc", file=sys.stderr)
        sys.exit(1)

    data = json.loads(_DATA_FILE.read_text())
    payload_bytes = len(json.dumps(data).encode())

    print(f"\nRPyC {_rpyc.__version__} vs daffi  —  {N} sequential rpc calls")
    print(f"host: {HOST}   warmup: {WARMUP}   payload: {_DATA_FILE.name} ({payload_bytes} bytes JSON)")
    print("daffi serde=PICKLE (object RPC peer)\n")

    print("── Direct (Client → Server/Service) ─────────────────────")
    print("  RPyC")
    rpyc_direct = _report("RPyC direct", bench_rpyc_direct(data))
    print("  daffi")
    daffi_direct = _report("daffi direct", bench_daffi_direct(data))

    print("\n── Via hop (Proxy / Router) ─────────────────────────────")
    print("  RPyC")
    rpyc_hop = _report("RPyC proxy", bench_rpyc_via_proxy(data))
    print("  daffi")
    daffi_hop = _report("daffi router", bench_daffi_via_router(data))

    print("\n── Summary (calls/s) ───────────────────────────────────")
    print(f"  {'layout':<10}  {'RPyC':>10}  {'daffi':>10}  {'daffi vs RPyC':>14}")
    print(f"  {'----------':<10}  {'----------':>10}  {'----------':>10}  {'--------------':>14}")
    print(
        f"  {'Direct':<10}  {rpyc_direct:>10.0f}  {daffi_direct:>10.0f}  "
        f"{daffi_direct / rpyc_direct:>13.2f}×"
    )
    print(
        f"  {'Via hop':<10}  {rpyc_hop:>10.0f}  {daffi_hop:>10.0f}  "
        f"{daffi_hop / rpyc_hop:>13.2f}×"
    )
    print()


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
