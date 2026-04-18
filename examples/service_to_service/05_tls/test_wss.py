"""Smoke-test: verify that a TLS-enabled service accepts both plain TLS-TCP daffi
clients *and* WSS (WebSocket Secure) clients simultaneously.

Run after service.py is already up:
    python examples/service_to_service/05_tls/test_wss.py
"""

import ssl
import socket
import struct
import os
import sys

HOST = "127.0.0.1"
PORT = 5005
CERTS = os.path.join(os.path.dirname(__file__), "certs")


def make_tls_context() -> ssl.SSLContext:
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.load_verify_locations(os.path.join(CERTS, "ca.crt"))
    return ctx


def test_wss_handshake() -> None:
    """Open a WSS connection and verify the server returns '101 Switching Protocols'."""
    ctx = make_tls_context()
    with socket.create_connection((HOST, PORT)) as raw:
        with ctx.wrap_socket(raw, server_hostname=HOST) as tls:
            upgrade = (
                b"GET / HTTP/1.1\r\n"
                b"Host: 127.0.0.1:5005\r\n"
                b"Upgrade: websocket\r\n"
                b"Connection: Upgrade\r\n"
                b"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
                b"Sec-WebSocket-Version: 13\r\n"
                b"\r\n"
            )
            tls.sendall(upgrade)
            response = b""
            while b"\r\n\r\n" not in response:
                chunk = tls.recv(4096)
                if not chunk:
                    break
                response += chunk

            assert b"101 Switching Protocols" in response, (
                f"Expected 101, got:\n{response.decode(errors='replace')}"
            )
            print("WSS handshake OK  ✓")


def test_tls_tcp_rpc() -> None:
    """Run a normal daffi RPC call over TLS-TCP to confirm co-existence."""
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    from daffi import Client

    client = Client(
        host=HOST,
        port=PORT,
        app_name="tls-coexist-check",
        tls=True,
        ca_file=os.path.join(CERTS, "ca.crt"),
    )
    conn = client.connect()
    result = conn.rpc(timeout=5).add(10, 5)
    assert result == 15, f"Expected 15, got {result}"
    client.stop()
    print("TLS-TCP RPC OK    ✓")


if __name__ == "__main__":
    print(f"Testing mixed connections to {HOST}:{PORT} ...")
    test_wss_handshake()
    test_tls_tcp_rpc()
    print("\nAll checks passed — TLS service accepts WSS and TLS-TCP simultaneously.")
