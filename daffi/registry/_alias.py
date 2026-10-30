from typing import Callable, Any


def alias(value: str):
    """Register a callback under *value* instead of its own name.

    Works above or below ``@callback``::

        @callback
        @alias("sum")
        def add(a, b): ...

        @alias("sum")
        @callback
        def add(a, b): ...

    On a class method it renames that one method.
    """

    if not isinstance(value, str) or not value:
        raise ValueError("Alias must be a non-empty string.")
    if "," in value:
        raise ValueError("Alias cannot contain a comma (method lists are comma-separated on the wire).")

    def dec(fn: Callable[..., Any]):
        from daffi.registry._callback import callback
        from daffi.registry._executor_registry import EXECUTOR_REGISTRY

        if isinstance(fn, callback):
            if len(fn.names) != 1:
                raise ValueError("@alias names one callback; put it on a method of the class instead.")
            EXECUTOR_REGISTRY.rename(fn.names[0], value)
            fn.names[0] = value
            return fn
        fn.alias = value
        return fn

    return dec
