"""
router/04_serde_pickle — Worker.

Receives Task dataclass instances via PICKLE and returns TaskResult.

Start 1_router.py first, then this, then 3_caller.py.
"""
import os
from daffi import Client, callback
from daffi import SerdeFormat
from models import Task, TaskResult

WORKER_NAME = os.environ.get("WORKER_NAME", "task-worker-1")


@callback
def execute_task(task: Task) -> TaskResult:
    print(f"[{WORKER_NAME}] execute_task id={task.task_id!r} "
          f"priority={task.priority.value}")
    output = f"processed: {task.payload.upper()}"
    return TaskResult(task_id=task.task_id, worker=WORKER_NAME, output=output)


if __name__ == "__main__":
    worker = Client(app_name=WORKER_NAME, host="127.0.0.1", port=6004)
    worker.connect()
    print(f"Worker {WORKER_NAME!r} connected — press Ctrl+C to stop.")
    worker.join()
