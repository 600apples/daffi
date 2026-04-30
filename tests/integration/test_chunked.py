"""
Integration tests for multi-chunk data-integrity transfer.

Motivation
----------
When a payload is too large to fit comfortably in a single call — or when the
application deliberately streams data in pieces — daffi's ``conn.stream()`` and
``conn.stream_nowait()`` APIs send each piece as a separate OPAQUE message.
These tests verify that:

  * No byte is dropped, duplicated, or reordered across multiple messages.
  * The assembled bytes are byte-identical to the original pickled payload.
  * ``pickle.loads()`` of the assembled bytes recovers the original Python object.

Transfer protocol used in these tests
--------------------------------------
1. Caller pickles a Python object → ``raw_bytes``
2. ``raw_bytes`` is split into fixed-size chunks
3. Each chunk is sent via ``conn.stream(serde=OPAQUE)`` (blocking, one ack per
   chunk) or ``conn.stream_nowait(serde=OPAQUE)`` (fire-and-forget)
4. After the last chunk, ``conn.rpc(serde=PICKLE).get_result()`` retrieves the
   entire accumulated buffer from the service
5. ``pickle.loads(result)`` recovers the object; ``assert obj == original``

FIFO guarantee for ``stream_nowait``
-------------------------------------
All stream_nowait chunks and the subsequent ``get_result()`` rpc travel on the
same TCP connection in the same order they were sent.  TCP guarantees delivery
order, and the service's task queue is FIFO, so ``get_result()`` is always
processed after every preceding chunk — no sleep or polling needed.

Layouts tested
--------------
* Direct: Client  →  Service
* Router: Client  →  Router  →  Worker
"""
from __future__ import annotations

import multiprocessing as mp
import pickle
import time

import pytest

from .conftest import (
    HOST,
    TIMEOUT,
    quiet_kill,
    silence_subprocess,
    wait_for_port,
    wait_for_members,
)

# ── tunables ──────────────────────────────────────────────────────────────────

# Chunk size used in multi-chunk tests.  Small enough to force several messages
# even for modest payloads, large enough not to be pathologically slow.
CHUNK_SIZE = 64 * 1024   # 64 KiB

# Size of the "large" pickled payload (list of ints before pickling).
LARGE_LIST_LEN = 50_000


# ── helpers ───────────────────────────────────────────────────────────────────

def _chunked(data: bytes, size: int):
    """Yield successive *size*-byte slices of *data*."""
    for i in range(0, max(len(data), 1), size):
        yield data[i : i + size]


def _round_trip(conn, obj, chunk_size: int = CHUNK_SIZE, *, nowait: bool = False):
    """Pickle *obj*, stream the bytes in chunks, reassemble, and unpickle.

    Returns the recovered object so the caller can assert equality.
    """
    from daffi import SerdeFormat

    raw = pickle.dumps(obj)
    chunks = list(_chunked(raw, chunk_size))

    if nowait:
        conn.stream_nowait(serde=SerdeFormat.OPAQUE).receive_chunk(iter(chunks))
    else:
        conn.stream(timeout=TIMEOUT, serde=SerdeFormat.OPAQUE).receive_chunk(
            iter(chunks)
        )

    # get_result() is queued AFTER all chunks on the same connection — FIFO
    # guarantees it is processed last even for stream_nowait.
    assembled = conn.rpc(timeout=TIMEOUT).get_result()
    assert isinstance(assembled, bytes), "service must return bytes"
    assert assembled == raw, (
        f"assembled {len(assembled)} bytes != original {len(raw)} bytes"
    )
    return pickle.loads(assembled)


# ── subprocess entry points ───────────────────────────────────────────────────

def _proc_chunked_service(port: int, app_name: str = "chunk-svc") -> None:
    """Service subprocess: accumulates OPAQUE chunks, returns on demand."""
    silence_subprocess()
    from daffi import Service, callback

    _buf: bytearray = bytearray()

    @callback
    def receive_chunk(data: bytes) -> None:
        """Append one raw chunk to the in-memory buffer."""
        _buf.extend(data)

    @callback
    def get_result() -> bytes:
        """Return the full assembled buffer; leave it intact for inspection."""
        return bytes(_buf)

    @callback
    def reset() -> None:
        """Clear the buffer so the service can accept a new transfer."""
        _buf.clear()

    svc = Service(app_name=app_name, host=HOST, port=port)
    svc.start()
    svc.join()


