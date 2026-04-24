"""
Shared data models for the router PICKLE serialisation example.

Both 2_worker.py and 3_caller.py import from this module.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class Priority(Enum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"


@dataclass
class Task:
    task_id: str
    payload: str
    priority: Priority = Priority.NORMAL


@dataclass
class TaskResult:
    task_id: str
    worker: str
    output: str
    success: bool = True
