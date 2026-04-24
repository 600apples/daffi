"""
Global executor registry — maps callback names to :class:`Executor` wrappers.
"""

import os

try:
    import dill
except ImportError:
    dill = None  # type: ignore[assignment]
from multiprocessing import shared_memory, Lock
from typing import Callable, Any, Optional, Dict, List

from daffi.exceptions import InitializationError

__all__ = ["EXECUTOR_REGISTRY"]


class SharedDict:
    """Process-safe dict backed by ``multiprocessing.shared_memory``.

    Used as a drop-in replacement for ``ExecutorRegistry.registry`` when
    ``use_processes=True`` so that all forked worker processes share the same
    view of registered callbacks.  Any ``register()`` or ``unregister()``
    call made in the parent *after* the fork is immediately visible to every
    worker on its next ``get()`` — no message-passing or broadcasting needed.

    Layout of the shared memory buffer::

        [0..3]   uint32 LE — version counter (incremented after every write)
        [4..7]   uint32 LE — length of the dill payload in bytes
        [8..N]   dill.dumps(dict)

    Each worker process keeps a ``(version, dict)`` cache.  The hot path is
    a single lock-free 4-byte version read; ``dill.loads`` is called only
    when the version changes (i.e. a callback was registered or removed).
    A ``multiprocessing.Lock`` serialises all writes and full reloads.
    """

    def __init__(self, initial: dict):
        if dill is None:
            raise ImportError(
                "dill is required for use_processes=True. "
                "Install it with:  pip install 'daffi[processes]'  or  pip install dill"
            )
        self._lock = Lock()
        self._creator_pid = os.getpid()
        # Per-process (version, dict) cache — populated lazily after fork.
        self._cache: "tuple[int, dict] | None" = None
        data = dill.dumps(initial)
        # 8-byte header + data; allocate 2× headroom for additions.
        self._size = max(4096, (8 + len(data)) * 2)
        self._shm = shared_memory.SharedMemory(create=True, size=self._size)
        self._write(data)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _write(self, data: bytes) -> None:
        """Write *data* and bump the version counter. Caller must hold ``_lock``."""
        n = len(data)
        if 8 + n > self._size:
            raise MemoryError(
                f"SharedDict buffer ({self._size} B) too small for {8 + n} B. "
                "Register all callbacks before start() to avoid this."
            )
        self._shm.buf[4:8] = n.to_bytes(4, "little")
        self._shm.buf[8 : 8 + n] = data
        # Bump version AFTER data is fully written so readers always see a
        # consistent (version, payload) pair.
        ver = int.from_bytes(bytes(self._shm.buf[0:4]), "little")
        self._shm.buf[0:4] = (ver + 1).to_bytes(4, "little")

    def _read_dict(self) -> dict:
        """Deserialise the dict from shared memory. Caller must hold ``_lock``."""
        n = int.from_bytes(bytes(self._shm.buf[4:8]), "little")
        if n == 0:
            return {}
        return dill.loads(bytes(self._shm.buf[8 : 8 + n]))

    def _cached_read(self) -> dict:
        """Return the dict using the process-local cache when possible.

        Hot path: one 4-byte read, no lock, no deserialisation.
        Cold path (version changed): lock + ``dill.loads`` to refresh cache.
        """
        ver = int.from_bytes(bytes(self._shm.buf[0:4]), "little")
        cache = self._cache
        if cache is not None and cache[0] == ver:
            return cache[1]
        with self._lock:
            # Re-read version inside the lock for a consistent snapshot.
            ver = int.from_bytes(bytes(self._shm.buf[0:4]), "little")
            d = self._read_dict()
        self._cache = (ver, d)
        return d

    # ------------------------------------------------------------------
    # Public dict-like API
    # ------------------------------------------------------------------

    def get(self, key, default=None):
        return self._cached_read().get(key, default)

    def __setitem__(self, key, value):
        with self._lock:
            d = self._read_dict()
            d[key] = value
            self._write(dill.dumps(d))

    def __delitem__(self, key):
        with self._lock:
            d = self._read_dict()
            d.pop(key, None)
            self._write(dill.dumps(d))

    def pop(self, key, *args):
        with self._lock:
            d = self._read_dict()
            result = d.pop(key, *args)
            self._write(dill.dumps(d))
            return result

    def __contains__(self, key):
        return key in self._cached_read()

    def items(self):
        return self._cached_read().items()

    def values(self):
        return self._cached_read().values()

    def __bool__(self):
        return bool(self._cached_read())

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def child_close(self) -> None:
        """Close the handle in a forked child without unlinking the segment.

        Call once in each worker process before ``os._exit()``.  This
        prevents Python's resource tracker from emitting "leaked
        shared_memory object" warnings, while leaving the segment alive for
        the parent.
        """
        try:
            self._shm.close()
        except Exception:
            pass

    def __del__(self) -> None:
        """Automatically close and unlink when GC'd in the creating process."""
        try:
            if os.getpid() == self._creator_pid:
                self._shm.close()
                self._shm.unlink()
            else:
                self._shm.close()
        except Exception:
            pass


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

    In single-process / thread-pool mode ``registry`` is a plain ``dict``
    — zero overhead.

    In process-pool mode, :meth:`update_to_use_processes` replaces it with
    a :class:`SharedDict` backed by ``multiprocessing.shared_memory``.
    Forked workers inherit the shared memory handle and see every subsequent
    ``register()`` / ``unregister()`` made in the parent automatically, with
    no broadcasting or IPC beyond the lock-protected shared memory read.

    Subscribers are notified synchronously on :meth:`register` (used by the
    native layer to announce new callbacks).
    """

    def __init__(self):
        self.registry: "Dict[str, Executor] | SharedDict" = {}
        self.subscribers: List[Callable[[Executor], Any]] = []

    def __iter__(self):
        return iter(self.registry.items())

    def __bool__(self):
        return bool(self.registry)

    def update_to_use_processes(self) -> None:
        """Upgrade *registry* to a :class:`SharedDict` for cross-process visibility.

        Must be called **before** worker processes are forked so the shared
        memory segment is created while the parent is still single-threaded.
        No-op if already upgraded.
        """
        if isinstance(self.registry, SharedDict):
            return
        self.registry = SharedDict(dict(self.registry))

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
