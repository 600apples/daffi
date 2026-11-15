"""
End-to-end regression tests for the fourth review round (sync layer).

Each test fails on the behaviour that used to happen:

* ``cast()`` to two or more peers waited on executor threads, so an inline
  callback that cast to peers of the same process froze the shared poller
  and nobody answered;
* ``wait_for_members()`` from an inline callback slept on the poller, the
  only thread that refreshes the member list, and never returned;
* one peer that left between the member lookup and the send aborted the
  whole ``cast()`` instead of being reported for that peer;
* a disconnect while ``Client.join()`` was parked stopped the client, so
  ``join()`` could not reconnect as documented;
* ``connect()`` failing after the native connection was made (out of file
  descriptors) left it open and the client "already connected".
"""

from __future__ import annotations

import errno
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest

from tests.conftest import active_runtime

from .conftest import HOST

ROOT = Path(__file__).resolve().parents[2]


def _run_script(source: str, timeout: float = 60) -> tuple[int, str]:
    env = dict(os.environ, PYTHONPATH=str(ROOT))
    proc = subprocess.Popen(
        [sys.executable, "-c", source],
        cwd=str(ROOT),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        out, err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
        pytest.fail(f"script did not exit within {timeout}s\n{out}\n{err}")
    return proc.returncode, out + err


def _mesh_script(port: int, body: str) -> str:
    """A Router and clients A, B, C, D in one process; *body* runs on D."""
    rt = active_runtime()
    return f"""
import threading, time
from daffi import Client, Router, TCPTransport, callback, dfcore
dfcore.setRuntime({rt!r})
conns = {{}}

@callback
def leaf():
    return "leaf"

@callback
def fan():
    return conns["A"].cast(timeout=10, receiver=["B", "C"]).leaf()

@callback
def await_member(name):
    conns["A"].wait_for_members(name, timeout=10)
    return "seen"

router = Router(transport=TCPTransport("127.0.0.1", {port}), runtime={rt!r})
router.start()
clients = []
def join_mesh(name):
    client = Client(app_name=name, transport=TCPTransport("127.0.0.1", {port}), runtime={rt!r})
    conns[name] = client.connect()
    clients.append(client)
for name in ("A", "B", "C", "D"):
    join_mesh(name)
conns["D"].wait_for_members("A", "B", "C", timeout=10)
{body}
for client in clients:
    client.stop()
router.stop()
"""


class TestCallbacksThatWait:
    def test_cast_from_a_callback_to_peers_of_the_same_process(self, free_port):
        code, output = _run_script(
            _mesh_script(
                free_port,
                """
started = time.monotonic()
result = conns["D"].rpc(timeout=30, receiver="A").fan()
print("took", round(time.monotonic() - started, 2), flush=True)
print("result", sorted(result.items()), flush=True)
""",
            )
        )
        assert code == 0, output
        assert "result [('B', 'leaf'), ('C', 'leaf')]" in output, output
        assert float(output.split("took ")[1].split()[0]) < 5, output

    def test_wait_for_members_from_a_callback(self, free_port):
        code, output = _run_script(
            _mesh_script(
                free_port,
                """
answer = []
caller = threading.Thread(
    target=lambda: answer.append(conns["D"].rpc(timeout=30, receiver="A").await_member("late"))
)
caller.start()
time.sleep(0.5)
join_mesh("late")
caller.join(30)
print("answer", answer, flush=True)
""",
            )
        )
        assert code == 0, output
        assert "answer ['seen']" in output, output


def test_cast_reports_a_missing_peer_and_still_calls_the_others(free_port):
    code, output = _run_script(
        _mesh_script(
            free_port,
            """
result = conns["D"].cast(timeout=10, receiver=["B", "nobody", "C"]).leaf()
print("B", result["B"], "C", result["C"], flush=True)
print("nobody", type(result["nobody"]).__name__, "ReceiverNotFound" in str(result["nobody"]), flush=True)
""",
        )
    )
    assert code == 0, output
    assert "B leaf C leaf" in output, output
    assert "nobody TransmissionFailure True" in output, output


def test_join_reconnects_after_a_disconnect(free_port):
    """The router goes away while join() is parked and comes back."""
    from daffi import Client, Router, TCPTransport

    router = Router(transport=TCPTransport(HOST, free_port), runtime=active_runtime())
    router.start()
    client = Client(
        app_name="rejoiner",
        transport=TCPTransport(HOST, free_port),
        runtime=active_runtime(),
    )
    client.connect()
    back = threading.Event()
    real_reconnect = client._try_reconnect

    def reconnect_once_the_router_is_back():
        back.wait(15)
        return real_reconnect()

    client._try_reconnect = reconnect_once_the_router_is_back
    outcome: list = []

    def _join():
        try:
            client.join()
            outcome.append("returned")
        except BaseException as exc:  # noqa: BLE001 — reported below
            outcome.append(exc)

    joiner = threading.Thread(target=_join, daemon=True)
    joiner.start()
    router2 = None
    try:
        deadline = time.monotonic() + 5
        while not client._joining and time.monotonic() < deadline:
            time.sleep(0.01)
        router.stop()
        deadline = time.monotonic() + 10
        while not client._disconnected and time.monotonic() < deadline:
            time.sleep(0.01)
        assert client._disconnected, "the client never saw the router go"
        router2 = Router(
            transport=TCPTransport(HOST, free_port), runtime=active_runtime()
        )
        router2.start()
        back.set()
        joiner.join(20)
        assert outcome == ["returned"], outcome
        assert not client._intentionally_stopped
        assert not client._disconnected and client._conn_num is not None
    finally:
        back.set()
        client.stop()
        if router2 is not None:
            router2.stop()
        router.stop()


def test_connect_failing_part_way_can_be_retried(free_port, monkeypatch):
    from daffi import Client, Router, TCPTransport
    from daffi import _task_dispatcher
    from daffi._task_dispatcher import shared_dispatcher

    router = Router(transport=TCPTransport(HOST, free_port), runtime=active_runtime())
    router.start()
    shared_dispatcher()
    real_wakeup = _task_dispatcher.WakeupFd
    opened: list = []

    class _Tracked(real_wakeup):
        closed = False

        def close(self):
            self.closed = True
            super().close()

    def out_of_fds(*, pipe: bool = False):
        if pipe:
            raise OSError(errno.EMFILE, "Too many open files")
        channel = _Tracked(pipe=pipe)
        opened.append(channel)
        return channel

    client = Client(
        app_name="half-connected",
        transport=TCPTransport(HOST, free_port),
        runtime=active_runtime(),
    )
    try:
        monkeypatch.setattr(_task_dispatcher, "WakeupFd", out_of_fds)
        with pytest.raises(OSError, match="Too many open files"):
            client.connect()
        monkeypatch.setattr(_task_dispatcher, "WakeupFd", real_wakeup)
        assert client._conn_num is None
        assert opened and all(channel.closed for channel in opened)
        assert client not in shared_dispatcher().connections

        conn = client.connect()
        conn.wait_for_members("half-connected", timeout=10)
    finally:
        client.stop()
        router.stop()
