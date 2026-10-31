"""
Application-level exceptions for daffi.
"""


__all__ = [
    "DaffiError",
    "InitializationError",
    "Disconnected",
    "Evicted",
    "TransmissionFailure",
    "RemoteCallError",
    "SerdeNotAllowed",
    "CallTimeout",
]


class DaffiError(Exception):
    """Base class for all daffi exceptions. Provides a ``fire()`` helper for
    raising the instance without an explicit ``raise`` statement."""

    def __init__(self, message: str):
        self.message = message
        super().__init__(message)

    def fire(self):
        """Raise this exception instance."""
        raise self


class InitializationError(DaffiError):
    """Raised when a component (Router, Service, or Client) fails to start or
    connect, or is configured incorrectly."""


class Disconnected(DaffiError):
    """Raised on a Client when the router or service it was connected to
    has stopped or closed the connection unexpectedly.

    Unlike the built-in :class:`ConnectionError` this is a daffi-specific
    type, so application code can catch it precisely::

        try:
            conn.join()
        except Disconnected:
            print("server gone — reconnecting…")
    """


class Evicted(DaffiError):
    """Raised on a Client or Service-connected client when its slot in the
    router/service is taken over by a new connection with the same
    ``app_name`` (last-connection-wins semantics).

    This is distinct from :class:`Disconnected` raised on a plain
    server-side disconnect so application code can handle the two cases
    differently — for example by logging a warning and exiting cleanly rather
    than attempting to reconnect."""


class TransmissionFailure(DaffiError):
    """Raised when a message cannot be delivered.

    Common causes: no receiver found for the requested method, handshake
    timeout, or an expected receiver disconnected mid-call."""


class RemoteCallError(DaffiError):
    """Raised on the caller side when the remote executor raised an exception."""


class SerdeNotAllowed(DaffiError):
    """Raised by a node refusing a request in a format it does not accept:
    one outside its ``serdes=`` list, or PICKLE from a WebSocket peer.

    The caller receives it as a :class:`RemoteCallError` named
    ``SerdeNotAllowed``."""


class CallTimeout(DaffiError, TimeoutError):
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


# The old name of DaffiError.  Not in __all__: a star import would hide the
# builtin BaseException.
BaseException = DaffiError
