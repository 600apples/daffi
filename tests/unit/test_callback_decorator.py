"""
Unit tests for the @callback decorator, @alias, @local, and EXECUTOR_REGISTRY.

Current public API (daffi.registry / daffi.registry.executor_registry):

  callback          — registers a plain function or all public methods of a
                      class instance in EXECUTOR_REGISTRY
  alias(name)       — attaches a `.alias` metadata attribute to a function
                      (does not yet affect the registry key; __name__ is used)
  local             — marks a method/function so @callback's class-scanner
                      skips it
  EXECUTOR_REGISTRY — module-level ExecutorRegistry singleton
  Executor          — thin wrapper stored in the registry for each callback
"""
import warnings

import pytest

from daffi.registry import callback, alias, local
from daffi.registry._executor_registry import EXECUTOR_REGISTRY, Executor
from daffi.exceptions import InitializationError


# ── registry isolation ─────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def _clean_registry():
    """Snapshot and restore EXECUTOR_REGISTRY around every test.

    Without this, the global singleton accumulates state and causes
    duplicate-name conflicts between tests.
    """
    before = dict(EXECUTOR_REGISTRY.registry)
    yield
    EXECUTOR_REGISTRY.registry.clear()
    EXECUTOR_REGISTRY.registry.update(before)


# ══════════════════════════════════════════════════════════════════════════════
# @callback on plain functions
# ══════════════════════════════════════════════════════════════════════════════

class TestCallbackFunction:
    """@callback on a module-level function."""

    def test_registers_under_function_name(self):
        @callback
        def my_add(a: int, b: int) -> int:
            return a + b

        assert "my_add" in EXECUTOR_REGISTRY.registry

    def test_executor_returned_by_get(self):
        @callback
        def my_mul(a: int, b: int) -> int:
            return a * b

        ex = EXECUTOR_REGISTRY.get("my_mul")
        assert isinstance(ex, Executor)

    def test_executor_is_callable_and_correct(self):
        @callback
        def my_triple(x: int) -> int:
            return x * 3

        assert EXECUTOR_REGISTRY.get("my_triple")(4) == 12

    def test_decorated_object_is_callable(self):
        """The @callback instance itself delegates calls to the original fn."""
        @callback
        def my_sub(a: int, b: int) -> int:
            return a - b

        assert my_sub(10, 3) == 7

    def test_decorated_object_is_callback_instance(self):
        @callback
        def fn_inst(x: int) -> int:
            return x

        assert isinstance(fn_inst, callback)

    def test_multiple_functions_registered_independently(self):
        @callback
        def fn_alpha() -> str:
            return "alpha"

        @callback
        def fn_beta() -> str:
            return "beta"

        assert EXECUTOR_REGISTRY.get("fn_alpha")() == "alpha"
        assert EXECUTOR_REGISTRY.get("fn_beta")() == "beta"

    def test_executor_has_no_cls_for_plain_function(self):
        @callback
        def fn_plain() -> int:
            return 1

        assert EXECUTOR_REGISTRY.get("fn_plain").cls is None

    # ── error cases ───────────────────────────────────────────────────────────

    def test_duplicate_name_raises(self):
        @callback
        def fn_dup() -> int:
            return 1

        with pytest.raises(InitializationError):
            callback(lambda: 2)   # not a dup yet — but let's use a proper dup:

        # reset name to use same name
        def fn_dup() -> int:  # noqa: F811  (intentional redefinition for test)
            return 2

        with pytest.raises(InitializationError):
            callback(fn_dup)

    def test_lambda_raises(self):
        with pytest.raises(InitializationError):
            callback(lambda x: x)

    def test_async_def_allowed(self):
        # async def callbacks are accepted so they can be used with daffi.aio.
        # The sync task dispatcher guards against accidental use of async
        # callbacks in the synchronous runtime.
        @callback
        async def my_async_fn():
            pass

    def test_generator_function_raises(self):
        with pytest.raises(InitializationError):
            @callback
            def my_gen():
                yield 1

    def test_async_generator_raises(self):
        with pytest.raises(InitializationError):
            @callback
            async def my_agen():
                yield 1

    def test_no_warn_without_annotation(self):
        """No warning when there is no return annotation."""
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")

            @callback
            def fn_no_ann():
                return 42

        assert not any(issubclass(w.category, UserWarning) for w in caught)


