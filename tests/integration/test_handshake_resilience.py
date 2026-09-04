"""
Integration tests for router handshake resilience and join-broadcast fan-out.

Covers two regressions from the perf-fixes / review follow-ups:

1. Malformed HANDSHAKE JSON must unlock the router mutex (plain ``return``
   after a successful error reply).  A follow-up client must still be able
   to join and call RPCs.

2. Join broadcast targets are collected in a dynamic list (no fixed 512
   cap).  When the N-th peer joins with N-1 > 512 existing members, every
   existing peer must receive ``on_member_added`` for the newcomer.
"""
from __future__ import annotations

import multiprocessing as mp
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import pytest

from .conftest import (
    HOST,
    TIMEOUT,
    wait_for_port,
    wait_for_members,
    silence_subprocess,
    quiet_kill,
    proc_router,
    proc_worker,
)

# Above the old fixed ``bcast_conns: [512]`` cap so a silent skip would fail.
N_BROADCAST_PEERS = 520
_BROADCAST_JOIN_TIMEOUT = 60.0


# ── subprocess helpers ─────────────────────────────────────────────────────────

def _echo_worker(port: int, name: str = "hs-echo-worker") -> None:
    silence_subprocess()
    from daffi import Client, callback

    @callback
    def echo(payload):
        return payload

    client = Client(app_name=name, host=HOST, port=port, workers=1)
    client.connect()
    try:
        client.join()
    finally:
        client.stop()


# ── fixtures ───────────────────────────────────────────────────────────────────

@pytest.fixture
def router_port(free_port):
    proc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def router_with_echo(router_port):
    wproc = mp.Process(
        target=_echo_worker, args=(router_port, "hs-echo-worker"), daemon=True
    )
    wproc.start()
    wait_for_members(router_port, {"hs-echo-worker"})
    yield router_port
    quiet_kill(wproc)


# ── malformed handshake ────────────────────────────────────────────────────────

class TestMalformedHandshake:
    """Router must keep serving after a HANDSHAKE body that fails JSON parse."""

    def test_router_accepts_new_client_after_bad_handshake(self, router_with_echo):
        from daffi import Client
        from daffi._bindings import send_message_from_client, MessageFlag
        from daffi._serialization import SerdeFormat

        port = router_with_echo
        attacker = Client(app_name="hs-attacker", host=HOST, port=port, workers=1)
        conn = attacker.connect()
        try:
            # Already-connected client sends a second HANDSHAKE with garbage
            # payload — hits RouterHandler.onHandshake's fromJson catch path.
            send_message_from_client(
                data=b"{{{not-valid-json",
                flag=MessageFlag.HANDSHAKE,
                serde=SerdeFormat.JSON,
                receiver="",
                func_name="",
                return_result=False,
                conn_num=attacker._conn_num,
                is_bytes=True,
                uuid=1,  # non-REQUEST path asserts uuid != 0
            )
            # Give the router a moment to process the bad frame.
            time.sleep(0.2)
        finally:
            attacker.stop()

        # If the router mutex were still held, this connect / rpc would hang.
        survivor = Client(app_name="hs-survivor", host=HOST, port=port, workers=1)
        conn = survivor.connect()
        try:
            assert conn.rpc(timeout=TIMEOUT).echo("still-alive") == "still-alive"
        finally:
            survivor.stop()

    def test_existing_rpc_path_still_works_after_bad_handshake(self, router_with_echo):
        from daffi import Client
        from daffi._bindings import send_message_from_client, MessageFlag
        from daffi._serialization import SerdeFormat

        port = router_with_echo
        client = Client(app_name="hs-rpc-client", host=HOST, port=port, workers=1)
        conn = client.connect()
        try:
            assert conn.rpc(timeout=TIMEOUT).echo("before") == "before"

            send_message_from_client(
                data=b"not-json-at-all",
                flag=MessageFlag.HANDSHAKE,
                serde=SerdeFormat.JSON,
                receiver="",
                func_name="",
                return_result=False,
                conn_num=client._conn_num,
                is_bytes=True,
                uuid=1,
            )
            time.sleep(0.2)

            assert conn.rpc(timeout=TIMEOUT).echo("after") == "after"
        finally:
            client.stop()


# ── join broadcast fan-out ─────────────────────────────────────────────────────

class TestJoinBroadcastFanout:
    """Every existing peer must see on_member_added for a new joiner."""

    def test_join_notifies_all_existing_peers_beyond_old_512_cap(self, router_port):
        from daffi import Client

        n = N_BROADCAST_PEERS
        last_name = f"bcast-peer-{n - 1}"
        # peer i (i < n-1) sets events[i] when it sees the last peer join.
        seen_last = [threading.Event() for _ in range(n - 1)]
        clients: list = [None] * n

        def _start_peer(idx: int) -> None:
            c = Client(
                app_name=f"bcast-peer-{idx}",
                host=HOST,
                port=router_port,
                workers=1,
            )
            conn = c.connect()
            if idx < n - 1:
                def _on_added(name: str, _idx=idx) -> None:
                    if name == last_name:
                        seen_last[_idx].set()

                c.on_member_added(_on_added)
            clients[idx] = c

        try:
            # Bring up N-1 peers first (with handlers), then the last joiner.
            with ThreadPoolExecutor(max_workers=32) as pool:
                futs = [pool.submit(_start_peer, i) for i in range(n - 1)]
                for fut in as_completed(futs):
                    fut.result()

            _start_peer(n - 1)

            deadline = time.monotonic() + _BROADCAST_JOIN_TIMEOUT
            missing = []
            for i, ev in enumerate(seen_last):
                remaining = max(0.1, deadline - time.monotonic())
                if not ev.wait(timeout=remaining):
                    missing.append(i)

            assert not missing, (
                f"{len(missing)}/{n - 1} peers never saw on_member_added for "
                f"{last_name!r} (old 512-cap regression). "
                f"First missing indices: {missing[:20]}"
            )
        finally:
            def _stop(c):
                if c is not None:
                    try:
                        c.stop()
                    except Exception:
                        pass

            with ThreadPoolExecutor(max_workers=32) as pool:
                list(pool.map(_stop, clients))
