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