# ══════════════════════════════════════════════════════════════════════════════
# @callback on classes
# ══════════════════════════════════════════════════════════════════════════════

class TestCallbackClass:
    """@callback on a class registers all public instance methods."""

    def test_registers_all_public_methods(self):
        @callback
        class MyOps:
            def add(self, a: int, b: int) -> int:
                return a + b

            def sub(self, a: int, b: int) -> int:
                return a - b

        assert "add" in EXECUTOR_REGISTRY.registry
        assert "sub" in EXECUTOR_REGISTRY.registry

    def test_skips_private_methods(self):
        @callback
        class MyPrivate:
            def public_fn(self) -> str:
                return "public"

            def _private_fn(self) -> str:
                return "private"

        assert "public_fn" in EXECUTOR_REGISTRY.registry
        assert "_private_fn" not in EXECUTOR_REGISTRY.registry

    def test_skips_local_decorated_methods(self):
        @callback
        class MyWithLocal:
            def visible(self) -> str:
                return "visible"

            @local
            def hidden(self) -> str:
                return "hidden"

        assert "visible" in EXECUTOR_REGISTRY.registry
        assert "hidden" not in EXECUTOR_REGISTRY.registry

    def test_executor_has_cls_reference(self):
        @callback
        class MyClassRef:
            def cls_method(self) -> str:
                return "from class"

        ex = EXECUTOR_REGISTRY.get("cls_method")
        assert ex.cls is not None

    def test_executor_callable_through_class(self):
        @callback
        class MyCallable:
            def double(self, x: int) -> int:
                return x * 2

        assert EXECUTOR_REGISTRY.get("double")(5) == 10

    def test_executor_str_includes_class_name(self):
        @callback
        class MyNamedClass:
            def named_method(self) -> int:
                return 1

        ex = EXECUTOR_REGISTRY.get("named_method")
        assert "MyNamedClass" in str(ex)
        assert "named_method" in str(ex)


# ══════════════════════════════════════════════════════════════════════════════
# @alias
# ══════════════════════════════════════════════════════════════════════════════

class TestAlias:
    """@alias sets a .alias metadata attribute on the function."""

    def test_sets_alias_attribute(self):
        @alias("custom_name")
        def fn_aliased() -> int:
            return 0

        assert fn_aliased.alias == "custom_name"

    def test_does_not_change_dunder_name(self):
        @alias("other_name")
        def original_name_fn() -> int:
            return 0

        assert original_name_fn.__name__ == "original_name_fn"

    def test_returns_original_function_unmodified(self):
        def raw_fn() -> int:
            return 0

        result = alias("whatever")(raw_fn)
        assert result is raw_fn

    def test_non_string_value_raises(self):
        with pytest.raises(ValueError):
            alias(123)

    def test_callback_uses_function_name_not_alias(self):
        """Current impl: @callback registers under __name__, not .alias."""
        @callback
        @alias("alias_key")
        def alias_test_fn() -> int:
            return 99

        assert "alias_test_fn" in EXECUTOR_REGISTRY.registry
        assert "alias_key" not in EXECUTOR_REGISTRY.registry

    def test_stacking_outer_wins(self):
        """When applied twice, the outermost decorator's value is stored."""
        @alias("outer")
        @alias("inner")
        def double_aliased() -> int:
            return 0

        assert double_aliased.alias == "outer"


# ══════════════════════════════════════════════════════════════════════════════
# @local
# ══════════════════════════════════════════════════════════════════════════════

class TestLocal:
    """@local marks a function/method so @callback's class scanner skips it."""

    def test_sets_local_attribute_bare(self):
        """@local (no parentheses) must set .local = True."""
        @local
        def fn_bare() -> int:
            return 0

        assert fn_bare.local is True

    def test_sets_local_attribute_with_parens(self):
        """@local() (with parentheses) must also work."""
        @local()
        def fn_parens() -> int:
            return 0

        assert hasattr(fn_parens, "local")

    def test_local_function_skipped_in_class(self):
        @callback
        class ClassWithLocal:
            def registered(self) -> str:
                return "registered"

            @local
            def not_registered(self) -> str:
                return "not_registered"

        assert "registered" in EXECUTOR_REGISTRY.registry
        assert "not_registered" not in EXECUTOR_REGISTRY.registry

    def test_local_does_not_break_callable(self):
        """@local leaves the function callable."""
        @local
        def fn_still_callable(x: int) -> int:
            return x * 2

        assert fn_still_callable(5) == 10


