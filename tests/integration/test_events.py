"""
Integration tests for on_member_added / on_member_removed event handlers.

Layout: Client (watcher) connected to a Router observes workers joining/leaving.

Each test verifies:
  * The correct handler is called (not the wrong one).
  * The member name passed to the handler is correct.
  * Decorator usage and direct-call usage both work.
  * Multiple handlers on the same event are all called in registration order.
  * The watcher never sees its own name in on_member_added.

Note: Service layout is intentionally not tested here.  Clients connected to a
Service do not start a task dispatcher (only router connections do), so they
never process incoming EVENTS messages on the Python side.
"""
from __future__ import annotations

import multiprocessing as mp
import threading
import time

import pytest

from .conftest import (
    HOST,
    wait_for_port,
    silence_subprocess,
    quiet_kill,
    proc_router,
)

_EVENT_TIMEOUT = 15  # seconds to wait for an event before failing


# ── subprocess helpers ─────────────────────────────────────────────────────────

def _worker_proc(port: int, name: str) -> None:
    """Minimal worker: registers one callback and blocks until killed."""
    silence_subprocess()
    import time as _t
    from daffi import Client, callback

    @callback
    def ping():
        return "pong"

    client = Client(app_name=name, host=HOST, port=port)
    client.connect()
    try:
        while True:
            _t.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


# ── fixtures ───────────────────────────────────────────────────────────────────

@pytest.fixture
def router_port(free_port):
    """Bare Router; no workers pre-spawned."""
    proc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    yield free_port
    quiet_kill(proc)


# ── Router layout ──────────────────────────────────────────────────────────────

class TestRouterMemberAdded:
    """on_member_added fires when a peer joins via Router."""

    def test_fires_with_correct_name(self, router_port):
        """Handler receives the joining peer's app_name."""
        from daffi import Client

        added: list[str] = []
        arrived = threading.Event()

        watcher = Client(app_name="ev-watcher-add", host=HOST, port=router_port)

        @watcher.on_member_added
        def _handle(member: str):
            added.append(member)
            arrived.set()

        watcher.connect()
        wproc = mp.Process(target=_worker_proc, args=(router_port, "ev-joiner"), daemon=True)
        wproc.start()
        try:
            assert arrived.wait(timeout=_EVENT_TIMEOUT), "on_member_added did not fire"
            assert "ev-joiner" in added
        finally:
            watcher.stop()
            quiet_kill(wproc)

    def test_decorator_and_direct_call_equivalent(self, router_port):
        """Decorator-style and direct-call registration both work."""
        from daffi import Client

        by_decorator: list[str] = []
        by_call:      list[str] = []
        both_done = threading.Event()

        watcher = Client(app_name="ev-watcher-deco", host=HOST, port=router_port)

        @watcher.on_member_added
        def _deco(member: str):
            by_decorator.append(member)
            if by_call:
                both_done.set()

        watcher.on_member_added(lambda m: (by_call.append(m), both_done.set() if by_decorator else None))

        watcher.connect()
        wproc = mp.Process(target=_worker_proc, args=(router_port, "ev-deco-worker"), daemon=True)
        wproc.start()
        try:
            assert both_done.wait(timeout=_EVENT_TIMEOUT), "not all handlers fired"
            assert "ev-deco-worker" in by_decorator
            assert "ev-deco-worker" in by_call
        finally:
            watcher.stop()
            quiet_kill(wproc)

    def test_multiple_handlers_called_in_order(self, router_port):
        """All on_member_added handlers are called in registration order."""
        from daffi import Client

        order: list[int] = []
        done = threading.Event()

        watcher = Client(app_name="ev-multi-add", host=HOST, port=router_port)
        watcher.on_member_added(lambda m: order.append(1))
        watcher.on_member_added(lambda m: order.append(2))
        watcher.on_member_added(lambda m: (order.append(3), done.set()))

        watcher.connect()
        wproc = mp.Process(target=_worker_proc, args=(router_port, "ev-multi-w"), daemon=True)
        wproc.start()
        try:
            assert done.wait(timeout=_EVENT_TIMEOUT), "last on_member_added handler did not fire"
            assert order == [1, 2, 3], f"wrong call order: {order}"
        finally:
            watcher.stop()
            quiet_kill(wproc)

    def test_own_name_never_received(self, router_port):
        """The watcher's own connect must not appear in on_member_added."""
        from daffi import Client

        added: list[str] = []
        arrived = threading.Event()

        watcher = Client(app_name="ev-self-check", host=HOST, port=router_port)
        watcher.on_member_added(lambda m: (added.append(m), arrived.set()))
        watcher.connect()

        wproc = mp.Process(target=_worker_proc, args=(router_port, "ev-other-peer"), daemon=True)
        wproc.start()
        try:
            arrived.wait(timeout=_EVENT_TIMEOUT)
            assert "ev-self-check" not in added, (
                f"watcher saw its own name in on_member_added: {added}"
            )
            assert "ev-other-peer" in added
        finally:
            watcher.stop()
            quiet_kill(wproc)

    def test_on_member_removed_not_called_on_join(self, router_port):
        """on_member_removed must NOT fire when a peer joins."""
        from daffi import Client

        removed: list[str] = []
        added_event = threading.Event()

        watcher = Client(app_name="ev-no-rem", host=HOST, port=router_port)
        watcher.on_member_added(lambda m: added_event.set())
        watcher.on_member_removed(lambda m: removed.append(m))
        watcher.connect()

        wproc = mp.Process(target=_worker_proc, args=(router_port, "ev-joiner-only"), daemon=True)
        wproc.start()
        try:
            added_event.wait(timeout=_EVENT_TIMEOUT)
            # Give a short window for any spurious removed event to arrive.
            time.sleep(0.3)
            assert removed == [], f"on_member_removed fired on join: {removed}"
        finally:
            watcher.stop()
            quiet_kill(wproc)


