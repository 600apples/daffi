"""
``js-client/daffi.js`` run in QuickJS against a mock WebSocket and a mock of
the wasm exports, with virtual timers.

Each test fails on the behaviour that used to happen:

* a reply that arrived after its call timed out was kept, and resolved a
  later call that reused the uuid;
* a socket that failed to open or handshake stayed alive and its handlers
  fed frames into, or closed, the connection that replaced it;
* calls made while disconnected were dropped silently and never settled;
* a throwing event handler (or a reply that could not be decoded) threw
  through the wasm frame, skipping its cleanup and the other handlers;
* after ``stop()`` autoreconnect stayed off for good;
* the cast receiver filter matched by prefix (``w1`` matched ``w10``).
"""

from __future__ import annotations

from pathlib import Path

import pytest

quickjs = pytest.importorskip("quickjs")

DAFFI_JS = Path(__file__).resolve().parents[2] / "js-client" / "daffi.js"

PRELUDE = r"""
var console = { log() {}, warn() {}, errors: [], error(...a) { console.errors.push(a.map(String).join(' ')); } };
var document = { currentScript: null };
var location = { href: 'http://localhost/a/b/page.html', hostname: 'localhost' };
class URL {
    constructor(rel, base) { this.href = String(base) + '|' + rel; }
    toString() { return this.href; }
}
function fetch() { return {}; }

class TextEncoder {
    encode(s = '') {
        const out = [];
        for (const ch of String(s)) {
            const c = ch.codePointAt(0);
            if (c < 0x80) out.push(c);
            else if (c < 0x800) out.push(0xc0 | c >> 6, 0x80 | c & 63);
            else if (c < 0x10000) out.push(0xe0 | c >> 12, 0x80 | c >> 6 & 63, 0x80 | c & 63);
            else out.push(0xf0 | c >> 18, 0x80 | c >> 12 & 63, 0x80 | c >> 6 & 63, 0x80 | c & 63);
        }
        return new Uint8Array(out);
    }
}
class TextDecoder {
    decode(b) {
        if (!b) return '';
        let s = '', i = 0;
        while (i < b.length) {
            const c = b[i++];
            if (c < 0x80) s += String.fromCharCode(c);
            else if (c < 0xe0) s += String.fromCharCode((c & 31) << 6 | b[i++] & 63);
            else if (c < 0xf0) s += String.fromCharCode((c & 15) << 12 | (b[i++] & 63) << 6 | b[i++] & 63);
            else s += String.fromCodePoint((c & 7) << 18 | (b[i++] & 63) << 12 | (b[i++] & 63) << 6 | b[i++] & 63);
        }
        return s;
    }
}

let __now = 0, __seq = 0;
const __timers = new Map();
function setTimeout(fn, ms) { const id = ++__seq; __timers.set(id, { at: __now + (ms || 0), fn, id }); return id; }
function clearTimeout(id) { __timers.delete(id); }
function __tick() {
    let next = null;
    for (const t of __timers.values()) {
        if (!next || t.at < next.at || (t.at === next.at && t.id < next.id)) next = t;
    }
    if (!next) return false;
    __timers.delete(next.id);
    __now = Math.max(__now, next.at);
    next.fn();
    return true;
}
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

const sockets = [];
class WebSocket {
    constructor(url) {
        this.url = url; this.readyState = 0; this.sent = []; this.closeCalls = 0;
        this.onopen = this.onclose = this.onerror = this.onmessage = null;
        sockets.push(this);
    }
    send(data) {
        if (this.readyState !== 1) throw new Error('InvalidStateError');
        this.sent.push(new Uint8Array(data).slice());
    }
    close() {
        this.closeCalls++;
        if (this.readyState === 3) return;
        this.readyState = 3;
        setTimeout(() => { if (this.onclose) this.onclose({ code: 1000 }); }, 0);
    }
    _open() { this.readyState = 1; if (this.onopen) this.onopen(); }
    _serverClose() { this.readyState = 3; if (this.onclose) this.onclose({ code: 1006 }); }
    _deliver(obj) {
        const b = new TextEncoder().encode(JSON.stringify(obj));
        if (this.onmessage) this.onmessage({ data: b.buffer });
    }
}
WebSocket.CONNECTING = 0; WebSocket.OPEN = 1; WebSocket.CLOSING = 2; WebSocket.CLOSED = 3;

const mock = {
    heap: new ArrayBuffer(1 << 22), top: 8, uuid: 1, version: 1, members: [], sent: [],
    handshakes: [], completed: 0, memberCalls: 0, failSend: null, imports: null, err: null, errPtr: 0,
};
mock.u8 = () => new Uint8Array(mock.heap);
mock.nextUuid = () => { const u = mock.uuid; mock.uuid = (mock.uuid + 1) & 0xffff; return u; };
function alloc(n) {
    if (mock.top + n + 8 > mock.heap.byteLength) mock.top = 8;
    const p = mock.top;
    mock.top += (n + 8) & ~7;
    return p;
}
const readStr = (p, n) => new TextDecoder().decode(new Uint8Array(mock.heap, p, n));
function writeBytes(bytes) { const p = alloc(bytes.length); mock.u8().set(bytes, p); return p; }
function setError(msg) { mock.err = new TextEncoder().encode(msg); mock.errPtr = writeBytes(mock.err); }
const enc = (s) => new TextEncoder().encode(s);

const mockExports = {
    memory: { get buffer() { return mock.heap; } },
    allocUint8: alloc,
    free() {},
    freeSendResult() {},
    stopClient() {},
    lastErrorPtr: () => mock.errPtr,
    lastErrorLen: () => mock.err.length,
    membersVersion: () => mock.version,
    initClient: () => 1,
    sendHandshake() {
        const uuid = mock.nextUuid();
        const f = enc('hs');
        mock.imports.window._sendToSocket(writeBytes(f), f.length);
        mock.handshakes.push(uuid);
        return uuid;
    },
    sendMessage(dp, dl, rp, rl, fp, fl, serde, rr) {
        const receiver = readStr(rp, rl), func = readStr(fp, fl);
        if (mock.failSend) { setError(mock.failSend); return 0; }
        const actual = receiver || 'svc';
        const uuid = mock.nextUuid();
        const frame = enc(func);
        mock.imports.window._sendToSocket(writeBytes(frame), frame.length);
        mock.sent.push({ uuid, receiver: actual, func, serde, rr });
        const rb = enc(actual);
        const rptr = writeBytes(rb);
        const res = alloc(16);
        const v = new DataView(mock.heap, res, 16);
        v.setUint32(0, uuid, true); v.setUint32(4, rb.length, true);
        v.setUint32(8, rptr, true); v.setUint32(12, serde === 1 ? 1 : 0, true);
        return res;
    },
    getAvailableMembers() {
        mock.memberCalls++;
        const b = enc(JSON.stringify({ meta: {}, members: mock.members }));
        const p = alloc(b.length + 1);
        mock.u8().set(b, p);
        mock.u8()[p + b.length] = 0;
        return p;
    },
    parseAndStoreMessage(p, n) {
        const msg = JSON.parse(readStr(p, n));
        if (msg.event) {
            mock.version++;
            const b = enc(JSON.stringify(msg.event));
            mock.imports.window._triggerEvent(writeBytes(b), b.length);
        } else {
            const b = msg.raw ? new Uint8Array(msg.raw) : enc(msg.data);
            mock.imports.window._storeMessage(writeBytes(b), b.length, msg.uuid, !!msg.isError, msg.decoder);
        }
        mock.completed++;
        return 0;
    },
};
var WebAssembly = {
    async compileStreaming() { return {}; },
    async compile() { return {}; },
    async instantiate(_, imports) { mock.imports = imports; return { exports: mockExports }; },
};

const flush = () => sleep(0);
const reply = (uuid, value) => ({ uuid, decoder: 1, data: JSON.stringify({ args: [value], kwargs: {} }) });
async function connect(client) {
    const p = client.connect();
    await flush();
    const ws = sockets[sockets.length - 1];
    ws._open();
    await flush();
    ws._deliver({ uuid: mock.handshakes[mock.handshakes.length - 1], decoder: 1,
                  data: JSON.stringify({ meta: { type: 'router' }, members: [] }) });
    return [await p, ws];
}
async function settle(promise) {
    try { return ['ok', await promise]; } catch (e) { return ['err', String(e && e.message || e)]; }
}
function check(cond, what) { if (!cond) throw new Error('check failed: ' + what); }
"""