# ══════════════════════════════════════════════════════════════════════════════
# ExecutorRegistry
# ══════════════════════════════════════════════════════════════════════════════

class TestExecutorRegistry:
    """Direct tests of the ExecutorRegistry API."""

    def test_register_and_get(self):
        def raw_fn(x: int) -> int:
            return x * 2

        EXECUTOR_REGISTRY.register("raw_fn_key", raw_fn)
        ex = EXECUTOR_REGISTRY.get("raw_fn_key")
        assert isinstance(ex, Executor)
        assert ex(5) == 10

    def test_get_missing_returns_none(self):
        assert EXECUTOR_REGISTRY.get("nonexistent_xyz") is None

    def test_duplicate_register_raises(self):
        def fn_a() -> int:
            return 1

        EXECUTOR_REGISTRY.register("dup_reg_key", fn_a)
        with pytest.raises(InitializationError):
            EXECUTOR_REGISTRY.register("dup_reg_key", fn_a)

    def test_bool_true_when_non_empty(self):
        def fn_b() -> int:
            return 2

        EXECUTOR_REGISTRY.register("bool_test_fn", fn_b)
        assert bool(EXECUTOR_REGISTRY)

    def test_bool_false_when_empty(self):
        EXECUTOR_REGISTRY.registry.clear()
        assert not bool(EXECUTOR_REGISTRY)

    def test_iter_yields_name_executor_pairs(self):
        def iter_fn() -> str:
            return "iter"

        EXECUTOR_REGISTRY.register("iter_fn_key", iter_fn)
        pairs = list(EXECUTOR_REGISTRY)
        names = {name for name, _ in pairs}
        assert "iter_fn_key" in names
        assert all(isinstance(ex, Executor) for _, ex in pairs)

    def test_subscriber_called_on_register(self):
        received: list[Executor] = []
        EXECUTOR_REGISTRY.subscribers.append(received.append)

        def subscribed_fn() -> int:
            return 1

        try:
            EXECUTOR_REGISTRY.register("sub_fn_key", subscribed_fn)
            assert len(received) == 1
            assert isinstance(received[0], Executor)
            assert received[0].name == "sub_fn_key"
        finally:
            EXECUTOR_REGISTRY.subscribers.remove(received.append)

    def test_register_with_cls_binds_correctly(self):
        class Holder:
            def greet(self) -> str:
                return "hello"

        inst = Holder()
        # Registration name must match the method name because Executor.__call__
        # dispatches via getattr(cls, self.name).
        EXECUTOR_REGISTRY.register("greet", inst.greet, cls=inst)
        ex = EXECUTOR_REGISTRY.get("greet")
        assert ex.cls is inst
        assert ex() == "hello"


# ══════════════════════════════════════════════════════════════════════════════
# Executor
# ══════════════════════════════════════════════════════════════════════════════

class TestExecutor:
    """Unit tests for the Executor wrapper."""

    def test_plain_function_call(self):
        def add(a: int, b: int) -> int:
            return a + b

        ex = Executor(add, "add")
        assert ex(2, 3) == 5

    def test_class_method_dispatch(self):
        class Worker:
            def double(self, x: int) -> int:
                return x * 2

        inst = Worker()
        ex   = Executor(inst.double, "double", cls=inst)
        assert ex(7) == 14

    def test_kwargs_forwarded(self):
        def fn(a: int, b: int = 10) -> int:
            return a + b

        ex = Executor(fn, "fn")
        assert ex(1, b=99) == 100

    def test_str_plain_function(self):
        def my_func() -> int:
            return 0

        ex = Executor(my_func, "my_func")
        assert "my_func" in str(ex)

    def test_str_class_method_includes_class_name(self):
        class MyClass:
            def method(self) -> int:
                return 0

        inst = MyClass()
        ex   = Executor(inst.method, "method", cls=inst)
        s    = str(ex)
        assert "MyClass" in s
        assert "method" in s

    def test_repr_equals_str(self):
        def fn() -> int:
            return 0

        ex = Executor(fn, "fn")
        assert repr(ex) == str(ex)

    def test_cls_none_by_default(self):
        def fn() -> int:
            return 0

        ex = Executor(fn, "fn")
        assert ex.cls is None

    def test_name_attribute(self):
        def named_fn() -> int:
            return 0

        ex = Executor(named_fn, "named_fn")
        assert ex.name == "named_fn"
