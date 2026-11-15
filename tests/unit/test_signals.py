"""
Ctrl+C after daffi: it stops live applications, and otherwise behaves as
without daffi.

Regressions: the SIGINT handler was never uninstalled and always swallowed
the signal, so once every application had stopped, or in a forked child,
Ctrl+C did nothing at all.  Dead applications stayed in the handler list.
"""

from __future__ import annotations

import gc
import os
import subprocess
import sys
from pathlib import Path

import pytest

from tests.conftest import active_runtime

ROOT = Path(__file__).resolve().parents[2]

_PRELUDE = f"""
import os, signal, sys, time
# As in an interactive start; a background job inherits SIGINT ignored.
signal.signal(signal.SIGINT, signal.default_int_handler)
from daffi import Client, TCPTransport, dfcore
from daffi import _signals
dfcore.setRuntime({{runtime!r}})

def ctrl_c():
    try:
        os.kill(os.getpid(), signal.SIGINT)
        time.sleep(2)
        return "swallowed"
    except KeyboardInterrupt:
        return "interrupted"

def client(name):
    return Client(app_name=name, transport=TCPTransport("127.0.0.1", 1), runtime={{runtime!r}})
"""


def _run(body: str) -> str:
    source = _PRELUDE.format(runtime=active_runtime()) + body
    proc = subprocess.run(
        [sys.executable, "-c", source],
        cwd=str(ROOT),
        env=dict(os.environ, PYTHONPATH=str(ROOT)),
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
    return proc.stdout


def test_a_live_application_takes_ctrl_c():
    out = _run("""
c = client("live")
stopped = []
c.stop = lambda *a, **k: stopped.append(True)
print(ctrl_c(), "stopped" if stopped else "not stopped")
""")
    assert out.split() == ["swallowed", "stopped"]


def test_ctrl_c_interrupts_once_every_application_stopped():
    out = _run("""
a, b = client("a"), client("b")
a.stop()
print("one-left", signal.getsignal(signal.SIGINT) is _signals._on_signal)
b.stop()
print("none-left", signal.getsignal(signal.SIGINT) is signal.default_int_handler)
print(ctrl_c())
""")
    assert out.split() == ["one-left", "True", "none-left", "True", "interrupted"]


def test_ctrl_c_is_handed_on_when_the_handler_cannot_be_restored():
    """stop() off the main thread cannot reinstall the old handler; the
    installed one must then delegate instead of swallowing."""
    out = _run("""
import threading
c = client("off-main")
t = threading.Thread(target=c.stop)
t.start(); t.join()
print(signal.getsignal(signal.SIGINT) is _signals._on_signal, ctrl_c())
""")
    assert out.split() == ["True", "interrupted"]


def test_starting_again_takes_ctrl_c_again():
    out = _run("""
c = client("again")
c.stop()
c._intentionally_stopped = False   # what start() / connect() do
stopped = []
c.stop = lambda *a, **k: stopped.append(True)
print(ctrl_c(), bool(stopped))
""")
    assert out.split() == ["swallowed", "True"]


def test_a_handler_installed_later_is_left_alone():
    out = _run("""
c = client("user-handler")
mine = lambda signum, frame: print("mine")
signal.signal(signal.SIGINT, mine)
c.stop()
print(signal.getsignal(signal.SIGINT) is mine)
""")
    assert out.split() == ["True"]


@pytest.mark.skipif(not hasattr(os, "fork"), reason="fork is POSIX-only")
def test_a_forked_child_gets_ctrl_c_back():
    out = _run("""
c = client("parent")
pid = os.fork()
if pid == 0:
    result = ctrl_c()
    os._exit(0 if result == "interrupted" else 1)
_, status = os.waitpid(pid, 0)
print("child", os.waitstatus_to_exitcode(status))
""")
    assert out.split() == ["child", "0"]


def test_dead_applications_are_pruned():
    from daffi import _signals

    class _App:
        def stop(self):
            pass

    first, second = _App(), _App()
    _signals.set_signal_handler(first.stop)
    del first
    gc.collect()
    _signals.set_signal_handler(second.stop)
    _signals.set_signal_handler(second.stop)
    try:
        assert all(ref() is not None for ref in _signals._handlers)
        assert sum(ref() == second.stop for ref in _signals._handlers) == 1
    finally:
        _signals.release_signal_handler(second.stop)
