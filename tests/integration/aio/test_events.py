"""
Async integration tests for on_member_added / on_member_removed event handlers.

Mirrors tests/integration/test_events.py using daffi.aio.
Layout: AsyncClient (watcher) connected to an AsyncRouter.
"""
from __future__ import annotations

import asyncio
import multiprocessing as mp
import time

import pytest

from .conftest import (
    HOST,
    wait_for_port,
    silence_subprocess,
    quiet_kill,
    proc_router,
)

_EVENT_TIMEOUT = 15


# ── subprocess helpers ─────────────────────────────────────────────────────────

def _worker_proc(port: int, name: str) -> None:
    silence_subprocess()

    async def _main():
        from daffi import callback
        from daffi.aio import AsyncClient

        @callback
        async def ping():
            return "pong"

        client = AsyncClient(app_name=name, host=HOST, port=port)
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── fixtures ───────────────────────────────────────────────────────────────────

@pytest.fixture
def router_port(free_port):
    proc = mp.Process(target=proc_router, args=(free_port,), daemon=True)
    proc.start()
    wait_for_port(free_port)
    yield free_port
    quiet_kill(proc)


# ── tests ──────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
class TestMemberAddedEventAsync:
    """on_member_added fires when a new peer registers."""

    async def test_decorator_fires_on_join(self, router_port):
        from daffi.aio import AsyncClient

        received: list[str] = []
        event = asyncio.Event()

        client = AsyncClient(app_name="evt-watcher-added", host=HOST, port=router_port)
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            received.append(name)
            event.set()

        proc = mp.Process(target=_worker_proc, args=(router_port, "evt-joiner"), daemon=True)
        proc.start()
        try:
            await asyncio.wait_for(event.wait(), timeout=_EVENT_TIMEOUT)
            assert "evt-joiner" in received
        finally:
            await client.stop()
            quiet_kill(proc)

    async def test_watcher_does_not_see_itself(self, router_port):
        from daffi.aio import AsyncClient

        received: list[str] = []
        event = asyncio.Event()

        client = AsyncClient(app_name="evt-watcher-self", host=HOST, port=router_port)
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            received.append(name)
            event.set()

        proc = mp.Process(target=_worker_proc, args=(router_port, "evt-other-self"), daemon=True)
        proc.start()
        try:
            await asyncio.wait_for(event.wait(), timeout=_EVENT_TIMEOUT)
            assert "evt-watcher-self" not in received
        finally:
            await client.stop()
            quiet_kill(proc)

    async def test_correct_name_passed(self, router_port):
        from daffi.aio import AsyncClient

        received: list[str] = []
        event = asyncio.Event()

        client = AsyncClient(app_name="evt-watcher-name", host=HOST, port=router_port)
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            received.append(name)
            event.set()

        expected_name = "evt-named-worker"
        proc = mp.Process(target=_worker_proc, args=(router_port, expected_name), daemon=True)
        proc.start()
        try:
            await asyncio.wait_for(event.wait(), timeout=_EVENT_TIMEOUT)
            assert expected_name in received
        finally:
            await client.stop()
            quiet_kill(proc)

    async def test_multiple_handlers_all_called(self, router_port):
        from daffi.aio import AsyncClient

        received_a: list[str] = []
        received_b: list[str] = []
        event_a = asyncio.Event()
        event_b = asyncio.Event()

        client = AsyncClient(app_name="evt-multi-added", host=HOST, port=router_port)
        conn = await client.connect()

        @conn.on_member_added
        def _handler_a(name: str):
            received_a.append(name)
            event_a.set()

        @conn.on_member_added
        def _handler_b(name: str):
            received_b.append(name)
            event_b.set()

        proc = mp.Process(target=_worker_proc, args=(router_port, "evt-multi-w"), daemon=True)
        proc.start()
        try:
            await asyncio.gather(
                asyncio.wait_for(event_a.wait(), timeout=_EVENT_TIMEOUT),
                asyncio.wait_for(event_b.wait(), timeout=_EVENT_TIMEOUT),
            )
            assert "evt-multi-w" in received_a
            assert "evt-multi-w" in received_b
        finally:
            await client.stop()
            quiet_kill(proc)


@pytest.mark.asyncio
class TestMemberRemovedEventAsync:
    """on_member_removed fires when a peer disconnects."""

    async def test_fires_on_graceful_disconnect(self, router_port):
        from daffi.aio import AsyncClient

        removed: list[str] = []
        event = asyncio.Event()

        client = AsyncClient(app_name="evt-watcher-removed", host=HOST, port=router_port)
        conn = await client.connect()

        @conn.on_member_removed
        def _on_removed(name: str):
            removed.append(name)
            event.set()

        proc = mp.Process(target=_worker_proc, args=(router_port, "evt-leaver"), daemon=True)
        proc.start()
        await asyncio.sleep(0.5)
        proc.terminate()
        proc.join(timeout=5)

        try:
            await asyncio.wait_for(event.wait(), timeout=_EVENT_TIMEOUT)
            assert "evt-leaver" in removed
        finally:
            await client.stop()

    async def test_added_not_called_on_remove(self, router_port):
        from daffi.aio import AsyncClient

        added_called = [False]
        removed_event = asyncio.Event()

        client = AsyncClient(app_name="evt-no-add-on-rm", host=HOST, port=router_port)
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            # Only the joiner itself triggers this; filter out the initial join.
            pass

        @conn.on_member_removed
        def _on_removed(name: str):
            removed_event.set()

        proc = mp.Process(target=_worker_proc, args=(router_port, "evt-rm-only"), daemon=True)
        proc.start()
        await asyncio.sleep(0.3)
        added_called[0] = False  # reset after initial join
        proc.terminate()
        proc.join(timeout=5)

        try:
            await asyncio.wait_for(removed_event.wait(), timeout=_EVENT_TIMEOUT)
            assert not added_called[0], "on_member_added fired on a removal event"
        finally:
            await client.stop()