def _proc_chunked_worker(port: int, app_name: str = "chunk-worker") -> None:
    """Worker subprocess for router-topology tests."""
    silence_subprocess()
    import time as _time
    from daffi import Client, callback

    _buf: bytearray = bytearray()

    @callback
    def receive_chunk(data: bytes) -> None:
        _buf.extend(data)

    @callback
    def get_result() -> bytes:
        return bytes(_buf)

    @callback
    def reset() -> None:
        _buf.clear()

    client = Client(app_name=app_name, host=HOST, port=port)
    client.connect()
    try:
        while True:
            _time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        client.stop()


def _proc_router(port: int, app_name: str = "chunk-router") -> None:
    silence_subprocess()
    from daffi import Router

    r = Router(app_name=app_name, host=HOST, port=port)
    r.start()
    r.join()


# ── fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def chunked_service(free_port):
    """Direct-layout: fresh Service subprocess with chunk callbacks."""
    proc = mp.Process(
        target=_proc_chunked_service, args=(free_port,), daemon=True
    )
    proc.start()
    wait_for_port(free_port)
    time.sleep(0.15)
    yield free_port
    quiet_kill(proc)


@pytest.fixture
def chunked_router(free_port):
    """Router-layout: Router + Worker subprocess with chunk callbacks."""
    rproc = mp.Process(target=_proc_router, args=(free_port,), daemon=True)
    rproc.start()
    wait_for_port(free_port)

    wproc = mp.Process(
        target=_proc_chunked_worker, args=(free_port,), daemon=True
    )
    wproc.start()
    wait_for_members(free_port, {"chunk-worker"})
    yield free_port
    quiet_kill(wproc)
    quiet_kill(rproc)


def _connect(port: int, name: str):
    from daffi import Client

    client = Client(app_name=name, host=HOST, port=port)
    conn = client.connect()
    return client, conn


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 1 — stream() with backpressure (direct layout)
# ══════════════════════════════════════════════════════════════════════════════

