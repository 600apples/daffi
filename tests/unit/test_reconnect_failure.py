"""
Failed reconnect must not leave a healthy-looking dead client.

Regression: ``_try_reconnect`` cleared ``_disconnected`` / ``_stop_event``
before ``_do_connect``; on failure those stayed cleared with
``_conn_num is None``.  The next RPC skipped reconnect, and ``join()``
hung forever on the cleared stop event.
"""

from __future__ import annotations

import asyncio
import threading
from unittest.mock import patch

import pytest

from tests.conftest import active_runtime

from daffi import Client, TCPTransport
from daffi.aio import AsyncClient
from daffi.exceptions import InitializationError, TransmissionFailure
from daffi._rpc_proxy import ClientConnection
from daffi.aio._rpc_proxy import AsyncClientConnection


def _disconnected_client(cls, name: str):
    client = cls(
        app_name=name,
        transport=TCPTransport("127.0.0.1", 1),
        runtime=active_runtime(),
    )
    client._disconnected = True
    client._connection_error = TransmissionFailure("peer gone")
    client._conn_num = None
    client._stop_event.clear()
    return client


class TestSyncReconnectFailure:
    def test_failed_reconnect_restores_disconnected_state(self):
        client = _disconnected_client(Client, "reconn-fail-sync")
        saved = client._connection_error

        with patch.object(
            client, "_do_connect", side_effect=InitializationError("no server")
        ):
            assert client._try_reconnect() is False

        assert client._disconnected is True
        assert client._conn_num is None
        assert client._stop_event.is_set()
        assert client._connection_error is saved

    def test_ensure_connected_retries_when_handle_is_missing(self):
        client = _disconnected_client(Client, "reconn-ensure-sync")
        # Inconsistent state the old bug left behind.
        client._disconnected = False
        client._conn_num = None
        conn = ClientConnection(client)

        with patch.object(client, "_try_reconnect", return_value=False) as try_reconn:
            with pytest.raises(TransmissionFailure, match="reconnect attempt failed"):
                conn._ensure_connected()
            assert try_reconn.called

    def test_join_after_failed_reconnect_does_not_hang(self):
        client = _disconnected_client(Client, "reconn-join-sync")

        with patch.object(
            client, "_do_connect", side_effect=InitializationError("no server")
        ):
            assert client._try_reconnect() is False

        # join() will attempt one more reconnect; keep it failing fast.
        with patch.object(client, "_try_reconnect", return_value=False):
            done = threading.Event()
            raised: list[BaseException] = []

            def _run():
                try:
                    client.join()
                except BaseException as exc:  # noqa: BLE001 — capture for assert
                    raised.append(exc)
                finally:
                    done.set()

            thread = threading.Thread(target=_run, daemon=True)
            thread.start()
            assert done.wait(2.0), "join() hung after a failed reconnect"
            assert raised and isinstance(raised[0], TransmissionFailure)


class TestAsyncReconnectFailure:
    def test_failed_reconnect_restores_disconnected_state(self):
        async def _run():
            client = _disconnected_client(AsyncClient, "reconn-fail-aio")
            saved = client._connection_error

            async def boom():
                raise InitializationError("no server")

            with patch.object(client, "_do_connect", side_effect=boom):
                assert await client._try_reconnect() is False

            assert client._disconnected is True
            assert client._conn_num is None
            assert client._stop_event.is_set()
            assert client._connection_error is saved

        asyncio.run(_run())

    def test_ensure_connected_retries_when_handle_is_missing(self):
        async def _run():
            client = _disconnected_client(AsyncClient, "reconn-ensure-aio")
            client._disconnected = False
            client._conn_num = None
            conn = AsyncClientConnection(client)

            with patch.object(
                client, "_try_reconnect", return_value=False
            ) as try_reconn:
                with pytest.raises(
                    TransmissionFailure, match="reconnect attempt failed"
                ):
                    await conn._ensure_connected()
                assert try_reconn.called

        asyncio.run(_run())
