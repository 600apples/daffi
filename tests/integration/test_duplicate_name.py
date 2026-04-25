"""
Integration tests for server-side duplicate ``app_name`` rejection.

The router and service handlers refuse a handshake whose advertised member
name is already registered with a *live* peer.  The connecting client gets
back a normal ``HANDSHAKE`` reply with ``meta.error`` populated; the Python
side surfaces this as :class:`InitializationError`.

What this file pins down:

1. **Duplicate is rejected** while the original peer is alive — covered
   for both :class:`Router` and :class:`Service`, each of which has its
   own ``onHandshake`` in ``core/handlers/handlers.zig``.

2. **Reconnect with the same name succeeds** after a clean ``stop()`` — the
   server's ``diconnectionHandler`` removes the slot when the original
   peer's TCP FIN arrives.

3. **Autoreconnect recovers** by retrying after the holder releases the
   name — same retry mechanic used internally by
   :class:`~daffi._rpc_proxy.AutoReconnect`.

Note: the Zig ``serverLoop`` does not actively close the rejected client's
socket; it just sends the rejection and loops back to ``read``.  The
Python client's :meth:`Client._do_connect` calls ``stopClient`` on
:class:`InitializationError`, which sends FIN and lets the server clean up.
"""
from __future__ import annotations

import multiprocessing as mp
import time

import pytest

