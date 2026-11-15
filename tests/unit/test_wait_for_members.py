"""
wait_for_members — sync and aio unit coverage.

Scenarios: empty args, already present, event wake, multi-peer join,
irrelevant join, timeout (incl. missing names), disconnect mid-wait,
not connected, and handler cleanup.
"""

from __future__ import annotations

import asyncio
import threading
import time

import pytest

from daffi.exceptions import Disconnected, Evicted
from daffi._rpc_proxy import ClientConnection
from daffi.aio._rpc_proxy import AsyncClientConnection


class _FakeClient:
    def __init__(self, conn_num: int = 7):
        self._conn_num = conn_num
        self._disconnected = False
        self._connection_error = None
        self._on_member_added_handlers: list = []
        self._on_member_removed_handlers: list = []


def _patch_sync_members(monkeypatch, members: dict):
    def fake(conn_num):
        return [{"name": n, "methods": []} for n in members.get(conn_num, [])]

    monkeypatch.setattr("daffi._rpc_proxy.get_available_members", fake)


def _patch_aio_members(monkeypatch, members: dict):
    def fake(conn_num):
        return [{"name": n, "methods": []} for n in members.get(conn_num, [])]

    monkeypatch.setattr("daffi.aio._rpc_proxy.get_available_members", fake)


def _fire_join(client: _FakeClient, name: str) -> None:
    for handler in list(client._on_member_added_handlers):
        handler(name)


# ---------------------------------------------------------------------------
# Sync
# ---------------------------------------------------------------------------


class TestSyncWaitForMembers:
    def test_empty_members_is_noop(self, monkeypatch):
        client = _FakeClient()
        _patch_sync_members(monkeypatch, {7: []})
        ClientConnection(client).wait_for_members()
        assert client._on_member_added_handlers == []

    def test_already_present_returns_immediately(self, monkeypatch):
        client = _FakeClient()
        _patch_sync_members(
            monkeypatch, {7: ["worker-1", "worker-2"]}
        )
        conn = ClientConnection(client)
        started = time.monotonic()
        conn.wait_for_members("worker-1", "worker-2", timeout=2)
        assert time.monotonic() - started < 0.5
        assert client._on_member_added_handlers == []

    def test_wakes_on_member_added(self, monkeypatch):
        client = _FakeClient()
        members = {7: []}
        _patch_sync_members(monkeypatch, members)
        conn = ClientConnection(client)

        def join_soon():
            time.sleep(0.05)
            members[7] = ["worker-1"]
            _fire_join(client, "worker-1")

        t = threading.Thread(target=join_soon)
        t.start()
        started = time.monotonic()
        conn.wait_for_members("worker-1", timeout=2)
        elapsed = time.monotonic() - started
        t.join(timeout=2)
        assert elapsed < 1.0
        assert client._on_member_added_handlers == []

    def test_waits_for_all_named_peers(self, monkeypatch):
        client = _FakeClient()
        members = {7: []}
        _patch_sync_members(monkeypatch, members)
        conn = ClientConnection(client)

        def join_soon():
            time.sleep(0.05)
            members[7] = ["a"]
            _fire_join(client, "a")
            time.sleep(0.05)
            members[7] = ["a", "b"]
            _fire_join(client, "b")

        t = threading.Thread(target=join_soon)
        t.start()
        started = time.monotonic()
        conn.wait_for_members("a", "b", timeout=2)
        elapsed = time.monotonic() - started
        t.join(timeout=2)
        assert elapsed < 1.0
        assert 0.08 <= elapsed  # both joins happened
        assert client._on_member_added_handlers == []

    def test_irrelevant_join_does_not_complete(self, monkeypatch):
        client = _FakeClient()
        members = {7: []}
        _patch_sync_members(monkeypatch, members)
        conn = ClientConnection(client)

        def noise_then_real():
            time.sleep(0.05)
            members[7] = ["other"]
            _fire_join(client, "other")
            time.sleep(0.05)
            members[7] = ["other", "needed"]
            _fire_join(client, "needed")

        t = threading.Thread(target=noise_then_real)
        t.start()
        conn.wait_for_members("needed", timeout=2)
        t.join(timeout=2)
        assert client._on_member_added_handlers == []

    def test_timeout_lists_missing_peers(self, monkeypatch):
        client = _FakeClient()
        _patch_sync_members(monkeypatch, {7: ["present"]})
        conn = ClientConnection(client)
        with pytest.raises(TimeoutError, match="missing") as exc:
            conn.wait_for_members("present", "missing", timeout=0.15)
        assert "missing" in str(exc.value)
        assert client._on_member_added_handlers == []

    def test_timeout_when_nobody_joins(self, monkeypatch):
        client = _FakeClient()
        _patch_sync_members(monkeypatch, {7: []})
        conn = ClientConnection(client)
        started = time.monotonic()
        with pytest.raises(TimeoutError, match="worker-missing"):
            conn.wait_for_members("worker-missing", timeout=0.15)
        assert time.monotonic() - started < 0.5
        assert client._on_member_added_handlers == []

    def test_not_connected_raises_disconnected(self, monkeypatch):
        client = _FakeClient()
        client._disconnected = True
        client._conn_num = None
        conn = ClientConnection(client)
        with pytest.raises(Disconnected):
            conn.wait_for_members("worker-1", timeout=1)

    def test_not_connected_reraises_connection_error(self, monkeypatch):
        client = _FakeClient()
        client._disconnected = True
        client._conn_num = None
        client._connection_error = Evicted("taken")
        conn = ClientConnection(client)
        with pytest.raises(Evicted, match="taken"):
            conn.wait_for_members("worker-1", timeout=1)

    def test_disconnect_while_waiting(self, monkeypatch):
        client = _FakeClient()
        members = {7: []}
        _patch_sync_members(monkeypatch, members)
        conn = ClientConnection(client)

        def drop_soon():
            time.sleep(0.05)
            client._disconnected = True
            client._conn_num = None
            # Fire the awaited name so the waiter wakes and re-checks state.
            _fire_join(client, "worker-1")

        t = threading.Thread(target=drop_soon)
        t.start()
        with pytest.raises(Disconnected, match="waiting for members"):
            conn.wait_for_members("worker-1", timeout=2)
        t.join(timeout=2)
        assert client._on_member_added_handlers == []


