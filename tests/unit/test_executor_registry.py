"""
``ExecutorRegistry.rename`` moves a callback in one step.

Regression: it deleted the old name and then registered the new one, so a
request in between found neither, and an error while registering lost the
callback.
"""

from __future__ import annotations

import pytest

from daffi.exceptions import InitializationError
from daffi.registry._executor_registry import ExecutorRegistry


def _registry_with(name: str) -> ExecutorRegistry:
    registry = ExecutorRegistry()
    registry.register(name, lambda: name)
    return registry


def test_subscribers_see_the_callback_under_its_new_name_only():
    registry = _registry_with("old")
    seen = []

    def subscriber(executor):
        seen.append(
            (executor.name, registry.get("old"), registry.get("new") is executor)
        )

    registry.subscribers.append(subscriber)
    registry.rename("old", "new")
    assert seen == [("new", None, True)]
    assert registry.get("new")() == "old"


def test_the_callback_is_never_missing_under_both_names(monkeypatch):
    registry = _registry_with("old")
    observed = []

    class _Watching(dict):
        def __setitem__(self, key, value):
            observed.append(self.get("old") or self.get("new"))
            super().__setitem__(key, value)

        def __delitem__(self, key):
            observed.append(self.get("old") or self.get("new"))
            super().__delitem__(key)

    registry.registry = _Watching(registry.registry)
    registry.rename("old", "new")
    assert observed and all(observed)


def test_a_refused_rename_leaves_the_callback_in_place():
    registry = _registry_with("old")
    registry.register("taken", lambda: "taken")
    with pytest.raises(InitializationError):
        registry.rename("old", "taken")
    assert registry.get("old")() == "old"
    assert registry.get("taken")() == "taken"
