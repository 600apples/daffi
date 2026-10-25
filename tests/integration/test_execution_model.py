"""
The native execution model is fixed per process by ``DAFFI_EXECUTION_MODEL``,
so these tests run their scenario in a fresh interpreter.
"""
from __future__ import annotations

import os
import subprocess
import sys
import textwrap

import pytest

# A Service started in the parent brings the event loops up; a child forked
# afterwards must start its own instead of using the parent's (which do not
# exist in the child).
_FORK_AFTER_LOOPS_STARTED = textwrap.dedent(
    """
    import multiprocessing as mp, socket, sys, time
    from daffi import Client, Service, callback, dfcore

    assert dfcore.getExecutionModel() == "evented", dfcore.getExecutionModel()

    def free_port():
        with socket.socket() as s:
            s.bind(("127.0.0.1", 0))
            return s.getsockname()[1]

    @callback
    def where():
        return "served"

    def child(port):
        svc = Service(app_name="forked-service", host="127.0.0.1", port=port)
        svc.start()
        svc.join()

    parent_port, child_port = free_port(), free_port()
    parent_svc = Service(app_name="parent-service", host="127.0.0.1", port=parent_port)
    parent_svc.start()

    proc = mp.get_context("fork").Process(target=child, args=(child_port,), daemon=True)
    proc.start()
    try:
        for name, port in (("parent-service", parent_port), ("forked-service", child_port)):
            client = Client(app_name="caller-" + name, host="127.0.0.1", port=port)
            deadline = time.monotonic() + 15
            while True:
                try:
                    conn = client.connect()
                    break
                except Exception:
                    if time.monotonic() > deadline:
                        raise
                    time.sleep(0.1)
            conn.wait_for_members(name, timeout=10)
            assert conn.rpc(timeout=10).where() == "served"
            client.stop()
    finally:
        proc.terminate()
        proc.join(5)
        parent_svc.stop()
    print("OK")
    """
)


@pytest.mark.execution_models_self_managed  # forces evented in its own subprocess
@pytest.mark.skipif(sys.platform == "win32", reason="fork is POSIX-only")
def test_evented_child_forked_after_loops_started():
    env = dict(os.environ, DAFFI_EXECUTION_MODEL="evented")
    result = subprocess.run(
        [sys.executable, "-c", _FORK_AFTER_LOOPS_STARTED],
        env=env, capture_output=True, text=True, timeout=90,
    )
    assert result.returncode == 0 and "OK" in result.stdout, result.stdout + result.stderr
