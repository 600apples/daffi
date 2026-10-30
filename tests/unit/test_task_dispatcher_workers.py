"""
Unit tests for TaskDispatcher / AsyncTaskDispatcher worker-pool sizing.

Regression: workers=N must spawn N pool workers (not N-1).  workers=1 stays
inline (no pool threads).  The async dispatcher runs up to ``workers``
requests at once (64 by default) and leaves the rest in the native queue.
"""

from __future__ import annotations

import asyncio
import logging
import time

import pytest


class _Node:
    def __init__(self, workers: int, conn_num: int, conn_type: str | None = None):
        self.workers = workers
        self._conn_num = conn_num
        self.server_mode = None
        self._conn_type = conn_type


def _stop_pools(dispatcher) -> None:
    for conn_num in list(dispatcher._pools):
        dispatcher._stop_connection_workers(conn_num)


class TestSyncTaskDispatcherWorkers:
    def test_workers_n_spawns_n_threads(self):
        from daffi._task_dispatcher import TaskDispatcher

        n = 7
        dispatcher = TaskDispatcher()
        node = _Node(n, 1, conn_type="router")
        try:
            dispatcher._start_connection_workers(node)
            pool = dispatcher._pools[node._conn_num]
            assert len(pool.threads) == n
            assert all(thread.is_alive() for thread in pool.threads)
        finally:
            _stop_pools(dispatcher)

    def test_workers_1_spawns_no_pool_threads(self):
        from daffi._task_dispatcher import TaskDispatcher

        dispatcher = TaskDispatcher()
        dispatcher._start_connection_workers(_Node(1, 1, conn_type="router"))
        assert dispatcher._pools == {}

    def test_service_client_ignores_workers(self):
        from daffi._task_dispatcher import TaskDispatcher

        dispatcher = TaskDispatcher()
        dispatcher._start_connection_workers(_Node(5, 1, conn_type="service"))
        assert dispatcher._pools == {}

    def test_each_connection_gets_its_own_pool(self):
        from daffi._task_dispatcher import TaskDispatcher

        dispatcher = TaskDispatcher()
        first = _Node(2, 1, conn_type="router")
        second = _Node(3, 2, conn_type="router")
        try:
            dispatcher._start_connection_workers(first)
            dispatcher._start_connection_workers(second)
            assert len(dispatcher._pools[1].threads) == 2
            assert len(dispatcher._pools[2].threads) == 3
            assert set(dispatcher._pools[1].threads).isdisjoint(dispatcher._pools[2].threads)
        finally:
            _stop_pools(dispatcher)

    def test_start_workers_is_idempotent(self):
        from daffi._task_dispatcher import TaskDispatcher

        dispatcher = TaskDispatcher()
        node = _Node(3, 1, conn_type="router")
        try:
            dispatcher._start_connection_workers(node)
            dispatcher._start_connection_workers(node)
            assert len(dispatcher._pools[node._conn_num].threads) == 3
        finally:
            _stop_pools(dispatcher)

    def test_pool_leaves_the_backlog_in_the_native_queue(self, monkeypatch):
        """The poller used to move every queued request into the pool's
        unbounded queue, so the native bound (ServiceOverloaded) never
        applied and the backlog grew without limit in Python."""
        import threading
        from daffi import _task_dispatcher
        from daffi._task_dispatcher import TaskDispatcher
        from daffi._bindings import MessageFlag

        n, total = 2, 100
        release = threading.Event()
        done = []

        def slow_callback(func_name, serde, data, accepted, exposed):
            release.wait(10)
            done.append(data)
            return None, MessageFlag.RESPONSE, serde

        monkeypatch.setattr(_task_dispatcher, "_invoke_callback", slow_callback)
        native = [(i + 1, i, MessageFlag.REQUEST, 1, "caller", "me", "f", False) for i in range(total)]

        class Wakeup:
            signals = 0

            def signal(self):
                Wakeup.signals += 1

        dispatcher = TaskDispatcher()
        dispatcher.pollers = (lambda _: native.pop(0) if native else None,) * 2
        node = _Node(n, 1, conn_type="router")
        node.logger = logging.getLogger("test-backlog")
        me = threading.current_thread()
        dispatcher._poller = me
        dispatcher.connections.add(node)
        try:
            dispatcher._start_connection_workers(node)
            dispatcher._pools[1].wakeup = Wakeup()
            dispatcher._drain_tasks(node, me)
            assert len(native) >= total - 2 * n, "the poller took the whole backlog"

            release.set()
            deadline = time.monotonic() + 10
            while native and time.monotonic() < deadline:
                if Wakeup.signals:
                    Wakeup.signals = 0
                    dispatcher._drain_tasks(node, me)
                time.sleep(0.001)
            assert not native, "workers never asked the poller to resume"
            while len(done) < total and time.monotonic() < deadline:
                time.sleep(0.01)
            assert sorted(done) == list(range(total))
        finally:
            release.set()
            _stop_pools(dispatcher)


