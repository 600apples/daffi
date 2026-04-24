"""
Root pytest configuration for the daffi test suite.

Adds the project root to sys.path so ``import daffi`` works even when
the package is not installed into the active Python environment.
"""
import sys
from pathlib import Path

# Ensure the project root is importable by all test processes.
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# When pytest is run with the system Python instead of the project .venv
# (e.g. `python3 -m pytest` vs `.venv/bin/pytest`), optional dependencies
# like dill and tblib are only available inside the .venv.  Add the .venv
# site-packages here — before any daffi module is imported — so that forked
# subprocesses inherit the full package environment.
for _sp in sorted(ROOT.glob(".venv/lib/python*/site-packages"), reverse=True):
    if str(_sp) not in sys.path:
        sys.path.insert(0, str(_sp))
