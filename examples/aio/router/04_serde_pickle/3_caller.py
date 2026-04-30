"""
aio/router/04_serde_pickle — Caller (async).

Sends Task dataclass objects using PICKLE serialisation and receives
TaskResult objects back.  Also demonstrates cast() with await to
broadcast to all workers concurrently.

Run 1_router.py and 2_worker.py first.
"""
import asyncio
from daffi.aio import AsyncClient
from daffi import SerdeFormat
from models import Task, TaskResult, Priority


async def main():
    caller = AsyncClient(app_name="task-caller", host="0.0.0.0", port=6004)
    conn = await caller.connect()

    rpc = conn.rpc(timeout=5, serde=SerdeFormat.PICKLE)

    tasks = [
        Task("t-001", "hello world", Priority.HIGH),
        Task("t-002", "foo bar baz", Priority.LOW),
    ]
    for task in tasks:
        result: TaskResult = await rpc.execute_task(task)
        print(f"task {result.task_id}: worker={result.worker!r}  "
              f"output={result.output!r}  ok={result.success}")

    # cast() — broadcast to ALL workers.
    cast = conn.cast(timeout=5, serde=SerdeFormat.PICKLE)
    all_results = await cast.execute_task(Task("t-broadcast", "broadcast payload"))
    for worker_name, res in all_results.items():
        print(f"[cast] {worker_name}: {res.output!r}")

    await caller.stop()
    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())
