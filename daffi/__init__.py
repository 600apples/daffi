"""
daffi — a lightweight inter-process RPC framework with a high-performance native core.

Public API
----------
Router
    Start a message-routing server that dispatches calls between services/clients.
Service
    Start a server that exposes ``@callback``-decorated functions to callers.
Client
    Connect to a Router or Service and call remote functions via ``.rpc()``,
    ``.cast()``, or stream a generator via ``.stream()``.
SerdeFormat
    Serialisation format selector: ``OPAQUE``, ``JSON``, ``PICKLE``, ``MSGPACK``.
    ``MSGPACK`` requires the optional dependency: ``pip install 'daffi[msgpack]'``.
TCPTransport
    A TCP address.  Pass one, or a list of transports, to Router or Service.
UnixTransport
    A Unix-domain socket address.
Runtime
    Process-wide native runtime: ``THREADS`` or ``EVENTED``.
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
    Runtime,
)
from daffi.transports import TCPTransport, UnixTransport
from daffi._serialization import SerdeFormat
from daffi.registry import callback, local, alias
from daffi.__about__ import __version__

__all__ = [
    "Router",
    "Service",
    "Client",
    "TCPTransport",
    "UnixTransport",
    "Runtime",
    "SerdeFormat",
    "callback",
    "local",
    "alias",
    "__version__",
]
