"""
``@callback`` decorator — register functions or class methods as remote executors.
"""

import warnings
from inspect import (
    iscoroutinefunction,
    isgeneratorfunction,
    isasyncgenfunction,
    isclass,
    ismethod,
    isfunction,
    getmembers,
    signature,
)

from daffi.exceptions import InitializationError
from daffi.utils.misc import is_lambda_function
from daffi.registry.executor_registry import EXECUTOR_REGISTRY


__all__ = ["callback"]


def _warn_if_no_return(name: str, func) -> None:
    """Emit a ``UserWarning`` when a callback is annotated to return ``None``.

    A callback with no return value will send ``None`` back to callers using
    ``rpc()`` (blocking call), which is almost always a mistake.  When the
    annotation explicitly says ``-> None`` we warn at registration time.

    Functions without a return annotation are left unchecked — they may
    intentionally return ``None`` or be used only with ``stream()``.
    """
    try:
        ret = signature(func).return_annotation
        if ret is None:
            warnings.warn(
                f"Callback {name!r} is annotated '-> None'. Callers using "
                f"rpc() will always receive None. Use stream() for "
                f"fire-and-forget calls, or fix the return type.",
                UserWarning,
                stacklevel=4,
            )
    except (TypeError, ValueError):
        pass  # built-ins or C extensions — skip


class callback:
    """Decorator that registers a plain function *or* all public methods of a
    class instance as remote callbacks.

    Decorated callables are added to the global :data:`~daffi.registry.executor_registry.EXECUTOR_REGISTRY`
    so the framework can dispatch incoming RPC requests to them.

    Restrictions:
        - Lambda functions are **not** supported.
        - Coroutine functions (``async def``) are **not** supported.
        - Generator functions are **not** supported.
        - Methods whose names start with ``_`` are silently skipped.
        - Methods decorated with :func:`~daffi.registry._local.local` are skipped.

    Example::

        from daffi import callback

        @callback
        def add(a: int, b: int) -> int:
            return a + b

        @callback
        class MathOps:
            def multiply(self, a: int, b: int) -> int:
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
            if iscoroutinefunction(func):
                raise InitializationError(
                    f"Not supported. {name!r} is a coroutine (async def) — "
                    f"daffi callbacks must be regular synchronous functions."
                )
            if isgeneratorfunction(func):
                raise InitializationError(
                    f"Not supported. {name!r} is a generator (uses yield) — "
                    f"daffi callbacks must be regular synchronous functions."
                )
            if isasyncgenfunction(func):
                raise InitializationError(
                    f"Not supported. {name!r} is an async generator (async def + yield) — "
                    f"daffi callbacks must be regular synchronous functions."
                )
            _warn_if_no_return(name, func)
            EXECUTOR_REGISTRY.register(name=name, func=func, cls=cls)

    def __call__(self, *args, **kwargs):
        """Delegate calls to the wrapped function or class."""
        return self._func_or_class(*args, **kwargs)
