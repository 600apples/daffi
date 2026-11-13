"""
Sync cast() awaits peer replies concurrently, not one after another.
"""

from __future__ import annotations

import logging
import time
from types import SimpleNamespace

from daffi._rpc_proxy import BroadcastProxy


class _SlowResult:
    def __init__(self, delay: float, value):
        self.delay = delay
        self.value = value
        self.uuid = 0

    def result(self):
        time.sleep(self.delay)
        return self.value, 0, 0


def test_cast_waits_for_replies_in_parallel(monkeypatch):
    proxy = BroadcastProxy(
        conn=SimpleNamespace(client=SimpleNamespace(_conn_num=1, app_name="caller")),
        timeout=5,
        receiver=["a", "b", "c"],
        serde=0,
        return_result=True,
        logger=logging.getLogger("test.cast.parallel"),
    )

    monkeypatch.setattr(
        "daffi._rpc_proxy.Serializer.serialize", lambda *a, **k: (b"x", True)
    )
    monkeypatch.setattr(
        "daffi._rpc_proxy.Serializer.unpack_result", lambda serde, data: data
    )

    def fake_send(**kwargs):
        return 1, 0, kwargs["receiver"]

    monkeypatch.setattr("daffi._rpc_proxy.send_message_from_client", fake_send)

    delays = {"a": 0.2, "b": 0.2, "c": 0.2}

    class _RpcResult:
        def __init__(self, **kwargs):
            name = next(iter(kwargs["receivers"]))
            self._inner = _SlowResult(delays[name], (name.encode(), 0, 0))
            self.uuid = 0

        def result(self):
            return self._inner.result()

    monkeypatch.setattr("daffi._rpc_proxy.RpcResult", _RpcResult)

    started = time.monotonic()
    results = proxy._process_call_all("echo", "hi")
    elapsed = time.monotonic() - started

    assert set(results) == {"a", "b", "c"}
    # Sequential would be ~0.6s; parallel should track the slowest (~0.2s).
    assert elapsed < 0.45, f"cast waited serially ({elapsed:.3f}s)"
