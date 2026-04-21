"""
daffi — a lightweight inter-process RPC framework backed by a Zig native core.

Public API
----------
Router
    Start a message-routing server that dispatches calls between services/clients.
Service
    Start a server that exposes ``@callback``-decorated functions to callers.
Client
    Connect to a Router or Service and call remote functions via ``.rpc()``
    or fire-and-forget via ``.stream()``.
SerdeFormat
    Serialisation format enum (``OPAQUE``, ``JSON``, ``PICKLE``, ``MSGPACK``).
    ``MSGPACK`` requires the optional dependency installed via
    ``pip install 'daffi[msgpack]'``.  ``RAW`` is kept as a deprecated alias
    of ``OPAQUE`` for backward compatibility.
callback
    Decorator that registers a function or class as a remote executor.
local
    Decorator that marks a method as *local-only* (skipped by ``@callback``).
alias
    Decorator that assigns a custom RPC name to a callback.
"""

from daffi.app import (
    Router,
    Service,
    Client,
    SerdeFormat,
)
from daffi.registry import callback, local, alias
from daffi.__about__ import __version__

__all__ = [
    "Router",
    "Service",
    "Client",
    "SerdeFormat",
    "callback",
    "local",
    "alias",
    "__version__",
]
