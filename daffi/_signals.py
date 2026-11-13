"""
OS signal and ``atexit`` handling for graceful shutdown.

One process-wide handler stops every live application.  Applications are
held weakly, so registering one does not keep it alive.  An application
leaves when it is stopped on purpose and comes back when it is started
again; with none left, a signal does what it did before daffi (Ctrl+C
raises ``KeyboardInterrupt``), and the original handlers are put back.
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
    Registering the same handler again does nothing.
    """
    global _atexit_installed, _stopper
    ref = weakref.WeakMethod(handler)
    with _lock:
        _handlers[:] = [h for h in _handlers if h() is not None]
        if ref not in _handlers:
            _handlers.append(ref)
        if not _atexit_installed:
            atexit.register(_stop_all)
            _atexit_installed = True
        if _stopper is None:
            _stopper = threading.Thread(
                target=_serve_stop_requests, name="daffi-signal-stop", daemon=True
            )
            _stopper.start()
        _install()


def release_signal_handler(handler) -> None:
    """Stop calling *handler*.  Once no application is left, the original
    signal handlers are restored (from the main thread; elsewhere
    :func:`_on_signal` hands each signal to them instead)."""
    ref = weakref.WeakMethod(handler)
    with _lock:
        _handlers[:] = [h for h in _handlers if h() is not None and h != ref]
        if not _handlers:
            _restore()


def _install() -> None:
    """Callers hold ``_lock``."""
    global _signals_installed
    if _signals_installed or threading.current_thread() is not threading.main_thread():
        return
    for signum in _HANDLED:
        previous = signal.getsignal(signum)
        # A default or ignored action is left to the kernel: it
        # terminates even while the main thread is stuck in native
        # code, where a Python handler would never run.
        if callable(previous) and previous is not _on_signal:
            _previous[signum] = previous
            signal.signal(signum, _on_signal)
    _signals_installed = True


def _restore() -> None:
    """Put back the handlers :func:`_install` replaced.  Main thread only;
    callers hold ``_lock``.

    Nothing changes once the program has installed a handler of its own
    over one of them: it may call :func:`_on_signal` in turn, which then
    still needs to know what came before.
    """
    global _signals_installed
    if (
        not _signals_installed
        or threading.current_thread() is not threading.main_thread()
    ):
        return
    if any(signal.getsignal(signum) is not _on_signal for signum in _previous):
        return
    for signum, previous in _previous.items():
        signal.signal(signum, previous)
    _previous.clear()
    _signals_installed = False


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
    there would hang.  The child gets the original handlers back."""
    global _lock, _requests, _stopper, _signals_installed
    _lock = threading.Lock()
    _handlers.clear()
    _requests = queue.SimpleQueue()
    _stopper = None
    try:
        _restore()
    except (ValueError, OSError):
        # Not forked from the main thread: _on_signal stays and delegates.
        pass


if hasattr(os, "register_at_fork"):
    os.register_at_fork(after_in_child=_forget_after_fork)


def _has_live_handler() -> bool:
    # No lock: the interrupted thread may hold it.
    return any(h() is not None for h in list(_handlers))


def _on_signal(signum, frame) -> None:
    previous = _previous.get(signum, signal.default_int_handler)
    if _stopper is not None and _has_live_handler():
        _requests.put(None)
        if previous is signal.default_int_handler:
            # Ctrl+C stops the applications and lets ``join()`` return.
            return
    if callable(previous):
        previous(signum, frame)
