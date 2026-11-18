"""
Zero (zeroapi) vs daffi — sequential unary RPC on the same payload.

Layout
------
Direct — Client → Server on loopback TCP.

Zero uses ZeroMQ + msgspec msgpack under the hood (default protocol).
daffi baseline uses ``SerdeFormat.MSGPACK`` so both sides pay a structured
encode/decode on the same ``data.json`` object (~2 KB).

Requires::

    pip install pyzmq msgspec
    # and either ``pip install zeroapi`` or a checkout of
    # https://github.com/Ananto30/zero on PYTHONPATH / ZERO_PATH

Run::

    python3 tests/perf/zero_benchmark.py

``BENCH_N`` overrides the call count (default 100000).
``ZERO_PATH`` points at a local zero checkout (default: common local path).
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
_DEFAULT_ZERO = Path("/home/fnn45/pCloudDrive/Python LIBS/zero")

N = int(os.environ.get("BENCH_N", "100000"))
WARMUP = 20
TIMEOUT = 30
HOST = "127.0.0.1"


def _ensure_zero() -> str:
    """Prefer an installed ``zero`` package; else add ZERO_PATH / local checkout.

    Returns the checkout root to pass into the server child (empty if installed).
    Appends the path so daffi's ``tests`` package is not shadowed by zero's.
    """
    try:
        import zero  # noqa: F401

        return ""
    except ImportError:
        pass
    root = Path(os.environ.get("ZERO_PATH", _DEFAULT_ZERO)).resolve()
    if not (root / "zero").is_dir():
        raise SystemExit(
            "zero (zeroapi) not found — pip install zeroapi, or set ZERO_PATH "
            "to a checkout of https://github.com/Ananto30/zero "
            f"(tried {root})"
        )
    root_s = str(root)
    if root_s not in sys.path:
        sys.path.append(root_s)
    import zero  # noqa: F401

    return root_s


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


# ── Zero (zeroapi) ────────────────────────────────────────────────────────────


def _proc_zero(port: int, zero_root: str) -> None:
    # Append only — spawn children re-import this module and need daffi's tests/.
    if zero_root and zero_root not in sys.path:
        sys.path.append(zero_root)
    _silence()
    from zero import ZeroServer

    app = ZeroServer(host=HOST, port=port, use_threads=True)

    @app.register_rpc
    def echo(msg: dict) -> dict:
        return msg

    # workers=1: fair sequential peer (Zero defaults to all cores).
    app.run(workers=1)


def bench_zero(data: dict, zero_root: str) -> list[float]:
    from zero import ZeroClient

    port = _free_port()
    proc = mp.Process(target=_proc_zero, args=(port, zero_root), daemon=True)
    proc.start()
    try:
        deadline = time.monotonic() + 15.0
        client = None
        last_err: Exception | None = None
        while time.monotonic() < deadline:
            try:
                client = ZeroClient(HOST, port, default_timeout=TIMEOUT * 1000)
                got = client.call("echo", data)
                if got != data:
                    raise SystemExit("Zero echo returned a different payload")
                break
            except Exception as exc:  # noqa: BLE001 — probe until broker is up
                last_err = exc
                if client is not None:
                    try:
                        client.close()
                    except Exception:
                        pass
                    client = None
                time.sleep(0.05)
        else:
            raise TimeoutError(f"Zero server not ready: {last_err!r}")

        assert client is not None
        try:
            return _measure("zero", lambda: client.call("echo", data))
        finally:
            client.close()
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

    svc = Service(
        app_name="zero-cmp-svc",
        transport=TCPTransport(HOST, port),
        runtime=runtime,
        workers=1,
    )
    svc.start()
    svc.join()


def bench_daffi_msgpack(data: dict) -> list[float]:
    from daffi import Client, TCPTransport
    from daffi._serialization import SerdeFormat

    port = _free_port()
    proc = mp.Process(target=_proc_daffi, args=(active_runtime(), port), daemon=True)
    proc.start()
    try:
        _wait_for_port(port)
        time.sleep(0.15)
        client = Client(
            app_name="zero-cmp-cli",
            transport=TCPTransport(HOST, port),
            runtime=active_runtime(),
        )
        c = client.connect().rpc(timeout=TIMEOUT, serde=SerdeFormat.MSGPACK)
        try:
            return _measure("daffi-msgpack", lambda: c.echo(data))
        finally:
            client.stop()
    finally:
        proc.terminate()
        proc.join(timeout=5)


def main() -> None:
    logging.disable(logging.INFO)
    zero_root = _ensure_zero()
    try:
        import msgspec  # noqa: F401
        import zmq  # noqa: F401
    except ImportError:
        print("need pyzmq and msgspec — pip install pyzmq msgspec", file=sys.stderr)
        sys.exit(1)

    import zero

    data = json.loads(_DATA_FILE.read_text())
    payload_bytes = len(json.dumps(data).encode())
    ver = getattr(zero, "__version__", None)
    if ver is None:
        # Local checkout / package without __version__
        ver = "checkout"

    print(f"\nZero (zeroapi) {ver} vs daffi  —  {N} sequential rpc calls")
    print(
        f"host: {HOST}   warmup: {WARMUP}   payload: {_DATA_FILE.name} ({payload_bytes} bytes JSON)"
    )
    print("layout: Direct; Zero=ZMQ+msgspec; daffi serde=MSGPACK; workers=1\n")

    print("── Zero ─────────────────────────────────────────────────")
    zero_rate = _report("Zero", bench_zero(data, zero_root))

    print("\n── daffi (MSGPACK) ─────────────────────────────────────")
    daffi_rate = _report("daffi MSGPACK", bench_daffi_msgpack(data))

    print("\n── Summary (calls/s) ───────────────────────────────────")
    print(f"  {'stack':<16}  {'calls/s':>10}")
    print(f"  {'----------------':<16}  {'----------':>10}")
    print(f"  {'Zero':<16}  {zero_rate:>10.0f}")
    print(f"  {'daffi MSGPACK':<16}  {daffi_rate:>10.0f}")
    if zero_rate > 0:
        print(f"\n  daffi vs Zero: {daffi_rate / zero_rate:.2f}×\n")


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(1)
