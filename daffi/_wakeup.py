"""
Notification channel shared across the Python <-> Zig boundary.

Zig writes to :attr:`WakeupFd.write_fd` to signal that some new state is
available (a task on the task queue, a response in the message store, a
disconnect, ...).  Python watches :attr:`WakeupFd.read_fd` with a selector
or the asyncio loop and consumes the notification with :meth:`drain`.

On Linux the underlying primitive is an ``os.eventfd`` (single fd, counter
semantics) **unless** *pipe=True* is passed.  On macOS / BSD and whenever
*pipe=True* is requested, ``os.pipe`` is used instead.  Both ends are
non-blocking so a missed signal never stalls the native thread that produced it.

Pass ``pipe=True`` whenever the channel must carry arbitrary data bytes
(e.g. lifecycle reason codes) so :meth:`write` / :meth:`read` work correctly.
"""

from __future__ import annotations

import errno
import fcntl
import os
from enum import Enum

_HAS_EVENTFD = hasattr(os, "eventfd")


def note_descriptors(delta: int) -> None:
    """Add *delta* to the process-wide descriptor count.

    Positive when descriptors are opened, negative when they are closed.
    The count and the soft limit both live in the native core and move
    atomically. When fewer than 100 descriptors remain under the stored
    limit, that limit doubles.
    """
    if delta == 0:
        return
    from . import dfcore

    if delta > 0:
        dfcore.acquireDescriptors(delta)
    else:
        dfcore.releaseDescriptors(-delta)


def _bump_file_limit() -> bool:
    """Double the stored soft limit after an open failed with EMFILE."""
    from . import dfcore

    return bool(dfcore.bumpFileLimit())


def _channel_fds(*, pipe: bool) -> int:
    """How many descriptors :func:`_open_channel` creates."""
    return 1 if _HAS_EVENTFD and not pipe else 2


def _open_channel(*, pipe: bool) -> tuple[int, int, bool]:
    """Return ``(read_fd, write_fd, is_eventfd)``.

    Retries once after doubling the open-file limit. ``os.pipe`` allocates
    both ends in one call, so a failure leaves nothing open.
    """
    for attempt in range(2):
        try:
            if _HAS_EVENTFD and not pipe:
                fd = os.eventfd(0, os.EFD_NONBLOCK)
                return fd, fd, True
            read_fd, write_fd = os.pipe()
            return read_fd, write_fd, False
        except OSError as exc:
            if exc.errno != errno.EMFILE or attempt or not _bump_file_limit():
                raise


class LifecycleSignal(bytes, Enum):
    """Single-byte signal codes carried over the lifecycle :class:`WakeupFd`.

    The native layer writes one of these to communicate a connection event.
    Inheriting from ``bytes`` means each member *is* the raw byte value, so
    comparisons against ``WakeupFd.read(1)`` work without any conversion::

        signal = lifecycle_wakeup.read(1)
        if signal == LifecycleSignal.EVICTED:
            ...

    ``NORMAL`` signals a graceful server-side disconnect (planned shutdown).
    ``INIT``   signals that the client should re-run its init/handshake
               sequence without tearing down the connection.
    """

    DISCONNECTED = b"d"
    EVICTED = b"e"
    NORMAL = b"n"
    INIT = b"i"


class WakeupFd:
    """Cross-thread wakeup / data channel.

    Use one instance per logical notification channel (one per connection,
    or one per response store).  The native layer takes :attr:`write_fd`,
    Python waits on :attr:`read_fd`.

    Args:
        pipe: Force ``os.pipe`` even on Linux.  Required whenever the channel
              must carry data bytes that need to be read back verbatim (e.g.
              the lifecycle disconnect-reason byte written by Zig).
    """

    __slots__ = ("read_fd", "write_fd", "_is_eventfd", "_tracked")

    def __init__(self, *, pipe: bool = False) -> None:
        count = _channel_fds(pipe=pipe)
        note_descriptors(count)
        try:
            read_fd, write_fd, is_eventfd = _open_channel(pipe=pipe)
        except BaseException:
            note_descriptors(-count)
            raise
        self.read_fd: int = read_fd
        self.write_fd: int = write_fd  # same fd for eventfd
        self._is_eventfd = is_eventfd
        self._tracked = count
        if is_eventfd:
            # EFD_NONBLOCK is set at creation. Writes from Zig never block,
            # and a second Python drainer that lost the race sees EAGAIN.
            return
        # Both ends non-blocking: write so Zig is never stalled, read so
        # multiple Python waiters racing to drain don't block when the
        # signal has already been consumed by another waiter.
        for fd in (read_fd, write_fd):
            flags = fcntl.fcntl(fd, fcntl.F_GETFL)
            fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

    # ------------------------------------------------------------------
    # Signal / drain helpers (counter / notification semantics)
    # ------------------------------------------------------------------

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

    # ------------------------------------------------------------------
    # Raw data helpers (pipe mode only)
    # ------------------------------------------------------------------

    def write(self, data: bytes) -> None:
        """Write *data* verbatim into the pipe.

        Only valid for pipe-mode instances (``pipe=True``).
        Silently drops the write if the pipe buffer is full or the fd is
        already closed, matching the non-blocking contract of :meth:`signal`.
        """
        if self._is_eventfd:
            raise TypeError(
                "WakeupFd.write() requires a pipe-mode instance (pipe=True)"
            )
        try:
            os.write(self.write_fd, data)
        except OSError:
            pass

    def read(self, n: int = 1) -> bytes:
        """Read up to *n* bytes from the read end.

        Returns an empty ``bytes`` object on EAGAIN / EOF / closed fd.
        Works for both pipe-mode and eventfd-mode instances (eventfd returns
        the 8-byte little-endian counter value).
        """
        try:
            return os.read(self.read_fd, n)
        except OSError:
            return b""

    # ------------------------------------------------------------------
    # Lifetime helpers
    # ------------------------------------------------------------------

    def close_write(self) -> None:
        """Close the write end of the pipe so readers see EOF.

        For eventfd instances (read_fd == write_fd) this is a no-op —
        call :meth:`close` to release the fd entirely.
        Only meaningful for pipe-mode instances.
        """
        if self._is_eventfd or self.write_fd < 0:
            return
        try:
            os.close(self.write_fd)
        except OSError:
            pass
        self.write_fd = -1
        if self._tracked:
            self._tracked -= 1
            note_descriptors(-1)

    def close(self) -> None:
        """Release both ends of the channel.  Idempotent."""
        if self.read_fd >= 0:
            try:
                os.close(self.read_fd)
            except OSError:
                pass
            self.read_fd = -1
            if self._is_eventfd:
                self.write_fd = -1
        if not self._is_eventfd and self.write_fd >= 0:
            try:
                os.close(self.write_fd)
            except OSError:
                pass
            self.write_fd = -1
        tracked = self._tracked
        self._tracked = 0
        if tracked:
            note_descriptors(-tracked)
