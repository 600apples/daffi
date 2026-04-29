"""
One-shot notification channel shared across the Python <-> Zig boundary.

Zig writes to :attr:`WakeupFd.write_fd` to signal that some new state is
available (a task on the task queue, a response in the message store, a
disconnect, ...).  Python blocks on :attr:`WakeupFd.read_fd` via
``select.select`` and consumes the notification with :meth:`drain`.

On Linux the underlying primitive is an ``os.eventfd`` (single fd, counter
semantics).  On macOS / BSD / fallback platforms an ``os.pipe`` is used
instead.  Both ends are non-blocking so a missed signal (counter already
saturated, pipe full) never stalls the native thread that produced it.
"""

from __future__ import annotations

import fcntl
import os


_HAS_EVENTFD = hasattr(os, "eventfd")


class WakeupFd:
    """Cross-thread wakeup primitive.

    Use one instance per logical notification channel (one per connection,
    or one per response store).  The native layer takes :attr:`write_fd`,
    Python waits on :attr:`read_fd`.
    """

    __slots__ = ("read_fd", "write_fd", "_is_eventfd")

    def __init__(self) -> None:
        if _HAS_EVENTFD:
            # EFD_NONBLOCK — writes from Zig never block; drain from Python is
            # also non-blocking (so a second concurrent drainer that lost the
            # race just sees EAGAIN instead of hanging).
            fd = os.eventfd(0, os.EFD_NONBLOCK)
            self.read_fd: int = fd
            self.write_fd: int = fd  # same fd for eventfd
            self._is_eventfd = True
        else:
            r, w = os.pipe()
            # Both ends non-blocking: write so Zig is never stalled, read so
            # multiple Python waiters racing to drain don't block when the
            # signal has already been consumed by another waiter.
            for fd in (r, w):
                flags = fcntl.fcntl(fd, fcntl.F_GETFL)
                fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
            self.read_fd = r
            self.write_fd = w
            self._is_eventfd = False

    def signal(self) -> None:
        """Write one notification unit so the fd becomes readable."""
        try:
            # eventfd: write uint64(1) as 8 little-endian bytes; pipe: 1 byte.
            os.write(
                self.write_fd,
                b"\x01\x00\x00\x00\x00\x00\x00\x00" if self._is_eventfd else b"\x01",
            )
        except OSError:
            pass

    def drain(self) -> None:
        """Consume pending notification(s) so the fd becomes unreadable again."""
        try:
            # eventfd: 8-byte uint64; pipe: drain up to 4 KiB of pending bytes.
            os.read(self.read_fd, 8 if self._is_eventfd else 4096)
        except OSError:
            pass

    def close(self) -> None:
        """Release both ends of the fd."""
        try:
            os.close(self.read_fd)
        except OSError:
            pass
        if not self._is_eventfd:
            try:
                os.close(self.write_fd)
            except OSError:
                pass