def _run(body: str) -> None:
    ctx = quickjs.Context()
    ctx.eval(PRELUDE)
    ctx.eval(DAFFI_JS.read_text(encoding="utf-8"))
    ctx.eval(
        "var __done = false, __error = null;"
        f"(async () => {{ {body} }})().then("
        "() => { __done = true; },"
        "(e) => { __error = String(e) + '\\n' + (e && e.stack || ''); __done = true; });"
    )
    for _ in range(100_000):
        while ctx.execute_pending_job():
            pass
        if ctx.eval("__done"):
            break
        if not ctx.eval("__tick()"):
            pytest.fail("the script is stuck: no job and no timer left")
    assert ctx.eval("__error") is None, ctx.eval("__error")


def test_late_reply_is_dropped_and_cannot_resolve_a_later_call():
    _run("""
        const client = new DaffiClient('js', { wsUrl: 'ws://x' });
        const [conn, ws] = await connect(client);
        const timedOut = settle(conn.rpc({ serde: 'json', timeout: 100 }).f());
        const oldUuid = mock.sent[mock.sent.length - 1].uuid;
        await sleep(150);
        check((await timedOut)[1] === 'Operation timed out', 'timeout');
        ws._deliver(reply(oldUuid, 'old'));
        check(Object.keys(client.pendingMessages).length === 0, 'late reply kept');

        mock.uuid = oldUuid;  // the u16 counter came round
        const next = conn.rpc({ serde: 'json' }).f();
        check(mock.sent[mock.sent.length - 1].uuid === oldUuid, 'uuid reused');
        ws._deliver(reply(oldUuid, 'new'));
        check((await next) === 'new', 'later call got its own reply');
    """)


