"""Listen and connect addresses for a daffi node.

A :class:`~daffi.app.Router` or :class:`~daffi.app.Service` may own several
transports.  They are not separate nodes: every accepted connection shares
that process's membership, so a client that arrives on a Unix socket can call
a worker that connected over TCP.

TLS is configured per transport.  That lets one process listen on a TLS TCP
port and a TLS (or plaintext) Unix socket at the same time, or use different
certificates on different binds.

``cert``, ``key``, and ``ca`` accept either a filesystem path or the PEM
material itself.  The native layer detects PEM by a leading ``-----BEGIN ``
armour and loads from memory; anything else is treated as a path.
"""

from __future__ import annotations

import os
import sys
from collections.abc import Sequence
from typing import TypeAlias

from daffi.exceptions import InitializationError

TlsBlob: TypeAlias = str | bytes | os.PathLike[str]


def _tls_blob(value: TlsBlob | None, *, name: str) -> str:
    """Normalize a TLS path / PEM argument to a ``str`` for the native layer."""
    if value is None or value == "":
        return ""
    if isinstance(value, (bytes, bytearray)):
        try:
            return bytes(value).decode("utf-8")
        except UnicodeDecodeError as exc:
            raise InitializationError(
                f"{name} bytes must be UTF-8 PEM or a path string"
            ) from exc
    if isinstance(value, os.PathLike):
        return os.fspath(value)
    if not isinstance(value, str):
        raise InitializationError(
            f"{name} must be a str, bytes, or path, got {type(value).__name__}"
        )
    return value


class TCPTransport:
    """A TCP listen or connect address, with optional TLS settings.

    Server-side (``Router`` / ``Service``) uses ``cert`` / ``key`` when
    ``tls=True``.  A non-empty ``ca`` on a listening transport enables
    mutual TLS (clients must present a certificate).  Client-side uses
    ``ca`` to verify the server and optional ``cert`` / ``key`` as the
    client identity.

    Each of ``cert``, ``key``, and ``ca`` may be a filesystem path or PEM
    material (detected natively by a leading ``-----BEGIN ``).
    """

    def __init__(
        self,
        host: str,
        port: int,
        *,
        tls: bool = False,
        cert: TlsBlob = "",
        key: TlsBlob = "",
        ca: TlsBlob = "",
    ) -> None:
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
        if not isinstance(tls, bool):
            raise InitializationError(f"tls must be a bool, got {type(tls).__name__}")
        self.host = host
        self.port = port
        self.tls = tls
        self.cert = _tls_blob(cert, name="cert")
        self.key = _tls_blob(key, name="key")
        self.ca = _tls_blob(ca, name="ca")

    @property
    def native_host(self) -> str:
        return self.host

    @property
    def native_port(self) -> int:
        return self.port

    def native_listener(self) -> tuple[str, int, bool, str, str, str]:
        """``(host, port, tls, cert, key, ca)`` for ``dfcore.startServer``.

        A non-empty ``ca`` enables mutual TLS on this listener.
        """
        return (
            self.native_host,
            self.native_port,
            self.tls,
            self.cert,
            self.key,
            self.ca,
        )

    def conn_info(self) -> tuple[str | None, int | None, str]:
        """``(host, port, unix_sock_path)`` for connection-error messages."""
        return self.host, self.port, ""

    def describe(self) -> str:
        scheme = "tcp+tls" if self.tls else "tcp"
        return f"{scheme}://{self.host}:{self.port}"

    def __repr__(self) -> str:
        if not self.tls:
            return f"TCPTransport(host={self.host!r}, port={self.port})"
        return (
            f"TCPTransport(host={self.host!r}, port={self.port}, tls=True, "
            f"cert={_short_blob(self.cert)}, key={_short_blob(self.key)}, "
            f"ca={_short_blob(self.ca)})"
        )


def _short_blob(value: str) -> str:
    if value.startswith("-----BEGIN "):
        return "<pem>"
    return repr(value)


class UnixTransport:
    """A Unix-domain socket listen or connect address, with optional TLS.

    Server-side uses ``cert`` / ``key`` when ``tls=True``.  A non-empty
    ``ca`` enables mutual TLS.  Client-side uses ``ca`` to verify the
    server and optional ``cert`` / ``key`` as the client identity.
    Hostname verification is skipped for Unix paths.
    """

    def __init__(
        self,
        path: str | os.PathLike[str],
        *,
        tls: bool = False,
        cert: TlsBlob = "",
        key: TlsBlob = "",
        ca: TlsBlob = "",
    ) -> None:
        if sys.platform == "win32":
            raise InitializationError(
                "Windows platform doesn't support unix sockets. Provide a TCPTransport"
            )
        self.path = os.fspath(path)
        if not self.path:
            raise InitializationError("UnixTransport requires a path")
        if not isinstance(tls, bool):
            raise InitializationError(f"tls must be a bool, got {type(tls).__name__}")
        self.tls = tls
        self.cert = _tls_blob(cert, name="cert")
        self.key = _tls_blob(key, name="key")
        self.ca = _tls_blob(ca, name="ca")

    @property
    def native_host(self) -> str:
        return self.path

    @property
    def native_port(self) -> int:
        return 0

    def native_listener(self) -> tuple[str, int, bool, str, str, str]:
        """``(path, 0, tls, cert, key, ca)`` for ``dfcore.startServer``.

        A non-empty ``ca`` enables mutual TLS on this listener.
        """
        return (
            self.native_host,
            self.native_port,
            self.tls,
            self.cert,
            self.key,
            self.ca,
        )

    def conn_info(self) -> tuple[str | None, int | None, str]:
        """``(host, port, unix_sock_path)`` for connection-error messages."""
        return None, None, self.path

    def describe(self) -> str:
        scheme = "unix+tls" if self.tls else "unix"
        return f"{scheme}://{self.path}"

    def __repr__(self) -> str:
        if not self.tls:
            return f"UnixTransport(path={self.path!r})"
        return (
            f"UnixTransport(path={self.path!r}, tls=True, "
            f"cert={_short_blob(self.cert)}, key={_short_blob(self.key)}, "
            f"ca={_short_blob(self.ca)})"
        )


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
    seen: set[tuple[str, str | int]] = set()
    for item in items:
        if not isinstance(item, (TCPTransport, UnixTransport)):
            raise InitializationError(
                f"expected TCPTransport or UnixTransport, got {type(item).__name__}"
            )
        key = _address_key(item)
        if key is None:
            continue
        if key in seen:
            raise InitializationError(f"duplicate transport {item.describe()}")
        seen.add(key)
    return items


def _address_key(transport: Transport) -> tuple[str, str | int] | None:
    """Identity of the socket a transport binds, or None when it never clashes
    with another bind (ephemeral TCP port 0)."""
    if isinstance(transport, UnixTransport):
        return "unix", os.path.abspath(transport.path)
    if transport.port == 0:
        return None
    return transport.host, transport.port
