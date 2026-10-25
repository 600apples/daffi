"""
Async integration tests for on_member_added / on_member_removed event handlers.

Mirrors tests/integration/test_events.py using daffi.aio.
Layout: AsyncClient (watcher) connected to an AsyncRouter.
"""

from __future__ import annotations
from tests.conftest import active_runtime

import asyncio
import multiprocessing as mp

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


def _worker_proc(runtime: str, port: int, name: str) -> None:
    silence_subprocess(runtime)

    async def _main():
        from daffi import callback, TCPTransport
        from daffi.aio import AsyncClient

        @callback
        async def ping():
            return "pong"

        client = AsyncClient(app_name=name, transport=TCPTransport(HOST, port), runtime=runtime)
        await client.connect()
        await client.join()

    asyncio.run(_main())


# ── fixtures ───────────────────────────────────────────────────────────────────


@pytest.fixture
def router_port(free_port):
    proc = mp.Process(target=proc_router, args=(active_runtime(), free_port,), daemon=True)
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
        from daffi import TCPTransport

        received: list[str] = []
        event = asyncio.Event()

        client = AsyncClient(
            app_name="evt-watcher-added", transport=TCPTransport(HOST, router_port),
            runtime=active_runtime(),
        )
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            received.append(name)
            event.set()

        proc = mp.Process(
            target=_worker_proc, args=(active_runtime(), router_port, "evt-joiner"), daemon=True
        )
        proc.start()
        try:
            await asyncio.wait_for(event.wait(), timeout=_EVENT_TIMEOUT)
            assert "evt-joiner" in received
        finally:
            await client.stop()
            quiet_kill(proc)

    async def test_watcher_does_not_see_itself(self, router_port):
        from daffi.aio import AsyncClient
        from daffi import TCPTransport

        received: list[str] = []
        event = asyncio.Event()

        client = AsyncClient(
            app_name="evt-watcher-self", transport=TCPTransport(HOST, router_port),
            runtime=active_runtime(),
        )
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            received.append(name)
            event.set()

        proc = mp.Process(
            target=_worker_proc, args=(active_runtime(), router_port, "evt-other-self"), daemon=True
        )
        proc.start()
        try:
            await asyncio.wait_for(event.wait(), timeout=_EVENT_TIMEOUT)
            assert "evt-watcher-self" not in received
        finally:
            await client.stop()
            quiet_kill(proc)

    async def test_correct_name_passed(self, router_port):
        from daffi.aio import AsyncClient
        from daffi import TCPTransport

        received: list[str] = []
        event = asyncio.Event()

        client = AsyncClient(
            app_name="evt-watcher-name", transport=TCPTransport(HOST, router_port),
            runtime=active_runtime(),
        )
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            received.append(name)
            event.set()

        expected_name = "evt-named-worker"
        proc = mp.Process(
            target=_worker_proc, args=(active_runtime(), router_port, expected_name), daemon=True
        )
        proc.start()
        try:
            await asyncio.wait_for(event.wait(), timeout=_EVENT_TIMEOUT)
            assert expected_name in received
        finally:
            await client.stop()
            quiet_kill(proc)

    async def test_multiple_handlers_all_called(self, router_port):
        from daffi.aio import AsyncClient
        from daffi import TCPTransport

        received_a: list[str] = []
        received_b: list[str] = []
        event_a = asyncio.Event()
        event_b = asyncio.Event()

        client = AsyncClient(
            app_name="evt-multi-added", transport=TCPTransport(HOST, router_port),
            runtime=active_runtime(),
        )
        conn = await client.connect()

        @conn.on_member_added
        def _handler_a(name: str):
            received_a.append(name)
            event_a.set()

        @conn.on_member_added
        def _handler_b(name: str):
            received_b.append(name)
            event_b.set()

        proc = mp.Process(
            target=_worker_proc, args=(active_runtime(), router_port, "evt-multi-w"), daemon=True
        )
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
        from daffi import TCPTransport

        removed: list[str] = []
        joined = asyncio.Event()
        event = asyncio.Event()

        client = AsyncClient(
            app_name="evt-watcher-removed", transport=TCPTransport(HOST, router_port),
            runtime=active_runtime(),
        )
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            if name == "evt-leaver":
                joined.set()

        @conn.on_member_removed
        def _on_removed(name: str):
            if name == "evt-leaver":
                removed.append(name)
                event.set()

        proc = mp.Process(
            target=_worker_proc, args=(active_runtime(), router_port, "evt-leaver"), daemon=True
        )
        proc.start()
        try:
            await asyncio.wait_for(joined.wait(), timeout=_EVENT_TIMEOUT)
            quiet_kill(proc)
            await asyncio.wait_for(event.wait(), timeout=_EVENT_TIMEOUT)
            assert "evt-leaver" in removed
        finally:
            await client.stop()
            quiet_kill(proc)

    async def test_added_not_called_on_remove(self, router_port):
        from daffi.aio import AsyncClient
        from daffi import TCPTransport

        added: list[str] = []
        joined = asyncio.Event()
        removed_event = asyncio.Event()

        client = AsyncClient(
            app_name="evt-no-add-on-rm", transport=TCPTransport(HOST, router_port),
            runtime=active_runtime(),
        )
        conn = await client.connect()

        @conn.on_member_added
        def _on_added(name: str):
            if name == "evt-rm-only":
                added.append(name)
                joined.set()

        @conn.on_member_removed
        def _on_removed(name: str):
            if name == "evt-rm-only":
                removed_event.set()

        proc = mp.Process(
            target=_worker_proc, args=(active_runtime(), router_port, "evt-rm-only"), daemon=True
        )
        proc.start()
        try:
            await asyncio.wait_for(joined.wait(), timeout=_EVENT_TIMEOUT)
            added.clear()  # discard the join event; only care about post-kill
            quiet_kill(proc)
            await asyncio.wait_for(removed_event.wait(), timeout=_EVENT_TIMEOUT)
            await asyncio.sleep(0.3)
            assert added == [], f"on_member_added fired on a removal event: {added}"
        finally:
            await client.stop()
            quiet_kill(proc)