class TestStreamBackpressure:
    """conn.stream() sends one chunk at a time and waits for an ack before
    proceeding to the next.  Natural backpressure prevents queue build-up."""

    def test_bytes_single_chunk(self, chunked_service):
        """A bytes object small enough to fit in one chunk is reassembled intact."""
        client, conn = _connect(chunked_service, "cs-bytes-1")
        try:
            original = bytes(range(256)) * 4   # 1 KiB
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
        finally:
            client.stop()

    def test_bytes_multi_chunk(self, chunked_service):
        """A bytes object split across multiple 64 KiB chunks is reassembled."""
        client, conn = _connect(chunked_service, "cs-bytes-n")
        try:
            original = bytes(range(256)) * 1024   # 256 KiB → 4 chunks of 64 KiB
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
        finally:
            client.stop()

    def test_large_list(self, chunked_service):
        """A large list of integers (pickled ~400 KiB) survives chunked transfer."""
        client, conn = _connect(chunked_service, "cs-list")
        try:
            original = list(range(LARGE_LIST_LEN))
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
        finally:
            client.stop()

    def test_nested_dict(self, chunked_service):
        """A richly nested dict with mixed types survives chunked transfer."""
        client, conn = _connect(chunked_service, "cs-dict")
        try:
            original = {
                "ints":    list(range(5_000)),
                "floats":  [i * 0.001 for i in range(1_000)],
                "strings": [f"item-{i}" for i in range(500)],
                "bytes":   bytes(range(256)) * 8,
                "nested":  {"a": {"b": {"c": [True, False, None]}}},
                "unicode": "日本語テスト 🐍 " * 100,
            }
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
        finally:
            client.stop()

    def test_small_chunk_size_many_messages(self, chunked_service):
        """Splitting into many tiny chunks (512 B) still reassembles correctly."""
        client, conn = _connect(chunked_service, "cs-tiny")
        try:
            original = list(range(10_000))
            recovered = _round_trip(conn, original, chunk_size=512)
            assert recovered == original
        finally:
            client.stop()

    def test_single_large_chunk(self, chunked_service):
        """Payload fits in one chunk of 1 MiB (tests single-message large transfer)."""
        client, conn = _connect(chunked_service, "cs-1mib")
        try:
            original = bytes(range(256)) * 4096   # 1 MiB of cyclic bytes
            recovered = _round_trip(conn, original, chunk_size=1 << 20)
            assert recovered == original
        finally:
            client.stop()

    def test_payload_types_preserved(self, chunked_service):
        """Python types that survive pickle (tuple, set, bool, None) are preserved."""
        client, conn = _connect(chunked_service, "cs-types")
        try:
            original = {
                "tuple":  (1, "two", 3.0),
                "set":    {10, 20, 30},
                "bool_t": True,
                "bool_f": False,
                "none":   None,
                "bytes":  b"\x00\xde\xad\xbe\xef",
            }
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
            assert isinstance(recovered["tuple"], tuple)
            assert isinstance(recovered["set"], (set, frozenset))
        finally:
            client.stop()

    def test_unicode_heavy_payload(self, chunked_service):
        """Multi-byte Unicode strings (CJK, emoji) survive the binary round-trip."""
        client, conn = _connect(chunked_service, "cs-unicode")
        try:
            original = {
                "cjk":   "你好世界" * 500,
                "emoji": "🐍🦊🎉" * 300,
                "rtl":   "مرحبا بالعالم" * 200,
            }
            recovered = _round_trip(conn, original, chunk_size=8 * 1024)
            assert recovered == original
        finally:
            client.stop()

    def test_varying_chunk_sizes_same_payload(self, chunked_service):
        """The same payload chunked at 1 KiB, 64 KiB, and 256 KiB all round-trip
        correctly — verifying the service accumulation is chunk-size agnostic."""
        original = list(range(20_000))
        for cs_label, chunk_size in [("1k", 1024), ("64k", CHUNK_SIZE), ("256k", 256 * 1024)]:
            client, conn = _connect(chunked_service, f"cs-vary-{cs_label}")
            try:
                recovered = _round_trip(conn, original, chunk_size=chunk_size)
                assert recovered == original, f"mismatch at chunk_size={chunk_size}"
                conn.rpc(timeout=TIMEOUT).reset()   # clear buffer for next iteration
            finally:
                client.stop()


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 2 — stream_nowait() fire-and-forget (direct layout)
# ══════════════════════════════════════════════════════════════════════════════

class TestStreamNowait:
    """conn.stream_nowait() enqueues all chunks without waiting for acks.

    FIFO ordering guarantee: all stream_nowait messages and the subsequent
    ``get_result()`` RPC are sent on the same TCP connection.  Because TCP is
    ordered and the service task queue is FIFO, ``get_result()`` is always
    processed after every preceding chunk, regardless of service processing speed.
    """

    def test_basic_fifo_ordering(self, chunked_service):
        """Chunks sent fire-and-forget arrive in send order; result is correct."""
        client, conn = _connect(chunked_service, "cnw-basic")
        try:
            original = list(range(LARGE_LIST_LEN))
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE, nowait=True)
            assert recovered == original
        finally:
            client.stop()

    def test_many_small_chunks_ordering(self, chunked_service):
        """Hundreds of tiny chunks sent nowait still arrive in order."""
        client, conn = _connect(chunked_service, "cnw-tiny")
        try:
            # 512-byte chunks from a 100 KiB payload → ~200 messages
            original = bytes(range(256)) * 400
            recovered = _round_trip(conn, original, chunk_size=512, nowait=True)
            assert recovered == original
        finally:
            client.stop()

    def test_nowait_bytes_integrity(self, chunked_service):
        """Raw bytes (non-ASCII) transferred nowait arrive byte-perfect."""
        client, conn = _connect(chunked_service, "cnw-bytes")
        try:
            original = bytes(range(256)) * 256   # 64 KiB of every byte value
            recovered = _round_trip(conn, original, chunk_size=8 * 1024, nowait=True)
            assert recovered == original
        finally:
            client.stop()

    def test_nowait_complex_object(self, chunked_service):
        """A complex nested dict transferred nowait is fully recovered."""
        client, conn = _connect(chunked_service, "cnw-dict")
        try:
            original = {
                "data":    list(range(10_000)),
                "meta":    {"version": 42, "flag": True},
                "payload": bytes(range(256)) * 32,
            }
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE, nowait=True)
            assert recovered == original
        finally:
            client.stop()


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 3 — stream() via Router (two-hop layout)
# ══════════════════════════════════════════════════════════════════════════════

