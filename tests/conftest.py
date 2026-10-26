"""
Root pytest configuration for the daffi test suite.

Adds the project root to sys.path so ``import daffi`` works even when
the package is not installed into the active Python environment.

Runtime matrix
--------------
The native runtime is chosen by the ``runtime`` argument and then locked
for the process.  The suite cannot switch ``threads`` ↔ ``evented``
mid-session.  Use::

    pytest --runtime=both          # default: two fresh runs
    pytest --runtime=threads       # single runtime
    pytest --runtime=evented

``both`` re-invokes pytest once per runtime in a fresh interpreter.
The ``runtime`` fixture locks that choice.  ``active_runtime()`` reads it
back for subprocess arguments.
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
        "--runtime",
        action="store",
        default="both",
        choices=("threads", "evented", "both"),
        help=(
            "Native runtime to pass to every node. "
            "'both' (default) runs the suite twice in fresh interpreters "
            "(threads, then evented). Use a single runtime for a faster loop."
        ),
    )


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line(
        "markers",
        "runtimes_self_managed: test/module already covers threads+evented; "
        "only collected under --runtime=threads (or a single-model run)",
    )
    config.addinivalue_line(
        "markers",
        "memleak: steady-state RSS / resource checks (slower; run with -m memleak)",
    )


# ── both → two fresh pytest processes ─────────────────────────────────────────


def _strip_runtime_args(argv: list[str]) -> list[str]:
    out: list[str] = []
    skip = False
    for arg in argv:
        if skip:
            skip = False
            continue
        if arg == "--runtime":
            skip = True
            continue
        if arg.startswith("--runtime="):
            continue
        out.append(arg)
    return out


@pytest.hookimpl(tryfirst=True)
def pytest_cmdline_main(config: pytest.Config):
    """When ``--runtime=both``, run pytest twice in clean subprocesses."""
    model = config.getoption("--runtime")
    if model != "both":
        return None
    if os.environ.get(_RUNNER_ENV) == "1":
        # Nested invocation should always pass a concrete model; belt-and-suspenders.
        return None
    # Discovery-only modes: do not double-invoke.
    if config.option.collectonly or getattr(config.option, "showfixtures", False):
        return None

    filtered = _strip_runtime_args(sys.argv[1:])
    rc = 0
    for m in _EXEC_MODELS:
        print(f"\n{'=' * 70}\n  runtime={m}\n{'=' * 70}\n", flush=True)
        env = os.environ.copy()
        env[_RUNNER_ENV] = "1"
        proc = subprocess.run(
            [sys.executable, "-m", "pytest", *filtered, f"--runtime={m}"],
            env=env,
            cwd=str(ROOT),
        )
        if proc.returncode and rc == 0:
            rc = proc.returncode
    return rc


# ── session fixture + collection tweaks ───────────────────────────────────────

# Set by the ``runtime`` fixture. Not on the tests package: a script run as
# ``python tests/perf/...`` must not need ``tests/__init__.py`` to import.
SELECTED_RUNTIME = "evented"


def active_runtime() -> str:
    """Runtime locked for this interpreter by the ``runtime`` fixture."""
    return SELECTED_RUNTIME


@pytest.fixture(scope="session", autouse=True)
def runtime(pytestconfig: pytest.Config) -> str:
    """Lock this interpreter to the ``--runtime`` choice before any node starts.

    Spawned children do not inherit that lock.  Their entry points take the
    same value as a ``runtime`` argument.  ``active_runtime()`` reports the
    value stored here.
    """
    global SELECTED_RUNTIME
    from daffi import dfcore

    model = pytestconfig.getoption("--runtime")
    if model == "both":
        model = "threads"
    assert model in _EXEC_MODELS, model
    SELECTED_RUNTIME = model
    dfcore.setRuntime(model)
    print(f"\n[daffi] runtime={model}\n", flush=True)
    return model


def pytest_collection_modifyitems(
    config: pytest.Config, items: list[pytest.Item]
) -> None:
    """Drop self-managed matrix tests from the evented pass (they already cover both)."""
    model = config.getoption("--runtime")
    if model not in _EXEC_MODELS:
        return
    if model == "threads":
        return
    keep: list[pytest.Item] = []
    for item in items:
        if item.get_closest_marker("runtimes_self_managed"):
            item.add_marker(
                pytest.mark.skip(
                    reason="self-managed threads+evented matrix; runs under --runtime=threads only"
                )
            )
        keep.append(item)
    items[:] = keep


def pytest_report_header(config: pytest.Config) -> list[str]:
    model = config.getoption("--runtime")
    return [f"daffi runtime: {model}"]
