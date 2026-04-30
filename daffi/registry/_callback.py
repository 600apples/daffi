"""
``@callback`` decorator — register functions or class methods as remote executors.
"""

from inspect import (
    iscoroutinefunction,
    isgeneratorfunction,
    isasyncgenfunction,
    isclass,
    ismethod,
    isfunction,
    getmembers,
)

from daffi.exceptions import InitializationError
from daffi.utils.misc import is_lambda_function
from daffi.registry._executor_registry import EXECUTOR_REGISTRY


__all__ = ["callback"]


class callback:
    """Decorator that registers a plain function *or* all public methods of a
    class instance as remote callbacks.

    Decorated callables are added to the global :data:`~daffi.registry.executor_registry.EXECUTOR_REGISTRY`
    so the framework can dispatch incoming RPC requests to them.

    Both regular (``def``) and coroutine (``async def``) functions are
    supported.  Coroutine callbacks are awaited by the
    :class:`~daffi.aio._task_dispatcher.AsyncTaskDispatcher`; using them with
    the synchronous :class:`~daffi._task_dispatcher.TaskDispatcher` raises a
    clear error at call time.

    Restrictions:
        - Lambda functions are **not** supported.
        - Generator functions (``yield``) are **not** supported.
        - Async generator functions (``async def`` + ``yield``) are **not** supported.
        - Methods whose names start with ``_`` are silently skipped.
        - Methods decorated with :func:`~daffi.registry._local.local` are skipped.

    Example::

        from daffi import callback

        @callback
        def add(a: int, b: int) -> int:
            return a + b

        # async callbacks work with daffi.aio (AsyncTaskDispatcher)
        @callback
        async def add_async(a: int, b: int) -> int:
            return a + b

        @callback
        class MathOps:
            async def multiply(self, a: int, b: int) -> int:
                return a * b
    """

    def __init__(self, func_or_class):
        cls = None
        self._func_or_class = func_or_class
        if isclass(func_or_class):
            # Inspect the *instance* so bound methods are discovered correctly.
            cls = func_or_class()
            members = getmembers(cls, predicate=lambda x: isfunction(x) or ismethod(x))
        else:
            members = [(func_or_class.__name__, func_or_class)]

        for name, func in members:
            if name.startswith("_") or hasattr(func, "local"):
                continue
            if is_lambda_function(func):
                raise InitializationError(
                    f"Not supported. {name!r} is a lambda — use a named function instead."
                )
            if isgeneratorfunction(func):
                raise InitializationError(
                    f"Not supported. {name!r} is a generator (uses yield) — "
                    f"use a regular or async function instead."
                )
            if isasyncgenfunction(func):
                raise InitializationError(
                    f"Not supported. {name!r} is an async generator (async def + yield) — "
                    f"use a regular or async function instead."
                )
            EXECUTOR_REGISTRY.register(name=name, func=func, cls=cls)

    def __call__(self, *args, **kwargs):
        """Delegate calls to the wrapped function or class."""
        return self._func_or_class(*args, **kwargs)
