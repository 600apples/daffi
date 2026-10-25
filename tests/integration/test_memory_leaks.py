"""
Steady-state memory / resource checks for the native core (short CI smoke).

Inspired by vast-csi ``test_library_memory_leaks.py``: run a load step
repeatedly and fail if Service RSS keeps climbing every round.

For a **multi-hour soak under huge load** with periodic RSS/CPU sampling
(vast-csi ``ResourceSampler`` style) and ``threads`` / ``evented`` selection,
use the standalone harness instead::

    python tests/perf/soak_leak_test.py                  # 3 h, both models
    python tests/perf/soak_leak_test.py --hours 3 --model evented
    python tests/perf/soak_leak_test.py --hours 0.1 --clients 32   # smoke

Run these short tests::

    pytest -m memleak tests/integration/test_memory_leaks.py -v -s
"""

from __future__ import annotations

import os
import subprocess
import sys
import textwrap

import pytest

from tests._resource_metrics import KiB, MiB

pytestmark = [
    pytest.mark.memleak,
    # Already parametrizes threads + evented via subprocesses; do not run twice
    # under --execution-model=both.
    pytest.mark.execution_models_self_managed,
    pytest.mark.skipif(sys.platform == "win32", reason="POSIX-only"),
]

MODELS = ("threads", "evented")


def _run_in_model(model: str, code: str, timeout: float = 180) -> subprocess.CompletedProcess:
    env = dict(os.environ, DAFFI_EXECUTION_MODEL=model)
    return subprocess.run(
        [sys.executable, "-c", code],
        env=env, capture_output=True, text=True, timeout=timeout,
    )


# ── connection churn: RSS must plateau ────────────────────────────────────────

_CHURN = textwrap.dedent(
    """
    import json, sys
    from tests._resource_metrics import scenario_connection_churn
    samples = scenario_connection_churn(rounds=8, clients_per_round=16)
    print("SAMPLES " + json.dumps(samples))
    """
)


@pytest.mark.parametrize("model", MODELS)
def test_service_rss_steady_under_connection_churn(model):
    """Connect/disconnect batches must not make Service RSS climb every round."""
    result = _run_in_model(model, _CHURN, timeout=240)
    assert result.returncode == 0, result.stdout + result.stderr
    line = next(l for l in result.stdout.splitlines() if l.startswith("SAMPLES "))
    import json
    samples = json.loads(line[len("SAMPLES "):])
    assert len(samples) >= 6

    # vast-csi style: last three round-to-round deltas must not all exceed tolerance.
    deltas = [samples[i] - samples[i - 1] for i in range(1, len(samples))]
    report = (
        f"{model} churn RSS KiB={samples}; deltas=["
        + ", ".join(f"{d:+d}" for d in deltas)
        + "]"
    )
    print(report)
    tolerance_kb = 2 * MiB // KiB  # 2 MiB
    tail = deltas[-3:]
    assert not all(d > tolerance_kb for d in tail), f"RSS keeps growing. {report}"


# ── sustained RPC on a fixed set of clients ───────────────────────────────────

_SUSTAINED = textwrap.dedent(
    """
    import json, multiprocessing as mp, time
    from tests._resource_metrics import (
        assert_rss_steady_state, free_port, proc_service, rss_kb,
        stop, wait_for_port, _connect_clients, _rpc_burst, _stop_clients,
    )

    port = free_port()
    svc = mp.Process(target=proc_service, args=(port,), daemon=True)
    svc.start()
    try:
        wait_for_port(port)
        time.sleep(0.3)
        clients, conns = _connect_clients(port, 24, "res-service")

        def step():
            _rpc_burst(conns, calls_per_client=80)

        def measure():
            return rss_kb(svc.pid) or 0

        deltas = assert_rss_steady_state(
            step, measure, label="sustained RPC", warmup=2, rounds=6,
            tolerance_kb=2 * 1024,  # 2 MiB
        )
        _stop_clients(clients)
        print("OK " + json.dumps(deltas))
    finally:
        stop(svc)
    """
)


@pytest.mark.parametrize("model", MODELS)
def test_service_rss_steady_under_sustained_rpc(model):
    """Fixed client set firing RPCs: Service RSS must not ratchet upward."""
    result = _run_in_model(model, _SUSTAINED, timeout=300)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "OK " in result.stdout


# ── threads vs evented snapshot (informational + sanity bounds) ───────────────

_COMPARE = textwrap.dedent(
    """
    import json
    from tests._resource_metrics import scenario_many_clients, scenario_router
    from daffi import dfcore

    many = scenario_many_clients(n_clients=48, calls_per_client=100, sample_s=0.8)
    router = scenario_router(n_clients=24, calls_per_client=100, sample_s=0.8)
    print("RESULT " + json.dumps({
        "model": dfcore.getExecutionModel(),
        "many_clients": {
            "idle_rss_kb": many.idle.rss_kb,
            "load_rss_kb": many.under_load.rss_kb,
            "idle_threads": many.idle.threads,
            "load_threads": many.under_load.threads,
            "load_cpu_pct": many.under_load.cpu_pct,
        },
        "router": {
            "idle_rss_kb": router.idle.rss_kb,
            "load_rss_kb": router.under_load.rss_kb,
            "idle_threads": router.idle.threads,
            "load_threads": router.under_load.threads,
            "load_cpu_pct": router.under_load.cpu_pct,
        },
    }))
    """
)


def test_compare_threads_vs_evented_resources():
    """Print RSS/CPU/threads for both models; assert evented stays flatter on threads."""
    import json

    by_model = {}
    for model in MODELS:
        result = _run_in_model(model, _COMPARE, timeout=300)
        assert result.returncode == 0, result.stdout + result.stderr
        line = next(l for l in result.stdout.splitlines() if l.startswith("RESULT "))
        by_model[model] = json.loads(line[len("RESULT "):])

    t, e = by_model["threads"], by_model["evented"]

    def row(label, a, b, fmt="{:,}"):
        print(f"  {label:<36}{fmt.format(a):>12}{fmt.format(b):>12}")

    print("\n  resource snapshot (pytest -s)")
    print(f"  {'metric':<36}{'threads':>12}{'evented':>12}")
    print("  " + "-" * 60)
    for key, title in (("many_clients", "many_clients/Service"), ("router", "router")):
        print(f"  --- {title} ---")
        row("idle RSS KiB", t[key]["idle_rss_kb"], e[key]["idle_rss_kb"])
        row("load RSS KiB", t[key]["load_rss_kb"], e[key]["load_rss_kb"])
        row("idle native threads", t[key]["idle_threads"], e[key]["idle_threads"])
        row("load native threads", t[key]["load_threads"], e[key]["load_threads"])
        if t[key]["load_cpu_pct"] is not None:
            row("load CPU% (1 core)", t[key]["load_cpu_pct"], e[key]["load_cpu_pct"], "{:.0f}")

    # Soft sanity: under many clients, evented must not grow one-thread-per-conn.
    assert e["many_clients"]["load_threads"] < t["many_clients"]["load_threads"]
    assert e["many_clients"]["load_threads"] < 32  # fixed loop pool, not 48+
    # Neither model should be absurdly large for this smoke load.
    for model, data in by_model.items():
        assert data["many_clients"]["load_rss_kb"] < 512 * KiB, f"{model} Service RSS too high"
        assert data["router"]["load_rss_kb"] < 512 * KiB, f"{model} Router RSS too high"
