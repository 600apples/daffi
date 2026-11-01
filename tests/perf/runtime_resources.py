"""
Compare memory (RSS) and CPU for daffi ``threads`` vs ``evented``.

Each model runs in a fresh interpreter. That interpreter locks the
runtime and passes the same value into the Service, Router, and workers.

Scenarios
---------
1. many_clients — N clients → Service (measure Service)
2. router       — N clients → Router → worker (measure Router)

Run::

    python tests/perf/runtime_resources.py
    python tests/perf/runtime_resources.py --clients 64 --calls 300

Which model runs first is chosen at random.
"""

from __future__ import annotations

import argparse
import json
import logging
import random
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests._resource_metrics import (  # noqa: E402
    KiB,
    ScenarioResult,
    scenario_many_clients,
    scenario_router,
)

MODELS = ("threads", "evented")


def _run_worker(calls: int, clients: int, sample_s: float) -> dict:
    logging.disable(logging.CRITICAL)
    from daffi import dfcore

    model = dfcore.getRuntime()
    many = scenario_many_clients(
        n_clients=clients, calls_per_client=calls, sample_s=sample_s
    )
    router = scenario_router(
        n_clients=max(8, clients // 2),
        calls_per_client=calls,
        sample_s=sample_s,
    )
    return {
        "model": model,
        "many_clients": _pack(many),
        "router": _pack(router),
    }


def _pack(r: ScenarioResult) -> dict:
    def s(sample):
        return {
            "rss_kb": sample.rss_kb,
            "threads": sample.threads,
            "cpu_pct": sample.cpu_pct,
        }

    return {
        "target": r.target,
        "idle": s(r.idle),
        "under_load": s(r.under_load),
        "after": s(r.after),
    }


def _fmt_rss(kb: int) -> str:
    return f"{kb / KiB:.1f} MiB"


def _fmt_cpu(pct) -> str:
    return "n/a" if pct is None else f"{pct:.0f}%"


def _cmp_rss(a_kb: int, b_kb: int) -> str:
    """Lower RSS wins → phrased as 'evented lighter +X%' / 'threads lighter +X%'."""
    if not a_kb or not b_kb:
        return "n/a"
    if b_kb <= a_kb:
        return f"evented lighter +{(a_kb - b_kb) / a_kb * 100:.1f}%"
    return f"threads lighter +{(b_kb - a_kb) / b_kb * 100:.1f}%"


def _cmp_cpu(a, b) -> str:
    if a is None or b is None or not a:
        return ""
    if b <= a:
        return f"evented lower +{(a - b) / a * 100:.1f}%"
    return f"threads lower +{(b - a) / b * 100:.1f}%"


def _print_table(results: dict) -> None:
    t, e = results["threads"], results["evented"]

    print("\n  RSS / CPU / native threads — threads vs evented")
    print("  (RSS of the Service or Router process; CPU% is of one core, Linux only)\n")

    header = f"  {'metric':<42}{'threads':>14}{'evented':>14}   comparison"
    print(header)
    print("  " + "-" * 90)

    for key, title in (
        ("many_clients", "many_clients → Service"),
        ("router", "clients → Router"),
    ):
        tt, ee = t[key], e[key]
        print(f"  --- {title} (target={tt['target']}) ---")
        for phase in ("idle", "under_load", "after"):
            a, b = tt[phase], ee[phase]
            print(
                f"  {phase + ' RSS':<42}"
                f"{_fmt_rss(a['rss_kb']):>14}{_fmt_rss(b['rss_kb']):>14}"
                f"   {_cmp_rss(a['rss_kb'], b['rss_kb'])}"
            )
            print(
                f"  {phase + ' CPU%':<42}"
                f"{_fmt_cpu(a['cpu_pct']):>14}{_fmt_cpu(b['cpu_pct']):>14}"
                f"   {_cmp_cpu(a['cpu_pct'], b['cpu_pct'])}"
            )
            print(
                f"  {phase + ' native threads':<42}"
                f"{a['threads']:>14}{b['threads']:>14}"
            )
        print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--clients", type=int, default=64, help="clients for many_clients scenario"
    )
    parser.add_argument(
        "--calls", type=int, default=200, help="RPC calls per client under load"
    )
    parser.add_argument(
        "--sample", type=float, default=1.0, help="CPU sample window seconds"
    )
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--runtime", choices=MODELS, help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.worker:
        if args.runtime is None:
            sys.exit("--runtime is required in worker mode")
        import tests.conftest as _runtime_state
        from daffi import dfcore

        _runtime_state.SELECTED_RUNTIME = args.runtime
        dfcore.setRuntime(args.runtime)
        print(
            "RESULT " + json.dumps(_run_worker(args.calls, args.clients, args.sample))
        )
        return

    order = list(MODELS)
    random.shuffle(order)
    print(f"model order: {' then '.join(order)}", flush=True)
    results = {}
    for model in order:
        print(f"running {model} model…", flush=True)
        proc = subprocess.run(
            [
                sys.executable,
                __file__,
                "--worker",
                "--runtime",
                model,
                "--clients",
                str(args.clients),
                "--calls",
                str(args.calls),
                "--sample",
                str(args.sample),
            ],
            capture_output=True,
            text=True,
            cwd=str(ROOT),
        )
        line = next(
            (l for l in proc.stdout.splitlines() if l.startswith("RESULT ")), None
        )
        if line is None:
            sys.exit(f"{model} run failed:\n{proc.stdout}\n{proc.stderr}")
        result = json.loads(line[len("RESULT ") :])
        assert result["model"] == model, f"expected {model}, got {result['model']}"
        results[model] = result
    _print_table(results)


if __name__ == "__main__":
    main()
