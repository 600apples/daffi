"""
Root pytest configuration for the daffi test suite.

Adds the project root to sys.path so ``import daffi`` works even when
the package is not installed into the active Python environment.

Execution-model matrix
----------------------
The native core locks ``DAFFI_EXECUTION_MODEL`` once per process, so the suite
cannot switch ``threads`` ↔ ``evented`` mid-session.  Use::

    pytest --execution-model=both          # default for integration: two fresh runs
    pytest --execution-model=threads       # single model
    pytest --execution-model=evented

``both`` re-invokes pytest once per model in a subprocess (fresh interpreter,
correct lock).  A session-scoped autouse fixture sets the env var and prints
which model is active.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

# Ensure the project root is importable by all test processes.
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# When pytest is run with the system Python instead of the project .venv
# (e.g. `python3 -m pytest` vs `.venv/bin/pytest`), optional dependencies
# like tblib are only available inside the .venv.  Add the .venv
# site-packages here — before any daffi module is imported — so that forked
# subprocesses inherit the full package environment.
for _sp in sorted(ROOT.glob(".venv/lib/python*/site-packages"), reverse=True):
    if str(_sp) not in sys.path:
        sys.path.insert(0, str(_sp))

_EXEC_MODELS = ("threads", "evented")
_RUNNER_ENV = "_DAFFI_EXEC_MODEL_RUNNER"


# ── CLI ───────────────────────────────────────────────────────────────────────

def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("daffi")
    group.addoption(
        "--execution-model",
        action="store",
        default="both",
        choices=("threads", "evented", "both"),
        help=(
            "Native DAFFI_EXECUTION_MODEL to run against. "
            "'both' (default) runs the suite twice in fresh interpreters "
            "(threads, then evented). Use a single model for a faster loop."
        ),
    )


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line(
        "markers",
        "execution_models_self_managed: test/module already covers threads+evented; "
        "only collected under --execution-model=threads (or a single-model run)",
    )
    config.addinivalue_line(
        "markers",
        "memleak: steady-state RSS / resource checks (slower; run with -m memleak)",
    )


# ── both → two fresh pytest processes ─────────────────────────────────────────

def _strip_execution_model_args(argv: list[str]) -> list[str]:
    out: list[str] = []
    skip = False
    for arg in argv:
        if skip:
            skip = False
            continue
        if arg == "--execution-model":
            skip = True
            continue
        if arg.startswith("--execution-model="):
            continue
        out.append(arg)
    return out


@pytest.hookimpl(tryfirst=True)
def pytest_cmdline_main(config: pytest.Config):
    """When ``--execution-model=both``, run pytest twice in clean subprocesses."""
    model = config.getoption("--execution-model")
    if model != "both":
        return None
    if os.environ.get(_RUNNER_ENV) == "1":
        # Nested invocation should always pass a concrete model; belt-and-suspenders.
        return None
    # Discovery-only modes: do not double-invoke.
    if config.option.collectonly or getattr(config.option, "showfixtures", False):
        os.environ.setdefault("DAFFI_EXECUTION_MODEL", "threads")
        return None

    filtered = _strip_execution_model_args(sys.argv[1:])
    rc = 0
    for m in _EXEC_MODELS:
        print(f"\n{'=' * 70}\n  DAFFI_EXECUTION_MODEL={m}\n{'=' * 70}\n", flush=True)
        env = os.environ.copy()
        env[_RUNNER_ENV] = "1"
        env["DAFFI_EXECUTION_MODEL"] = m
        proc = subprocess.run(
            [sys.executable, "-m", "pytest", *filtered, f"--execution-model={m}"],
            env=env,
            cwd=str(ROOT),
        )
        if proc.returncode and rc == 0:
            rc = proc.returncode
    return rc


# ── session fixture + collection tweaks ───────────────────────────────────────

@pytest.fixture(scope="session", autouse=True)
def execution_model(pytestconfig: pytest.Config) -> str:
    """Pin ``DAFFI_EXECUTION_MODEL`` for this interpreter before any native node starts.

    Spawned Service/Router/Client children inherit the same value.
    """
    model = pytestconfig.getoption("--execution-model")
    if model == "both":
        # Should not happen: cmdline_main consumes ``both``. Fallback for safety.
        model = os.environ.get("DAFFI_EXECUTION_MODEL", "threads")
    assert model in _EXEC_MODELS, model
    os.environ["DAFFI_EXECUTION_MODEL"] = model
    print(f"\n[daffi] execution_model={model}\n", flush=True)
    return model


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Drop self-managed matrix tests from the evented pass (they already cover both)."""
    model = config.getoption("--execution-model")
    if model not in _EXEC_MODELS:
        return
    if model == "threads":
        return
    keep: list[pytest.Item] = []
    for item in items:
        if item.get_closest_marker("execution_models_self_managed"):
            item.add_marker(
                pytest.mark.skip(
                    reason="self-managed threads+evented matrix; runs under --execution-model=threads only"
                )
            )
        keep.append(item)
    items[:] = keep


def pytest_report_header(config: pytest.Config) -> list[str]:
    model = config.getoption("--execution-model")
    env_model = os.environ.get("DAFFI_EXECUTION_MODEL", "<unset>")
    return [f"daffi execution-model: option={model}  env={env_model}"]
