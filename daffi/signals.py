"""
OS signal and ``atexit`` handler setup for graceful shutdown.
"""

import signal
import atexit
import threading

SIGNALS_TO_NAMES_DICT = dict(
    (getattr(signal, n), n) for n in dir(signal) if n.startswith("SIG") and "_" not in n
)


def set_signal_handler(handler):
    """Register *handler* for ``SIGINT``, ``SIGTERM``, and ``atexit``.

    This ensures that :meth:`~daffi.app.Application.stop` is called no matter
    how the process terminates (``Ctrl-C``, ``kill``, or normal exit).

    Signal handlers can only be registered from the main thread; when called
    from a worker thread (e.g. when creating many clients concurrently) the
    ``signal.signal`` calls are silently skipped — ``atexit`` is still
    registered because it is thread-safe.

    Args:
        handler: A zero-argument callable (or one that accepts ``*args``).
    """
    atexit.register(handler)
    if threading.current_thread() is threading.main_thread():
        signal.signal(signal.SIGINT, handler)
        signal.signal(signal.SIGTERM, handler)