def test_calls_while_disconnected_reject_at_once():
    _run("""
        const client = new DaffiClient('js', { wsUrl: 'ws://x' });
        const [conn, ws] = await connect(client);
        const rpc = conn.rpc({ serde: 'json' });
        const nowait = conn.stream_nowait();
        const waiting = settle(rpc.f());
        ws._serverClose();
        check((await waiting)[1] === 'Connection closed unexpectedly', 'pending rejected');
        check((await settle(rpc.f()))[1] === 'Connection is closed', 'rpc rejected');
        let threw = null;
        try { nowait.f([enc('x')]); } catch (e) { threw = e.message; }
        check(threw === 'Connection is closed', 'stream_nowait threw');
        threw = null;
        try { conn.rpc(); } catch (e) { threw = e.message; }
        check(threw === 'Connection is closed', 'proxy creation');
    """)


def test_send_failure_is_reported_by_the_wasm_error():
    _run("""
        const client = new DaffiClient('js', { wsUrl: 'ws://x' });
        const [conn] = await connect(client);
        mock.failSend = 'failed to create message: error.ReceiverNotFound';
        const out = await settle(conn.rpc({ serde: 'json', receiver: 'nobody' }).f());
        check(out[0] === 'err' && out[1].includes('ReceiverNotFound'), out[1]);
    """)


def test_failed_open_and_handshake_discard_the_socket():
    _run("""
        const client = new DaffiClient('js', { wsUrl: 'ws://x', autoreconnect: true });
        const first = settle(client.connect());
        await flush();
        const ws1 = sockets[0];
        await sleep(8001);
        check((await first)[1].includes('open timeout'), 'open timeout');
        check(ws1.closeCalls === 1 && ws1.onmessage === null && ws1.onclose === null, 'ws1 discarded');

        const second = settle(client.connect());
        await flush();
        const ws2 = sockets[1];
        ws2._open();
        await sleep(5001);
        check((await second)[1] === 'Operation timed out', 'handshake timeout');
        check(ws2.closeCalls === 1 && ws2.onclose === null && client.closed, 'ws2 discarded');

        const staleMessage = ws2.onmessage;
        const [conn, ws3] = await connect(client);
        const waiting = settle(conn.rpc({ serde: 'json' }).f());
        const uuid = mock.sent[mock.sent.length - 1].uuid;
        // Frames or a close from an older socket do not touch this connection.
        if (staleMessage) staleMessage({ data: enc(JSON.stringify(reply(uuid, 'stale'))).buffer });
        check(Object.keys(client.pendingMessages).length === 1, 'stale frame ignored');
        ws3._deliver(reply(uuid, 'fresh'));
        check((await waiting)[1] === 'fresh', 'own reply');
        check(sockets.length === 3, 'no reconnect scheduled');
    """)


def test_throwing_handlers_and_bad_replies_do_not_escape_into_wasm():
    _run("""
        const client = new DaffiClient('js', { wsUrl: 'ws://x' });
        const [conn, ws] = await connect(client);
        const seen = [];
        client.addEventHandler(() => { throw new Error('boom'); });
        client.addEventHandler((e) => seen.push(e.member));
        const before = mock.completed;
        ws._deliver({ event: { type: 'connected', member: 'w1' } });
        check(mock.completed === before + 1, 'parseAndStoreMessage returned');
        check(seen.length === 1 && seen[0] === 'w1', 'second handler ran');
        check(console.errors.some(e => e.includes('boom')), 'reported');

        const bad = settle(conn.rpc().f());
        const uuid = mock.sent[mock.sent.length - 1].uuid;
        ws._deliver({ uuid, decoder: 3, raw: [0xc1] });
        check(mock.completed === before + 2, 'returned after a bad reply');
        check((await bad)[1].startsWith('Could not decode the reply'), 'rejected');
    """)


