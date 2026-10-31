"""
OS signal and ``atexit`` handling for graceful shutdown.

One process-wide handler stops every live application.  Applications are
held weakly, so registering one does not keep it alive.
"""

import atexit
import os
import queue
import signal
import threading
import weakref

SIGNALS_TO_NAMES_DICT = dict(
    (getattr(signal, n), n) for n in dir(signal) if n.startswith("SIG") and "_" not in n
)

_HANDLED = (signal.SIGINT, signal.SIGTERM)

# Python runs signal handlers on the main thread only.  When another thread
# takes the signal, a main thread blocked without a timeout never runs the
# handler, so waits in ``join()`` wake up this often (seconds).
SIGNAL_POLL_S = 0.2

_lock = threading.Lock()
_handlers: "list[weakref.WeakMethod]" = []
_previous: dict = {}
_atexit_installed = False
_signals_installed = False
# Signals hand stop() to this thread and do not wait for it: the interrupted
# code may hold a lock that stop() needs. SimpleQueue is the one queue safe to
# use from a signal handler.
_requests: "queue.SimpleQueue[None]" = queue.SimpleQueue()
_stopper: "threading.Thread | None" = None


def set_signal_handler(handler) -> None:
    """Call the bound method *handler* on ``SIGINT``, ``SIGTERM`` and at exit.

    Every registered application is stopped, not just the latest one.  A
    handler the program installed before daffi still runs afterwards.  A
    signal whose action is the default one (``SIGTERM`` unless the program
    changed it) is not touched, so it terminates the process at once.
    Signal handlers can only be installed from the main thread; until an
    application is created there, only the ``atexit`` hook is active.
    """
    global _atexit_installed, _signals_installed, _stopper
    with _lock:
        _handlers.append(weakref.WeakMethod(handler))
        if not _atexit_installed:
            atexit.register(_stop_all)
            _atexit_installed = True
        if _stopper is None:
            _stopper = threading.Thread(
                target=_serve_stop_requests, name="daffi-signal-stop", daemon=True
            )
            _stopper.start()
        if not _signals_installed and threading.current_thread() is threading.main_thread():
            for signum in _HANDLED:
                previous = signal.getsignal(signum)
                # A default or ignored action is left to the kernel: it
                # terminates even while the main thread is stuck in native
                # code, where a Python handler would never run.
                if callable(previous):
                    _previous[signum] = previous
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


def _serve_stop_requests() -> None:
    while True:
        _requests.get()
        _stop_all()


def _forget_after_fork() -> None:
    """The applications belong to the parent: their native state (event-loop
    threads included) does not exist in a forked child, so stopping them
    there would hang."""
    global _lock, _requests, _stopper
    _lock = threading.Lock()
    _handlers.clear()
    _requests = queue.SimpleQueue()
    _stopper = None


if hasattr(os, "register_at_fork"):
    os.register_at_fork(after_in_child=_forget_after_fork)


def _on_signal(signum, frame) -> None:
    if _stopper is not None:
        _requests.put(None)
    previous = _previous[signum]
    if previous is signal.default_int_handler:
        # Ctrl+C stops the applications and lets ``join()`` return.
        return
    previous(signum, frame)
