"""
Unit tests for TaskDispatcher / AsyncTaskDispatcher worker-pool sizing.

Regression: workers=N must spawn N pool workers (not N-1).  workers=1 stays
inline (no pool threads / tasks).
"""
from __future__ import annotations

import asyncio

import pytest


class TestSyncTaskDispatcherWorkers:
    def test_workers_n_spawns_n_threads(self):
        from daffi._task_dispatcher import TaskDispatcher

        n = 7
        d = TaskDispatcher(workers=n)
        try:
            d._start_workers()
            assert len(d._workers) == n
            assert all(t.is_alive() for t in d._workers)
        finally:
            d.stop_event.set()
            for _ in range(len(d._workers)):
                d.queue.put(None)
            for t in d._workers:
                t.join(timeout=3)

    def test_workers_1_spawns_no_pool_threads(self):
        from daffi._task_dispatcher import TaskDispatcher

        d = TaskDispatcher(workers=1)
        d._start_workers()
        assert d._workers == []

    def test_start_workers_is_idempotent(self):
        from daffi._task_dispatcher import TaskDispatcher

        d = TaskDispatcher(workers=3)
        try:
            d._start_workers()
            d._start_workers()
            assert len(d._workers) == 3
        finally:
            d.stop_event.set()
            for _ in range(len(d._workers)):
                d.queue.put(None)
            for t in d._workers:
                t.join(timeout=3)


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
