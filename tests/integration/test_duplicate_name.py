"""
Integration tests for server-side duplicate ``app_name`` handling.

**Last-connection-wins semantics** (post-eviction change):

When a new peer connects with a name already registered on the router/service,
the *existing* (stale) connection is forcibly evicted and the new peer takes
over the slot.  This handles the common real-world case where a peer crashes
or loses network connectivity without sending a TCP FIN — the server never
runs ``diconnectionHandler`` for the dead socket, so without eviction the
slot would be permanently blocked.

What this file pins down:

1. **Reconnect takes over** while the original peer is still nominally alive
   but the new one attempts a fresh connect with the same name — the original
   gets evicted (its socket closed by the server), the newcomer succeeds.

2. **Reconnect with the same name succeeds** after a clean ``stop()`` — the
   server's ``diconnectionHandler`` removes the slot when the original peer's
   TCP FIN arrives.

3. **Second client connects immediately** when the slot is in use — eviction
   means the first attempt succeeds rather than retrying.
"""
from __future__ import annotations

import multiprocessing as mp
import time

import pytest

from .conftest import (
    HOST,
    quiet_kill,
    silence_subprocess,
    wait_for_members,
    wait_for_port,
)


# ── subprocess targets (module-level so spawn can pickle them) ────────────────

def _router_only(port: int, name: str = "dup-router") -> None:
    silence_subprocess()
    from daffi import Router
    r = Router(app_name=name, host=HOST, port=port)
    r.start()
    r.join()


def _service_only(port: int, name: str = "dup-service") -> None:
    """Bare service with no callbacks — keeps the test focused on the
    handshake / channel-registration path rather than RPC dispatch."""
    silence_subprocess()
    from daffi import Service
    s = Service(app_name=name, host=HOST, port=port, workers=2)
    s.start()
    s.join()


def _holding_worker(
    port: int,
    name: str,
    ready_evt,
    release_evt,
) -> None:
    """Connects with *name*, signals readiness, holds the connection until
    *release_evt* is set, then ``stop()``s cleanly."""
    silence_subprocess()
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    client = Client(app_name=name, host=HOST, port=port, workers=2)
    client.connect()
    ready_evt.set()
    release_evt.wait(timeout=30)
    client.stop()


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def router_proc(free_port):
    p = mp.Process(target=_router_only, args=(free_port,), daemon=True)
    p.start()
    wait_for_port(free_port)
    yield free_port, p
    quiet_kill(p)


@pytest.fixture
def service_proc(free_port):
    p = mp.Process(target=_service_only, args=(free_port,), daemon=True)
    p.start()
    wait_for_port(free_port)
    time.sleep(0.1)
    yield free_port, p
    quiet_kill(p)


# ── last-connection-wins (eviction) tests ─────────────────────────────────────

class TestLastConnectionWins:
    """A new peer connecting with a name that is already registered evicts the
    existing (stale/zombie) peer and takes over the slot."""

    def test_router_evicts_stale_slot_on_reconnect(self, router_proc):
        """Second client with the same ``app_name`` takes over from the first.

        The first holder's socket is closed by the router when evicted; the
        second's ``connect()`` must succeed.
        """
        from daffi import Client

        port, _ = router_proc
        ready = mp.Event()
        release = mp.Event()

        holder = mp.Process(
            target=_holding_worker,
            args=(port, "twin", ready, release),
            daemon=True,
        )
        holder.start()
        try:
            assert ready.wait(timeout=10), "holder failed to connect"

            # Newcomer claims the same name — must succeed by evicting the holder.
            newcomer = Client(app_name="twin", host=HOST, port=port)
            newcomer.connect()
            assert newcomer._conn_num is not None, "newcomer should have connected"

            # Newcomer is now the active peer with that name.
            wait_for_members(port, {"twin"}, timeout=5.0, probe_name="_evict-probe")
        finally:
            newcomer.stop()
            release.set()
            holder.join(timeout=5.0)
            if holder.is_alive():
                quiet_kill(holder)

    def test_service_evicts_stale_slot_on_reconnect(self, service_proc):
        """Same eviction guarantee for Service (separate ``onHandshake`` path)."""
        from daffi import Client

        port, _ = service_proc
        ready = mp.Event()
        release = mp.Event()

        holder = mp.Process(
            target=_holding_worker,
            args=(port, "twin-svc", ready, release),
            daemon=True,
        )
        holder.start()
        try:
            assert ready.wait(timeout=10), "holder failed to connect"

            newcomer = Client(app_name="twin-svc", host=HOST, port=port)
            newcomer.connect()
            assert newcomer._conn_num is not None
        finally:
            newcomer.stop()
            release.set()
            holder.join(timeout=5.0)
            if holder.is_alive():
                quiet_kill(holder)


# ── positive tests (reconnect / takeover after clean stop) ────────────────────

class TestReconnectAfterStop:
    """A name freed by ``stop()`` must be claimable again — by the same
    ``Client`` object or by a fresh process."""

    def test_same_client_can_reconnect_with_same_name(self, router_proc):
        """The literal user-reported scenario: connect, stop, connect again
        with the same ``app_name``."""
        from daffi import Client
        from daffi.exceptions import InitializationError

        port, _ = router_proc
        client = Client(app_name="recyclable", host=HOST, port=port)
        client.connect()
        assert client._conn_num is not None
        client.stop()
        assert client._conn_num is None

        deadline = time.monotonic() + 5.0
        last_err: Exception | None = None
        while time.monotonic() < deadline:
            try:
                client.connect()
                break
            except InitializationError as exc:
                last_err = exc
                time.sleep(0.05)
        else:
            raise AssertionError(
                f"reconnect with same name never succeeded: {last_err}"
            )

        try:
            assert client._conn_num is not None
        finally:
            client.stop()

    def test_other_process_can_take_over_after_stop(self, router_proc):
        """Process A claims the name then disconnects cleanly; process B
        then connects with the same name and succeeds."""
        from daffi import Client

        port, _ = router_proc

        first_ready = mp.Event()
        first_release = mp.Event()
        first = mp.Process(
            target=_holding_worker,
            args=(port, "shared-id", first_ready, first_release),
            daemon=True,
        )
        first.start()
        try:
            assert first_ready.wait(timeout=10)
            first_release.set()
            first.join(timeout=10)
            assert not first.is_alive()
        finally:
            if first.is_alive():
                quiet_kill(first)

        wait_for_members(port, set(), timeout=5.0, probe_name="_takeover-probe")

        b = Client(app_name="shared-id", host=HOST, port=port)
        b.connect()
        try:
            assert b._conn_num is not None
        finally:
            b.stop()

    def test_second_client_connects_via_eviction(self, router_proc):
        """A second client whose target name is in use must connect on the
        first attempt by evicting the stale holder — no retry needed."""
        from daffi import Client

        port, _ = router_proc

        ready = mp.Event()
        release = mp.Event()
        holder = mp.Process(
            target=_holding_worker,
            args=(port, "auto-id", ready, release),
            daemon=True,
        )
        holder.start()
        try:
            assert ready.wait(timeout=10)

            client = Client(app_name="auto-id", host=HOST, port=port)
            client.connect()
            assert client._conn_num is not None

            try:
                wait_for_members(port, {"auto-id"}, timeout=5.0, probe_name="_auto-probe")
            finally:
                client.stop()
        finally:
            release.set()
            if holder.is_alive():
                quiet_kill(holder)
            holder.join(timeout=5.0)