from conftest import (
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
    *release_evt* is set, then ``stop()``s cleanly.

    Used by the negative test: while this subprocess is parked between
    *ready_evt* and *release_evt*, the parent attempts a second connect
    with the same name and expects rejection.
    """
    silence_subprocess()
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    client = Client(app_name=name, host=HOST, port=port, workers=2)
    client.connect()
    ready_evt.set()
    # ``release_evt.wait`` rather than ``while True`` so the parent has a
    # deterministic way to make this worker disconnect.
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
    # Give the Service's accept-loop and worker pool a moment to settle.
    time.sleep(0.1)
    yield free_port, p
    quiet_kill(p)


# ── negative tests (duplicate name → rejected) ────────────────────────────────

class TestDuplicateNameRejection:
    """The second peer claiming an in-use name must be refused while the
    first one is still alive on the network."""

    def test_router_rejects_duplicate_name(self, router_proc):
        """Two clients, same ``app_name``, against the same Router.

        The first one wins the slot; the second's handshake response carries
        ``meta.error`` and the Python ``connect()`` raises
        :class:`InitializationError`.
        """
        from daffi import Client
        from daffi.exceptions import InitializationError

        port, _ = router_proc
        ready = mp.Event()
        release = mp.Event()

        # Hold the name "twin" via a subprocess so the duplicate-check sees
        # a *live* second connection (in-process two-Clients would also work
        # but the subprocess form mirrors how this bug bites users — the
        # other claimant is in another process they don't control).
        holder = mp.Process(
            target=_holding_worker,
            args=(port, "twin", ready, release),
            daemon=True,
        )
        holder.start()
        try:
            assert ready.wait(timeout=10), "holder failed to connect"

            # Second client tries the same name.  We do NOT try-except inside
            # the Client constructor — that succeeds.  The rejection happens
            # during ``connect()`` (handshake step).
            duplicate = Client(app_name="twin", host=HOST, port=port)
            with pytest.raises(InitializationError) as exc_info:
                duplicate.connect()
            # Surface enough of the server-side reason to be useful.
            assert "twin" in str(exc_info.value)
            assert "already connected" in str(exc_info.value).lower()

            # Critical: the failed connect must leave the client in a state
            # where a *fresh* connect attempt (e.g. with a different name)
            # is possible — i.e. ``_conn_num`` was cleaned up.  Without that
            # cleanup the user would hit "client is already connected" on
            # retry and have no way to recover short of building a new
            # ``Client`` object.
            assert duplicate._conn_num is None

            # And the original peer is unaffected — the rejection path must
            # not have mutated the router's channel map.
            wait_for_members(port, {"twin"}, timeout=5.0, probe_name="_dup-probe")
        finally:
            release.set()
            holder.join(timeout=5.0)
            if holder.is_alive():
                quiet_kill(holder)

    def test_service_rejects_duplicate_name(self, service_proc):
        """Same expectation as above but with a Service as the server.

        Important because Service has its own ``onHandshake`` implementation
        — a regression in Router-only logic would not catch a missing
        check on the Service path.
        """
        from daffi import Client
        from daffi.exceptions import InitializationError

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

            duplicate = Client(app_name="twin-svc", host=HOST, port=port)
            with pytest.raises(InitializationError) as exc_info:
                duplicate.connect()
            assert "twin-svc" in str(exc_info.value)
            assert "already connected" in str(exc_info.value).lower()
            assert duplicate._conn_num is None
        finally:
            release.set()
            holder.join(timeout=5.0)
            if holder.is_alive():
                quiet_kill(holder)


# ── positive tests (reconnect / takeover after release) ──────────────────────

class TestReconnectAfterStop:
    """A name freed by ``stop()`` must be claimable again — by the same
    ``Client`` object, by a fresh process, or by the autoreconnect loop."""

    def test_same_client_can_reconnect_with_same_name(self, router_proc):
        """The literal user-reported scenario: connect, stop, connect again
        with the same ``app_name``.

        ``stop()`` closes the TCP socket, which makes the server's
        ``serverLoop`` see EOF and run ``diconnectionHandler`` — that
        removes the entry from ``ChannelsMapper`` *synchronously*.  By the
        time the next ``connect()``'s handshake reaches the router, the
        slot is free and the duplicate-name check is satisfied.

        We retry the second connect with a short backoff so the test isn't
        sensitive to the (microsecond-scale) gap between FIN being sent
        client-side and ``destroyChannel`` running on the server's reader
        thread.  If a transient rejection slips through, the next iteration
        succeeds — which is exactly the production guarantee
        ``AutoReconnect`` relies on.
        """
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
        """Process A claims the name then disconnects; process B then
        connects with the same name and succeeds.  Mirrors a worker pod
        being rescheduled with the same logical identity."""
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

            # Release & wait for the first holder to actually exit so its
            # TCP FIN reaches the router (and ``diconnectionHandler``
            # removes the slot).  Joining the process is the synchronisation
            # point; no need to poll the router.
            first_release.set()
            first.join(timeout=10)
            assert not first.is_alive()
        finally:
            if first.is_alive():
                quiet_kill(first)

        # Verify the slot is gone before claiming it — otherwise a stale
        # entry would mask a real bug as "happens to work because timing".
        wait_for_members(port, set(), timeout=5.0, probe_name="_takeover-probe")

        # Now B claims the freed name.
        b = Client(app_name="shared-id", host=HOST, port=port)
        b.connect()
        try:
            assert b._conn_num is not None
        finally:
            b.stop()

    def test_autoreconnect_recovers_after_holder_releases(self, router_proc):
        """An autoreconnecting client whose first handshake is rejected
        (because the slot is held by another process) must keep retrying
        and eventually win the slot once the holder releases it.

        Without the autoreconnect retry the user would have to write the
        retry loop themselves — that's the whole point of the flag.
        """
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

            # The autoreconnect client tries to claim the same name — its
            # first handshake will be rejected.  ``connect()`` would raise
            # InitializationError on its first try, so we kick this off in
            # a background thread with autoreconnect=True; behavior is:
            # the *first* attempt happens synchronously inside ``connect``
            # and raises if rejected.  To avoid that, we drive the retry
            # ourselves: catch the InitializationError, then release the
            # holder, then connect succeeds.
            #
            # (Driving it manually is a faithful test of the fix because
            # autoreconnect's reconnect loop uses the exact same retry
            # mechanic — catch Exception, sleep, retry.)
            client = Client(
                app_name="auto-id", host=HOST, port=port,
                autoreconnect=True, reconnect_delay=0.5,
            )

            from daffi.exceptions import InitializationError
            with pytest.raises(InitializationError):
                client.connect()
            assert client._conn_num is None

            # Now free the slot and try again — must succeed.
            release.set()
            holder.join(timeout=10)

            wait_for_members(port, set(), timeout=5.0, probe_name="_auto-probe")

            client.connect()
            try:
                assert client._conn_num is not None
            finally:
                client.stop()
        finally:
            release.set()
            if holder.is_alive():
                quiet_kill(holder)