class TestStreamViaRouter:
    """Same data-integrity checks through the Router → Worker hop."""

    def test_bytes_multi_chunk_via_router(self, chunked_router):
        """Multi-chunk bytes transfer via Router reassembles correctly."""
        client, conn = _connect(chunked_router, "cr-bytes")
        try:
            original = bytes(range(256)) * 1024   # 256 KiB
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
        finally:
            client.stop()

    def test_large_list_via_router(self, chunked_router):
        """Large list transferred in chunks via Router round-trips intact."""
        client, conn = _connect(chunked_router, "cr-list")
        try:
            original = list(range(LARGE_LIST_LEN))
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
        finally:
            client.stop()

    def test_stream_nowait_via_router(self, chunked_router):
        """stream_nowait chunks sent via Router arrive in order."""
        client, conn = _connect(chunked_router, "cr-nowait")
        try:
            original = list(range(LARGE_LIST_LEN))
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE, nowait=True)
            assert recovered == original
        finally:
            client.stop()


# ══════════════════════════════════════════════════════════════════════════════
# Scenario 4 — edge cases
# ══════════════════════════════════════════════════════════════════════════════

class TestEdgeCases:
    """Boundary conditions that stress the chunking and reassembly logic."""

    def test_empty_object(self, chunked_service):
        """Pickling an empty list produces a tiny payload; the round-trip works."""
        client, conn = _connect(chunked_service, "ce-empty")
        try:
            original = []
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
        finally:
            client.stop()

    def test_single_byte_payload(self, chunked_service):
        """A one-byte payload (pickled int) travels intact."""
        client, conn = _connect(chunked_service, "ce-1byte")
        try:
            original = 0
            recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
            assert recovered == original
        finally:
            client.stop()

    def test_chunk_size_equals_payload_size(self, chunked_service):
        """When chunk_size == len(raw), exactly one chunk is sent."""
        client, conn = _connect(chunked_service, "ce-exact")
        try:
            original = list(range(1_000))
            raw = pickle.dumps(original)
            # chunk_size exactly equals total payload — yields exactly 1 chunk
            recovered = _round_trip(conn, original, chunk_size=len(raw))
            assert recovered == original
        finally:
            client.stop()

    def test_chunk_size_off_by_one(self, chunked_service):
        """chunk_size = payload_size - 1 forces a two-chunk transfer."""
        client, conn = _connect(chunked_service, "ce-obo")
        try:
            original = list(range(1_000))
            raw = pickle.dumps(original)
            # One byte spills into a second chunk
            recovered = _round_trip(conn, original, chunk_size=len(raw) - 1)
            assert recovered == original
        finally:
            client.stop()

    def test_multi_object_sequential_transfers(self, chunked_service):
        """Two independent transfers on the same connection, with reset between them,
        both round-trip correctly — verifying reset() clears state fully."""
        client, conn = _connect(chunked_service, "ce-seq")
        try:
            for i, original in enumerate([list(range(5_000)), {"x": bytes(256)}]):
                recovered = _round_trip(conn, original, chunk_size=CHUNK_SIZE)
                assert recovered == original, f"transfer {i} corrupted"
                conn.rpc(timeout=TIMEOUT).reset()
        finally:
            client.stop()