def test_connect_after_stop_turns_autoreconnect_back_on():
    _run("""
        const client = new DaffiClient('js', { wsUrl: 'ws://x', autoreconnect: true, reconnectDelay: 10 });
        await connect(client);
        client.stop();
        const [, ws] = await connect(client);
        const count = sockets.length;
        ws._serverClose();
        await sleep(20);
        check(sockets.length === count + 1, 'reconnected');
    """)


def test_cast_filter_matches_names_exactly_and_members_are_cached():
    _run("""
        const client = new DaffiClient('js', { wsUrl: 'ws://x' });
        const [conn, ws] = await connect(client);
        mock.members = [{ name: 'w1', methods: ['f'] }, { name: 'w10', methods: ['f'] }];
        mock.version++;
        const calls = mock.memberCalls;
        conn.cast_nowait({ receiver: 'w1' }).f(1);
        conn.cast_nowait({ receiver: ['w1'] }).f(2);
        check(mock.sent.slice(-2).every(s => s.receiver === 'w1'), 'exact match');
        check(mock.memberCalls === calls + 1, 'member list read once');
        ws._deliver({ event: { type: 'disconnected', member: 'w10' } });
        conn.cast_nowait().f(3);
        check(mock.memberCalls === calls + 2, 're-read after an event');
    """)


def test_msgpack_round_trip_matches_python():
    msgpack = pytest.importorskip("msgpack")
    value = [
        [
            1,
            -1,
            -33,
            200,
            -200,
            70000,
            -70000,
            2**40,
            1.5,
            "h\u00e9",
            "x" * 40,
            True,
            None,
            list(range(20)),
            {"k": [1, 2]},
        ],
        {},
    ]
    ctx = quickjs.Context()
    ctx.eval(PRELUDE)
    ctx.eval(DAFFI_JS.read_text(encoding="utf-8"))
    ctx.eval(
        "var v = [[1, -1, -33, 200, -200, 70000, -70000, 2 ** 40, 1.5, 'h\\u00e9', 'x'.repeat(40),"
        " true, null, Array.from({ length: 20 }, (_, i) => i), { k: [1, 2] }], {}];"
        "var big = 'y'.repeat(70000);"
    )
    js = bytes(map(int, ctx.eval("Array.from(_mp.encode(v)).join(',')").split(",")))
    assert js == msgpack.packb(value, use_bin_type=True)
    assert ctx.eval("JSON.stringify(_mp.decode(_mp.encode(v))) === JSON.stringify(v)")
    assert ctx.eval("_mp.decode(_mp.encode(big)) === big")


def test_replies_are_decoded_per_format_and_stream_waits_per_chunk():
    _run("""
        const client = new DaffiClient('js', { wsUrl: 'ws://x' });
        const [conn, ws] = await connect(client);
        const last = () => mock.sent[mock.sent.length - 1].uuid;

        const bin = conn.rpc({ serde: 'raw' }).f(new Uint8Array([0, 0xff, 7]));
        ws._deliver({ uuid: last(), decoder: 0, raw: [0, 0xff, 7] });
        const b = await bin;
        check(b instanceof Uint8Array && b.length === 3 && b[1] === 0xff, 'binary reply');
        check(b.buffer !== mock.heap, 'binary reply is a copy');

        const text = conn.rpc({ serde: 'raw' }).f('q');
        ws._deliver({ uuid: last(), decoder: 0, data: ' {"a": 1}' });
        check((await text).a === 1, 'JSON text reply parsed');

        const notJson = conn.rpc({ serde: 'raw' }).f('q');
        ws._deliver({ uuid: last(), decoder: 0, data: '1x' });
        check((await notJson) instanceof Uint8Array, 'invalid JSON stays bytes');

        const packed = conn.rpc().f(1, 'two');
        ws._deliver({ uuid: last(), decoder: 3, raw: Array.from(_mp.encode([['ok'], {}])) });
        check((await packed) === 'ok', 'msgpack reply');

        let done = false;
        const streaming = conn.stream().f([enc('a'), enc('b')]).then(() => { done = true; });
        await flush();
        check(mock.sent[mock.sent.length - 1].func === 'f' && !done, 'first chunk waits');
        const firstChunk = last();
        ws._deliver({ uuid: firstChunk, decoder: 0, data: 'x' });
        await flush();
        check(last() !== firstChunk && !done, 'second chunk sent after the ack');
        ws._deliver({ uuid: last(), decoder: 0, data: 'x' });
        await streaming;
    """)
