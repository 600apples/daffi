"""
Global executor registry — maps callback names to :class:`Executor` wrappers.
"""

from typing import Callable, Any, Optional, Dict, List

from daffi.exceptions import InitializationError

__all__ = ["EXECUTOR_REGISTRY"]


class Executor:
    """Wraps a single registered callback function or bound class method."""

    def __init__(self, func: Callable[..., Any], name: str, cls: Optional[type] = None):
        """
        Args:
            func: The underlying callable.
            name: The public name under which it is registered (used for routing).
            cls:  If *func* belongs to a class, the class instance (so calls
                  are dispatched as ``cls.name(...)`` rather than ``func(...)``).
        """
        self.func = func
        self.name = name
        self.cls = cls

    def __str__(self):
        if self.cls:
            if isinstance(self.cls, type):
                cls_name = self.cls.__name__
            else:
                cls_name = self.cls.__class__.__name__
            name = f"{cls_name}.{self.name}"
        else:
            name = self.name
        return f"{name!r}"

    __repr__ = __str__

    def __call__(self, *args, **kwargs):
        """Invoke the wrapped callback, dispatching via the class if present."""
        if self.cls:
            return getattr(self.cls, self.name)(*args, **kwargs)
        return self.func(*args, **kwargs)


class ExecutorRegistry:
    """Thread-safe mapping from callback name → :class:`Executor`.

    Subscribers (callables) may be appended to :attr:`subscribers`; they are
    notified synchronously whenever a new executor is registered.
    """

    def __init__(self):
        self.registry: Dict[str, Executor] = dict()
        self.subscribers: List[Callable[[Executor], Any]] = list()

    def __iter__(self):
        """Iterate over ``(name, executor)`` pairs."""
        return iter(self.registry.items())

    def __bool__(self):
        """Return ``True`` when at least one executor is registered."""
        return bool(self.registry)

    def register(
        self, name: str, func: Callable[..., Any], cls: Optional[type] = None
    ) -> None:
        """Add a new executor under *name*.

        Args:
            name: Public routing name (must be unique).
            func: The callback function.
            cls:  Optional class instance for method dispatch.

        Raises:
            InitializationError: If *name* is already registered.
        """
        if existing := self.get(name):
            raise InitializationError(
                f"Callback {existing!r} is already registered. "
                f"Please, use another name or set custom alias to callback."
            )
        self.registry[name] = Executor(func, name, cls)
        for subscriber in self.subscribers:
            subscriber(self.registry[name])

    def get(self, name: str) -> Optional[Executor]:
        """Look up an executor by *name*, returning ``None`` if not found."""
        return self.registry.get(name)


EXECUTOR_REGISTRY = ExecutorRegistry()
"""Module-level singleton registry shared by all decorators and dispatchers."""
