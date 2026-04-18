"""
OS signal and ``atexit`` handler setup for graceful shutdown.
"""

import signal
import atexit

SIGNALS_TO_NAMES_DICT = dict(
    (getattr(signal, n), n) for n in dir(signal) if n.startswith("SIG") and "_" not in n
)


def set_signal_handler(handler):
    """Register *handler* for ``SIGINT``, ``SIGTERM``, and ``atexit``.

    This ensures that :meth:`~daffi.app.Application.stop` is called no matter
    how the process terminates (``Ctrl-C``, ``kill``, or normal exit).

    Args:
        handler: A zero-argument callable (or one that accepts ``*args``).
    """
    atexit.register(handler)
    signal.signal(signal.SIGINT, handler)
    signal.signal(signal.SIGTERM, handler)
