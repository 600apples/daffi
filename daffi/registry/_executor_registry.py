"""
Global executor registry — maps callback names to :class:`Executor` wrappers.
"""

from typing import Callable, Any, Optional, Dict, List

from daffi.exceptions import InitializationError

__all__ = ["EXECUTOR_REGISTRY"]


class Executor:
    """Wraps a single registered callback function or bound class method."""

    def __init__(self, func: Callable[..., Any], name: str, cls: Optional[type] = None):
        self.func = func
        self.name = name
        self.cls = cls

    def __str__(self):
        if self.cls:
            cls_name = (
                self.cls.__name__
                if isinstance(self.cls, type)
                else self.cls.__class__.__name__
            )
            name = f"{cls_name}.{self.name}"
        else:
            name = self.name
        return f"{name!r}"

    __repr__ = __str__

    def __call__(self, *args, **kwargs):
        if self.cls:
            return getattr(self.cls, self.name)(*args, **kwargs)
        return self.func(*args, **kwargs)


class ExecutorRegistry:
    """Mapping from callback name → :class:`Executor`.

    Subscribers are notified synchronously on :meth:`register` (used by the
    native layer to announce new callbacks).
    """

    def __init__(self):
        self.registry: Dict[str, Executor] = {}
        self.subscribers: List[Callable[[Executor], Any]] = []

    def __iter__(self):
        return iter(self.registry.items())

    def __bool__(self):
        return bool(self.registry)

    def register(
        self, name: str, func: Callable[..., Any], cls: Optional[type] = None
    ) -> None:
        """Add a new executor under *name*.

        Raises:
            InitializationError: If *name* is already registered.
        """
        if existing := self.get(name):
            raise InitializationError(
                f"Callback {existing!r} is already registered. "
                "Please use another name or set a custom alias."
            )
        self.registry[name] = Executor(func, name, cls)
        for subscriber in self.subscribers:
            subscriber(self.registry[name])

    def unregister(self, name: str) -> None:
        """Remove the executor registered under *name*.  No-op if absent."""
        del self.registry[name]

    def get(self, name: str) -> Optional[Executor]:
        """Look up an executor by *name*, returning ``None`` if not found."""
        return self.registry.get(name)


EXECUTOR_REGISTRY = ExecutorRegistry()
"""Module-level singleton registry shared by all decorators and dispatchers."""
