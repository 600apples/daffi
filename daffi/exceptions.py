"""
Application-level exceptions for daffi.
"""


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