class TestRouterMemberRemoved:
    """on_member_removed fires when a peer leaves via Router."""

    def test_fires_with_correct_name(self, router_port):
        """Handler receives the departing peer's app_name."""
        from daffi import Client

        removed: list[str] = []
        departed = threading.Event()
        # Use on_member_added to know exactly when the worker is visible —
        # avoids spawning a probe client that would itself trigger a removed event.
        joined = threading.Event()

        watcher = Client(app_name="ev-watcher-rem", host=HOST, port=router_port)
        watcher.on_member_added(lambda m: joined.set() if m == "ev-leaver" else None)
        watcher.on_member_removed(lambda m: (removed.append(m), departed.set()) if m == "ev-leaver" else None)
        watcher.connect()

        wproc = mp.Process(target=_worker_proc, args=(router_port, "ev-leaver"), daemon=True)
        wproc.start()
        assert joined.wait(timeout=_EVENT_TIMEOUT), "ev-leaver never joined"

        quiet_kill(wproc)
        try:
            assert departed.wait(timeout=_EVENT_TIMEOUT), "on_member_removed did not fire"
            assert "ev-leaver" in removed
        finally:
            watcher.stop()

    def test_on_member_added_not_called_on_leave(self, router_port):
        """on_member_added must NOT fire when a peer leaves."""
        from daffi import Client

        added: list[str] = []
        joined = threading.Event()
        removed_event = threading.Event()

        watcher = Client(app_name="ev-no-add-on-rem", host=HOST, port=router_port)
        watcher.on_member_added(lambda m: (added.append(m), joined.set()) if m == "ev-gone" else None)
        watcher.on_member_removed(lambda m: removed_event.set() if m == "ev-gone" else None)
        watcher.connect()

        wproc = mp.Process(target=_worker_proc, args=(router_port, "ev-gone"), daemon=True)
        wproc.start()
        assert joined.wait(timeout=_EVENT_TIMEOUT), "ev-gone never joined"

        added.clear()   # discard the join event; only care about post-kill
        quiet_kill(wproc)
        try:
            removed_event.wait(timeout=_EVENT_TIMEOUT)
            time.sleep(0.3)
            assert added == [], f"on_member_added fired on leave: {added}"
        finally:
            watcher.stop()

    def test_full_lifecycle_add_then_remove(self, router_port):
        """on_member_added fires on join, on_member_removed fires on leave."""
        from daffi import Client

        added:   list[str] = []
        removed: list[str] = []
        added_ev   = threading.Event()
        removed_ev = threading.Event()

        watcher = Client(app_name="ev-lifecycle", host=HOST, port=router_port)
        watcher.on_member_added(lambda m: (added.append(m), added_ev.set()))
        watcher.on_member_removed(lambda m: (removed.append(m), removed_ev.set()))
        watcher.connect()

        wproc = mp.Process(target=_worker_proc, args=(router_port, "ev-cycle-peer"), daemon=True)
        wproc.start()

        try:
            assert added_ev.wait(timeout=_EVENT_TIMEOUT), "on_member_added never fired"
            assert "ev-cycle-peer" in added

            quiet_kill(wproc)
            wproc = None

            assert removed_ev.wait(timeout=_EVENT_TIMEOUT), "on_member_removed never fired"
            assert "ev-cycle-peer" in removed
        finally:
            watcher.stop()
            if wproc is not None:
                quiet_kill(wproc)