class _AsyncHarness:
    """An AsyncTaskDispatcher fed from a list instead of the native queue.

    Each request runs until :attr:`release` is set, so a test can see how
    many run at once.
    """

    CONN = 1

    def __init__(self, workers: int, queued: int) -> None:
        import logging

        from daffi._bindings import MessageFlag
        from daffi._task_dispatcher import _ConnEntry
        from daffi._wakeup import WakeupFd
        from daffi.aio._task_dispatcher import AsyncTaskDispatcher

        self.d = AsyncTaskDispatcher(workers=workers)
        self.queue = [
            (uuid, b"", MessageFlag.REQUEST, 1, "caller", "", "fn", False)
            for uuid in range(1, queued + 1)
        ]
        self.node = _Node(workers, self.CONN)
        self.node.logger = logging.getLogger("test-aio-dispatcher")
        self.entry = _ConnEntry(self.node, WakeupFd(), WakeupFd(pipe=True))
        self.d._conns[self.CONN] = self.entry
        self.d.connections.add(self.node)
        self.d.pollers = (self._take, self._take)
        self.d._run_task = self._run
        self.release = asyncio.Event()
        self.started: list[int] = []
        self.finished: list[int] = []

    def _take(self, conn_num):
        task = self.queue.pop(0) if self.queue else None
        if isinstance(task, Exception):
            raise task
        return task

    async def _run(self, uuid, *_):
        self.started.append(uuid)
        await self.release.wait()
        self.finished.append(uuid)

    async def drain(self) -> None:
        await self.d._drain_tasks(self.node, self.CONN)
        await asyncio.sleep(0)

    async def settle(self) -> None:
        while self.d._running:
            await asyncio.sleep(0)

    def close(self) -> None:
        for task in self.d._running:
            task.cancel()
        self.entry.wakeup.close()
        self.entry.lifecycle.close()


@pytest.mark.asyncio
class TestAsyncTaskDispatcherWorkers:
    async def test_default_is_one_like_the_sync_dispatcher(self):
        from daffi._task_dispatcher import TaskDispatcher
        from daffi.aio._task_dispatcher import AsyncTaskDispatcher

        assert AsyncTaskDispatcher.DEFAULT_WORKERS == TaskDispatcher.DEFAULT_WORKERS == 1
        assert AsyncTaskDispatcher().workers == 1

    async def test_runs_up_to_workers_at_once(self):
        h = _AsyncHarness(workers=3, queued=5)
        try:
            await h.drain()
            assert h.started == [1, 2, 3]
            # The rest stay in the native queue, so it can push back.
            assert len(h.queue) == 2
            assert h.d._starved == {h.CONN}
        finally:
            h.close()

    async def test_workers_1_runs_one_at_a_time(self):
        h = _AsyncHarness(workers=1, queued=3)
        try:
            await h.drain()
            assert h.started == [1]
            assert len(h.queue) == 2
        finally:
            h.close()

    async def test_freed_slot_resumes_a_starved_connection(self):
        h = _AsyncHarness(workers=2, queued=3)
        try:
            await h.drain()
            assert h.started == [1, 2]
            h.release.set()
            await h.settle()
            # The native layer will not signal again: a freed slot must.
            assert h.entry.wakeup.read_fd in h.d._ready
            assert h.d._starved == set()
            await h.drain()
            await h.settle()
            assert h.finished == [1, 2, 3]
        finally:
            h.close()

    async def test_unreadable_task_is_skipped(self):
        h = _AsyncHarness(workers=4, queued=2)
        h.queue.insert(0, UnicodeDecodeError("utf-8", b"\xff", 0, 1, "bad"))
        try:
            await h.drain()
            assert h.started == [1, 2]
        finally:
            h.close()
