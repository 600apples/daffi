"""
aio/router/04_serde_pickle — Worker (async).

Receives Task dataclass instances via PICKLE and returns TaskResult.
The async callback can await I/O (e.g. a database write) without
blocking the event loop.

Start 1_router.py first, then this, then 3_caller.py.
"""
import asyncio
import os
from daffi import callback, SerdeFormat
from daffi.aio import AsyncClient
from models import Task, TaskResult

WORKER_NAME = os.environ.get("WORKER_NAME", "task-worker-1")


@callback
async def execute_task(task: Task) -> TaskResult:
    print(f"[{WORKER_NAME}] execute_task id={task.task_id!r} "
          f"priority={task.priority.value}")
    await asyncio.sleep(0)
    output = f"processed: {task.payload.upper()}"
    return TaskResult(task_id=task.task_id, worker=WORKER_NAME, output=output)


async def main():
    worker = AsyncClient(app_name=WORKER_NAME, host="0.0.0.0", port=6004)
    await worker.connect()
    print(f"Worker {WORKER_NAME!r} connected — press Ctrl+C to stop.")
    await worker.join()


if __name__ == "__main__":
    asyncio.run(main())
