"""
Sync TaskDispatcher internals that need no network.

Regressions:

* every peer event started a thread of its own, even with no handler
  registered, and handlers of consecutive events could run out of order;
* the poller rebuilt and diffed the set of all registered fds on every
  wakeup;
* a new connection waited, holding the poller lock, for a stopping poller
  that was still running an abandoned callback;
* a disconnect seen while ``Client.join()`` was parked stopped the client,
  which forbade the reconnect ``join()`` promises.
"""

from __future__ import annotations

import logging
import threading
import time

import pytest

from daffi._task_dispatcher import EventType, TaskDispatcher, _handle_lifecycle_signal
from daffi._wakeup import LifecycleSignal


class _Conn:
    def __init__(self, conn_num: int = 1) -> None:
        self._conn_num = conn_num
        self.server_mode = None
        self.logger = logging.getLogger("test-dispatcher-internals")
        self._on_member_added_handlers: list = []
        self._on_member_removed_handlers: list = []


def _event_threads() -> int:
    return sum(t.name == "daffi-event" for t in threading.enumerate())


class TestEvents:
    def test_no_thread_without_handlers(self):
        dispatcher = TaskDispatcher()
        before = _event_threads()
        for i in range(20):
            dispatcher._dispatch_event(
                _Conn(), {"type": EventType.CONNECTED, "member": f"m{i}"}
            )
        assert dispatcher._event_worker is None
        assert _event_threads() == before

    def test_handlers_run_in_arrival_order_on_one_thread(self):
        dispatcher = TaskDispatcher()
        conn = _Conn()
        seen: list = []
        threads: set = set()
        done = threading.Event()
        total = 200

        def added(member):
            # Slow early events used to be overtaken by later ones.
            if len(seen) < 5:
                time.sleep(0.01)
            seen.append(("+", member))
            threads.add(threading.current_thread())

        def removed(member):
            seen.append(("-", member))
            threads.add(threading.current_thread())
            if len(seen) == total:
                done.set()

        conn._on_member_added_handlers.append(added)
        conn._on_member_removed_handlers.append(removed)
        expected = []
        for i in range(total // 2):
            dispatcher._dispatch_event(
                conn, {"type": EventType.CONNECTED, "member": str(i)}
            )
            dispatcher._dispatch_event(
                conn, {"type": EventType.DISCONNECTED, "member": str(i)}
            )
            expected += [("+", str(i)), ("-", str(i))]
        assert done.wait(10)
        assert seen == expected
        assert len(threads) == 1
        assert threads != {threading.current_thread()}

    def test_a_failing_handler_does_not_stop_the_rest(self):
        dispatcher = TaskDispatcher()
        conn = _Conn()
        seen = []
        done = threading.Event()

        def boom(member):
            raise RuntimeError("handler failed")

        conn._on_member_added_handlers += [boom, lambda m: (seen.append(m), done.set())]
        dispatcher._dispatch_event(conn, {"type": EventType.CONNECTED, "member": "x"})
        assert done.wait(5)
        assert seen == ["x"]


class TestSelectorSync:
    def test_the_fd_map_is_read_only_after_a_change(self):
        dispatcher = TaskDispatcher()
        reads = []

        class _Counting(dict):
            def __iter__(self):
                reads.append(1)
                return super().__iter__()

        dispatcher._rfd_to_conn_num = _Counting()
        try:
            assert dispatcher._sync_selector()
            for _ in range(50):
                assert dispatcher._sync_selector()
            assert len(reads) == 1
            dispatcher._fds_dirty = True
            assert dispatcher._sync_selector()
            assert len(reads) == 2
        finally:
            dispatcher._close_selector()
            dispatcher._control.close()


class TestAdmit:
    def test_does_not_wait_for_a_stopping_poller_in_a_callback(self):
        """The old poller is busy in an abandoned callback: a new one starts."""
        dispatcher = TaskDispatcher()
        release = threading.Event()
        busy = threading.Thread(target=release.wait, args=(30,), daemon=True)
        busy.start()
        with dispatcher._poller_lock:
            dispatcher._poller = busy
            dispatcher._dispatching = True
            dispatcher.stop_event.set()
        conn = _Conn()
        try:
            started = time.monotonic()
            dispatcher._admit(conn)
            assert time.monotonic() - started < 1
            assert dispatcher._poller is not busy
            assert dispatcher._poller.is_alive()
            assert not dispatcher.stop_event.is_set()
            assert conn in dispatcher.connections
        finally:
            release.set()
            new = dispatcher._poller
            dispatcher.connections.clear()
            dispatcher.stop_event.set()
            dispatcher._control.signal()
            new.join(5)
            assert not new.is_alive()

    def test_waits_for_a_stopping_poller_at_its_selector_without_the_lock(self):
        dispatcher = TaskDispatcher()
        first = _Conn(1)
        dispatcher._admit(first)
        old = dispatcher._poller
        # The last connection leaves: the poller is told to stop.
        with dispatcher._poller_lock:
            dispatcher.connections.discard(first)
            dispatcher.stop_event.set()
        second = _Conn(2)
        try:
            dispatcher._admit(second)
            assert not old.is_alive()
            assert dispatcher._poller is not old and dispatcher._poller.is_alive()
            # The lock is free: nothing held it across the wait.
            assert dispatcher._poller_lock.acquire(timeout=1)
            dispatcher._poller_lock.release()
        finally:
            new = dispatcher._poller
            dispatcher.connections.clear()
            dispatcher.stop_event.set()
            dispatcher._control.signal()
            new.join(5)
            assert not new.is_alive()


class _JoiningClient:
    def __init__(self) -> None:
        self.app_name = "joiner"
        self.logger = logging.getLogger("test-dispatcher-internals")
        self._connection_error = None
        self._disconnected = False
        self._joining = True
        self._stop_event = threading.Event()
        self.stopped = False

    def stop(self) -> None:
        self.stopped = True


@pytest.mark.parametrize("joining", [True, False])
def test_a_disconnect_never_stops_the_client(joining):
    client = _JoiningClient()
    client._joining = joining
    _handle_lifecycle_signal(client, 1, LifecycleSignal.DISCONNECTED)
    time.sleep(0.1)
    assert client._disconnected
    assert client._connection_error is not None
    assert not client.stopped
    # join() is woken at once; nobody else is.
    assert client._stop_event.is_set() is joining