# ---------------------------------------------------------------------------
# Async
# ---------------------------------------------------------------------------


class TestAioWaitForMembers:
    @pytest.mark.asyncio
    async def test_empty_members_is_noop(self, monkeypatch):
        client = _FakeClient()
        _patch_aio_members(monkeypatch, {7: []})
        await AsyncClientConnection(client).wait_for_members()
        assert client._on_member_added_handlers == []

    @pytest.mark.asyncio
    async def test_already_present_returns_immediately(self, monkeypatch):
        client = _FakeClient()
        _patch_aio_members(monkeypatch, {7: ["worker-1"]})
        conn = AsyncClientConnection(client)
        started = time.monotonic()
        await conn.wait_for_members("worker-1", timeout=2)
        assert time.monotonic() - started < 0.5
        assert client._on_member_added_handlers == []

    @pytest.mark.asyncio
    async def test_wakes_on_member_added(self, monkeypatch):
        client = _FakeClient()
        members = {7: []}
        _patch_aio_members(monkeypatch, members)
        conn = AsyncClientConnection(client)

        async def join_soon():
            await asyncio.sleep(0.05)
            members[7] = ["worker-1"]
            _fire_join(client, "worker-1")

        task = asyncio.create_task(join_soon())
        started = time.monotonic()
        await conn.wait_for_members("worker-1", timeout=2)
        elapsed = time.monotonic() - started
        await task
        assert elapsed < 1.0
        assert client._on_member_added_handlers == []

    @pytest.mark.asyncio
    async def test_waits_for_all_named_peers(self, monkeypatch):
        client = _FakeClient()
        members = {7: []}
        _patch_aio_members(monkeypatch, members)
        conn = AsyncClientConnection(client)

        async def join_soon():
            await asyncio.sleep(0.05)
            members[7] = ["a"]
            _fire_join(client, "a")
            await asyncio.sleep(0.05)
            members[7] = ["a", "b"]
            _fire_join(client, "b")

        task = asyncio.create_task(join_soon())
        started = time.monotonic()
        await conn.wait_for_members("a", "b", timeout=2)
        elapsed = time.monotonic() - started
        await task
        assert elapsed < 1.0
        assert 0.08 <= elapsed
        assert client._on_member_added_handlers == []

    @pytest.mark.asyncio
    async def test_irrelevant_join_does_not_complete(self, monkeypatch):
        client = _FakeClient()
        members = {7: []}
        _patch_aio_members(monkeypatch, members)
        conn = AsyncClientConnection(client)

        async def noise_then_real():
            await asyncio.sleep(0.05)
            members[7] = ["other"]
            _fire_join(client, "other")
            await asyncio.sleep(0.05)
            members[7] = ["other", "needed"]
            _fire_join(client, "needed")

        task = asyncio.create_task(noise_then_real())
        await conn.wait_for_members("needed", timeout=2)
        await task
        assert client._on_member_added_handlers == []

    @pytest.mark.asyncio
    async def test_timeout_lists_missing_peers(self, monkeypatch):
        client = _FakeClient()
        _patch_aio_members(monkeypatch, {7: ["present"]})
        conn = AsyncClientConnection(client)
        with pytest.raises(TimeoutError, match="missing") as exc:
            await conn.wait_for_members("present", "missing", timeout=0.15)
        assert "missing" in str(exc.value)
        assert client._on_member_added_handlers == []

    @pytest.mark.asyncio
    async def test_timeout_when_nobody_joins(self, monkeypatch):
        client = _FakeClient()
        _patch_aio_members(monkeypatch, {7: []})
        conn = AsyncClientConnection(client)
        started = time.monotonic()
        with pytest.raises(TimeoutError, match="worker-missing"):
            await conn.wait_for_members("worker-missing", timeout=0.15)
        assert time.monotonic() - started < 0.5
        assert client._on_member_added_handlers == []

    @pytest.mark.asyncio
    async def test_not_connected_raises_disconnected(self, monkeypatch):
        client = _FakeClient()
        client._disconnected = True
        client._conn_num = None
        conn = AsyncClientConnection(client)
        with pytest.raises(Disconnected):
            await conn.wait_for_members("worker-1", timeout=1)

    @pytest.mark.asyncio
    async def test_not_connected_reraises_connection_error(self, monkeypatch):
        client = _FakeClient()
        client._disconnected = True
        client._conn_num = None
        client._connection_error = Evicted("taken")
        conn = AsyncClientConnection(client)
        with pytest.raises(Evicted, match="taken"):
            await conn.wait_for_members("worker-1", timeout=1)

    @pytest.mark.asyncio
    async def test_disconnect_while_waiting(self, monkeypatch):
        client = _FakeClient()
        members = {7: []}
        _patch_aio_members(monkeypatch, members)
        conn = AsyncClientConnection(client)

        async def drop_soon():
            await asyncio.sleep(0.05)
            client._disconnected = True
            client._conn_num = None
            # Fire the awaited name so the waiter wakes and re-checks state.
            _fire_join(client, "worker-1")

        task = asyncio.create_task(drop_soon())
        with pytest.raises(Disconnected, match="waiting for members"):
            await conn.wait_for_members("worker-1", timeout=2)
        await task
        assert client._on_member_added_handlers == []
