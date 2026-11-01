"""
Guards for the browser client reconnect/Origin fixes.

There is no Node/browser harness in CI, so these assert the contracts in
``js-client/daffi.js`` and the example listeners that browsers connect to.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
DAFFI_JS = ROOT / "js-client" / "daffi.js"
EXAMPLES = ROOT / "js-client" / "examples"


def test_daffi_js_rejects_all_pending_on_close_and_before_init_client():
    """Uncleared early-arrival entries reused u16 uuids after reconnect."""
    src = DAFFI_JS.read_text(encoding="utf-8")

    assert "const _rejectAllPending" in src
    assert "_rejectAllPending('Connection closed unexpectedly')" in src
    assert "_rejectAllPending('Connection reset')" in src
    assert "_rejectAllPending(msg)" in src  # eviction path

    # Waiters must carry uuid; selective delete by missing uuid was the bug.
    assert re.search(
        r"pendingMessages\[uuid\]\s*=\s*\{[^}]*\buuid\b",
        src,
        re.DOTALL,
    ), "waiters must store uuid"

    # onclose must clear the whole map (including early-arrival arrays), not
    # only delete msgData.uuid on waiter objects.
    onclose = src.split("_socket.onclose")[1].split("};", 1)[0]
    assert "_rejectAllPending" in onclose
    assert "delete self.pendingMessages[msgData.uuid]" not in onclose


def test_js_listener_examples_allow_any_origin_for_browser_demos():
    """Fail-closed Origin refuses upgrades unless the listener allow-lists."""
    listeners = []
    for path in sorted(EXAMPLES.rglob("*.py")):
        text = path.read_text(encoding="utf-8")
        if "Service(" not in text and "Router(" not in text:
            continue
        if "TCPTransport(" not in text:
            continue
        # Workers are native Clients — only listening nodes need origins.
        if re.search(r"\bClient\s*\(", text) and "Service(" not in text and "Router(" not in text:
            continue
        listeners.append(path)

    assert listeners, "expected Service/Router example scripts"
    for path in listeners:
        text = path.read_text(encoding="utf-8")
        assert "websocket_allowed_origins" in text and '["*"]' in text, (
            f"{path.relative_to(ROOT)} must set websocket_allowed_origins = ['*'] "
            f"so browser demos are not rejected with 403"
        )
