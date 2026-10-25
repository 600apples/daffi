"""Listen and connect addresses for a daffi node.

A :class:`~daffi.app.Router` or :class:`~daffi.app.Service` may own several
transports.  They are not separate nodes: every accepted connection shares
that process's membership, so a client that arrives on a Unix socket can call
a worker that connected over TCP.
"""

from __future__ import annotations

import os
import sys
from collections.abc import Sequence
from typing import TypeAlias

from daffi.exceptions import InitializationError


class TCPTransport:
    """A TCP listen or connect address."""

    def __init__(self, host: str, port: int) -> None:
        if (
            isinstance(port, bool)
            or not isinstance(port, int)
            or not 0 <= port <= 65535
        ):
            raise InitializationError(
                f"TCP port must be an integer in 0..65535, got {port!r}"
            )
        if not host:
            raise InitializationError("TCPTransport requires a host")
        self.host = host
        self.port = port

    @property
    def native_host(self) -> str:
        return self.host

    @property
    def native_port(self) -> int:
        return self.port

    def conn_info(self) -> tuple[str | None, int | None, str]:
        """``(host, port, unix_sock_path)`` for connection-error messages."""
        return self.host, self.port, ""

    def describe(self) -> str:
        return f"tcp://{self.host}:{self.port}"

    def __repr__(self) -> str:
        return f"TCPTransport(host={self.host!r}, port={self.port})"


class UnixTransport:
    """A Unix-domain socket listen or connect address."""

    def __init__(self, path: str | os.PathLike[str]) -> None:
        if sys.platform == "win32":
            raise InitializationError(
                "Windows platform doesn't support unix sockets. Provide a TCPTransport"
            )
        self.path = os.fspath(path)
        if not self.path:
            raise InitializationError("UnixTransport requires a path")

    @property
    def native_host(self) -> str:
        return self.path

    @property
    def native_port(self) -> int:
        return 0

    def conn_info(self) -> tuple[str | None, int | None, str]:
        """``(host, port, unix_sock_path)`` for connection-error messages."""
        return None, None, self.path

    def describe(self) -> str:
        return f"unix://{self.path}"

    def __repr__(self) -> str:
        return f"UnixTransport(path={self.path!r})"


Transport: TypeAlias = TCPTransport | UnixTransport
TransportArg: TypeAlias = Transport | Sequence[Transport]


def normalize_transports(value: TransportArg) -> list[Transport]:
    """Accept one transport or a sequence of them."""
    if isinstance(value, (TCPTransport, UnixTransport)):
        return [value]
    if isinstance(value, (str, bytes)):
        raise InitializationError(
            "transports must be a TCPTransport, a UnixTransport, or a sequence of them"
        )
    try:
        items = list(value)
    except TypeError as exc:
        raise InitializationError(
            "transports must be a TCPTransport, a UnixTransport, or a sequence of them"
        ) from exc
    if not items:
        raise InitializationError("at least one transport is required")
    for item in items:
        if not isinstance(item, (TCPTransport, UnixTransport)):
            raise InitializationError(
                f"expected TCPTransport or UnixTransport, got {type(item).__name__}"
            )
    return items
