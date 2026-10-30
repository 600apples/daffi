"""
OS signal and ``atexit`` handling for graceful shutdown.

One process-wide handler stops every live application.  Applications are
held weakly, so registering one does not keep it alive.
"""

import atexit
import os
import signal
import threading
import weakref

SIGNALS_TO_NAMES_DICT = dict(
    (getattr(signal, n), n) for n in dir(signal) if n.startswith("SIG") and "_" not in n
)

_HANDLED = (signal.SIGINT, signal.SIGTERM)

_lock = threading.Lock()
_handlers: "list[weakref.WeakMethod]" = []
_previous: dict = {}
_atexit_installed = False
_signals_installed = False


def set_signal_handler(handler) -> None:
    """Call the bound method *handler* on ``SIGINT``, ``SIGTERM`` and at exit.

    Every registered application is stopped, not just the latest one.  A
    handler the program installed before daffi still runs afterwards.
    Signal handlers can only be installed from the main thread; until an
    application is created there, only the ``atexit`` hook is active.
    """
    global _atexit_installed, _signals_installed
    with _lock:
        _handlers.append(weakref.WeakMethod(handler))
        if not _atexit_installed:
            atexit.register(_stop_all)
            _atexit_installed = True
        if not _signals_installed and threading.current_thread() is threading.main_thread():
            for signum in _HANDLED:
                _previous[signum] = signal.getsignal(signum)
                signal.signal(signum, _on_signal)
            _signals_installed = True


def _stop_all() -> None:
    with _lock:
        live = [h() for h in _handlers]
        _handlers[:] = [h for h, fn in zip(_handlers, live) if fn is not None]
    for fn in live:
        if fn is None:
            continue
        try:
            fn()
        except Exception:
            pass


def _forget_after_fork() -> None:
    """The applications belong to the parent: their native state (event-loop
    threads included) does not exist in a forked child, so stopping them
    there would hang."""
    global _lock
    _lock = threading.Lock()
    _handlers.clear()


if hasattr(os, "register_at_fork"):
    os.register_at_fork(after_in_child=_forget_after_fork)


def _on_signal(signum, frame) -> None:
    _stop_all()
    previous = _previous.get(signum)
    if previous is signal.default_int_handler:
        # Ctrl+C stops the applications and lets ``join()`` return.
        return
    if callable(previous):
        previous(signum, frame)
    elif previous == signal.SIG_DFL:
        signal.signal(signum, signal.SIG_DFL)
        os.kill(os.getpid(), signum)
