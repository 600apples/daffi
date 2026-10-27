"""
Unit tests for TaskDispatcher / AsyncTaskDispatcher worker-pool sizing.

Regression: workers=N must spawn N pool workers (not N-1).  workers=1 stays
inline (no pool threads / tasks).
"""

from __future__ import annotations

import asyncio

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


@pytest.mark.asyncio
class TestAsyncTaskDispatcherWorkers:
    async def test_workers_n_spawns_n_tasks(self):
        from daffi.aio._task_dispatcher import AsyncTaskDispatcher

        n = 7
        d = AsyncTaskDispatcher(workers=n)
        try:
            d._start_workers()
            assert len(d._workers) == n
            assert all(isinstance(t, asyncio.Task) for t in d._workers)
        finally:
            for t in d._workers:
                t.cancel()
            if d._workers:
                await asyncio.gather(*d._workers, return_exceptions=True)
            d._workers.clear()

    async def test_workers_1_spawns_no_pool_tasks(self):
        from daffi.aio._task_dispatcher import AsyncTaskDispatcher

        d = AsyncTaskDispatcher(workers=1)
        d._start_workers()
        assert d._workers == []

    async def test_start_workers_is_idempotent(self):
        from daffi.aio._task_dispatcher import AsyncTaskDispatcher

        d = AsyncTaskDispatcher(workers=4)
        try:
            d._start_workers()
            d._start_workers()
            assert len(d._workers) == 4
        finally:
            for t in d._workers:
                t.cancel()
            if d._workers:
                await asyncio.gather(*d._workers, return_exceptions=True)
            d._workers.clear()
