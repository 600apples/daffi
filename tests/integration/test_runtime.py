"""
The native runtime is fixed per process by the ``runtime`` argument,
so these tests run their scenario in a fresh interpreter.
"""

from __future__ import annotations

import subprocess
import sys
import textwrap

import pytest

# A Service started in the parent brings the event loops up; a child forked
# afterwards must start its own instead of using the parent's (which do not
# exist in the child). The child keeps the runtime the parent already locked.
_FORK_AFTER_LOOPS_STARTED = textwrap.dedent("""
    import multiprocessing as mp, socket, sys, time
    from daffi import Client, Service, callback, dfcore, TCPTransport

    dfcore.setRuntime("evented")
    assert dfcore.getRuntime() == "evented", dfcore.getRuntime()

    def free_port():
        with socket.socket() as s:
            s.bind(("127.0.0.1", 0))
            return s.getsockname()[1]

    @callback
    def where():
        return "served"

    def child(port):
        svc = Service(
            app_name="forked-service",
            transport=TCPTransport("127.0.0.1", port),
            runtime="evented",
        )
        svc.start()
        svc.join()

    parent_port, child_port = free_port(), free_port()
    parent_svc = Service(
        app_name="parent-service",
        transport=TCPTransport("127.0.0.1", parent_port),
        runtime="evented",
    )
    parent_svc.start()

    proc = mp.get_context("fork").Process(target=child, args=(child_port,), daemon=True)
    proc.start()
    try:
        for name, port in (("parent-service", parent_port), ("forked-service", child_port)):
            client = Client(
                app_name="caller-" + name,
                transport=TCPTransport("127.0.0.1", port),
                runtime="evented",
            )
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
    """)


def _run_fresh(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-c", textwrap.dedent(script)],
        capture_output=True,
        text=True,
        timeout=60,
    )


def test_constructor_locks_evented():
    result = _run_fresh(
        """
        from daffi import Client, Runtime, Service, TCPTransport, dfcore
        svc = Service(
            transport=TCPTransport("127.0.0.1", 1),
            runtime=Runtime.EVENTED,
        )
        client = Client(
            transport=TCPTransport("127.0.0.1", 1),
            runtime="evented",
        )
        assert svc.runtime is Runtime.EVENTED
        assert client.runtime is Runtime.EVENTED
        assert dfcore.getRuntime() == "evented"
        print("OK")
        """
    )
    assert result.returncode == 0 and "OK" in result.stdout, result.stdout + result.stderr


def test_omitted_runtime_is_evented():
    result = _run_fresh(
        """
        from daffi import Runtime, Service, TCPTransport, dfcore
        svc = Service(transport=TCPTransport("127.0.0.1", 1))
        assert svc.runtime is Runtime.EVENTED
        assert dfcore.getRuntime() == "evented"
        print("OK")
        """
    )
    assert result.returncode == 0 and "OK" in result.stdout, result.stdout + result.stderr


def test_constructor_must_match_earlier_node():
    conflict = _run_fresh(
        """
        from daffi import Client, Service, TCPTransport
        Service(transport=TCPTransport("127.0.0.1", 1), runtime="threads")
        Client(transport=TCPTransport("127.0.0.1", 1), runtime="evented")
        """
    )
    assert conflict.returncode != 0 and "already" in (conflict.stderr + conflict.stdout)


@pytest.mark.runtimes_self_managed  # locks evented itself, in a fresh interpreter
@pytest.mark.skipif(sys.platform == "win32", reason="fork is POSIX-only")
def test_evented_child_forked_after_loops_started():
    result = subprocess.run(
        [sys.executable, "-c", _FORK_AFTER_LOOPS_STARTED],
        capture_output=True,
        text=True,
        timeout=90,
    )
    assert result.returncode == 0 and "OK" in result.stdout, (
        result.stdout + result.stderr
    )
