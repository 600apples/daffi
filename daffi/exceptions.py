"""
Application-level exceptions for daffi.
"""

from enum import Enum


class BaseException(Exception):
    """Base class for all daffi exceptions. Provides a ``fire()`` helper for
    raising the instance without an explicit ``raise`` statement."""

    def __init__(self, message: str):
        self.message = message
        super().__init__(message)

    def fire(self):
        """Raise this exception instance."""
        raise self


class InitializationError(BaseException):
    """Raised when a component (Router, Service, or Client) fails to start or
    connect, or is configured incorrectly."""


class DisconnectReason(bytes, Enum):
    """Single-byte reason codes written to the lifecycle pipe by the native
    layer when a client connection ends.  Inheriting from ``bytes`` means
    each member *is* the raw byte value, so comparisons against
    ``os.read(fd, 1)`` work without any conversion::

        reason = os.read(lifecycle_r, 1)
        if reason == DisconnectReason.EVICTED:
            ...
    """
    DISCONNECTED = b"d"
    EVICTED      = b"e"


class Disconnected(BaseException):
    """Raised on a Client when the router or service it was connected to
    has stopped or closed the connection unexpectedly.

    Unlike the built-in :class:`ConnectionError` this is a daffi-specific
    type, so application code can catch it precisely::

        try:
            conn.join()
        except Disconnected:
            print("server gone — reconnecting…")
    """


class Evicted(BaseException):
    """Raised on a Client or Service-connected client when its slot in the
    router/service is taken over by a new connection with the same
    ``app_name`` (last-connection-wins semantics).

    This is distinct from :class:`Disconnected` raised on a plain
    server-side disconnect so application code can handle the two cases
    differently — for example by logging a warning and exiting cleanly rather
    than attempting to reconnect."""


class CallTimeout(BaseException):
    """Raised when an outgoing RPC call does not receive a response within
    the configured timeout window.

    Carries structured context about the timed-out call so it can be logged
    or inspected programmatically:

    Attributes:
        call:      Human-readable description of the call
                   (function name, optional pinned receiver, uuid).
        timeout:   The timeout limit that was exceeded, in seconds.
        elapsed:   Seconds that elapsed from sending to giving up.
        receivers: The intended receiver set, or ``None`` for broadcast.

    Example::

        try:
            result = conn.rpc(timeout=5).heavy_computation(data)
        except CallTimeout as e:
            print(f"gave up after {e.elapsed:.1f}s waiting for {e.call}")
    """

    def __init__(
        self,
        *,
        call: str,
        timeout: int,
        elapsed: float,
        receivers,
    ) -> None:
        self.call = call
        self.timeout = timeout
        self.elapsed = elapsed
        self.receivers = receivers
        recv_str = repr(receivers) if receivers else "any (broadcast)"
        super().__init__(
            f"RPC call timed out after {timeout}s.\n\n"
            f"  Call:      {call}\n"
            f"  Receivers: {recv_str}\n"
            f"  Elapsed:   {elapsed:.1f}s"
        )
