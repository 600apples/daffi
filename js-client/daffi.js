'use strict';

/**
 * DaffiClient — browser WebSocket + WASM client for daffi.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DISTRIBUTION — loading daffi.js from the CDN
 * ─────────────────────────────────────────────────────────────────────────────
 * Load daffi.js from jsDelivr.  app.wasm is fetched automatically from the
 * same CDN release — you do NOT need to host or specify it yourself.
 *
 *   <!-- Load the JS client (pin to a specific release tag). MessagePack is built in. -->
 *   <script src="https://cdn.jsdelivr.net/gh/600apples/daffi@4.0.0/js-client/daffi.js"></script>
 *
 *   <script>
 *     // wsUrl is REQUIRED — there is no default.
 *     const client = new DaffiClient("my-app", { wsUrl: "ws://127.0.0.1:5000" });
 *   </script>
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * QUICK START
 * ─────────────────────────────────────────────────────────────────────────────
 *   // Explicit name:
 *   const client = new DaffiClient("my-app", { wsUrl: "ws://127.0.0.1:5000" });
 *   // Auto-generated name ("localhost-0x3f9a12bc"):
 *   const client = new DaffiClient({ wsUrl: "ws://127.0.0.1:5000" });
 *   const conn   = await client.connect();
 *
 *   // Call a remote function and get the result
 *   const sum = await conn.rpc({ timeout: 5000 }).add(3, 4);
 *
 *   // Fire-and-forget (no result)
 *   conn.rpc_nowait().log("hello");
 *
 *   // Broadcast to every peer that exposes the method, collect all results
 *   const all = await conn.cast({ timeout: 5000 }).add(3, 4);
 *   // → { "worker-1": 7, "worker-2": 7 }
 *
 *   // Fire-and-forget broadcast
 *   conn.cast_nowait().notify("event");
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DaffiClient([name,] options)
 * ─────────────────────────────────────────────────────────────────────────────
 *   name              string   — Unique name for this browser client.
 *                                Optional.  When omitted, a name is generated
 *                                automatically as  "hostname-0x<random32>"
 *                                (e.g. "localhost-0x3f9a12bc"), mirroring the
 *                                auto-naming behaviour of the Python client.
 *
 *   options.wsUrl     string   — REQUIRED. WebSocket URL of the daffi Service
 *                                or Router.  No default — must always be set
 *                                explicitly (e.g. "ws://127.0.0.1:5000").
 *
 *   options.autoreconnect  boolean — When true, automatically reconnect to the
 *                                    server after a disconnect.  The first retry
 *                                    happens after reconnectDelay ms; subsequent
 *                                    retries use exponential back-off (capped at
 *                                    60 s).  Default: false.
 *
 *   options.reconnectDelay number (ms) — Base reconnect delay.  Default: 2000.
 *
 *   options.authToken string — Shared secret for a server started with
 *                              ``auth_token=``.  Anyone who can read this
 *                              page can read it, so it only keeps out
 *                              clients that were never given the page.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * client.connect() → Promise<Connection>
 * ─────────────────────────────────────────────────────────────────────────────
 *   Connect to the server and perform the handshake.  Use ``wss://`` in
 *   ``wsUrl`` (and run the Python backend with ``tls=True``) to encrypt and
 *   authenticate the channel — no application-level secret is required.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * client.addEventHandler(fn)
 * ─────────────────────────────────────────────────────────────────────────────
 *   Subscribe to server-side events.  fn receives an event object:
 *     { type: "connected" | "disconnected" | "evicted", member: string }
 *
 *   "evicted" fires when this client is displaced by a new connection with the
 *   same app_name (last-connection-wins).  Autoreconnect is suppressed for this
 *   event — the client is closed intentionally.
 *
 *   Example:
 *     client.addEventHandler(e => console.log(e.type, e.member));
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Connection methods  (returned by client.connect())
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   conn.rpc(options) → Proxy
 *     Call a single remote function and await the result.
 *     Returns a Proxy — call any method name on it to issue the RPC.
 *
 *     options.receiver  string         — Pin call to a specific peer name.
 *                                        Omit to let the server pick any peer.
 *     options.timeout   number (ms)    — Reject if no reply within this time.
 *     options.serde     string|number  — Serialisation format (see SERDE below).
 *
 *   conn.rpc_nowait(options) → Proxy
 *     Fire-and-forget: send the call, do not wait for a result.
 *     Same options as rpc() except timeout is ignored.
 *
 *   conn.cast(options) → Proxy
 *     Broadcast to EVERY connected peer that exposes the method.
 *     Awaits all results and returns { workerName: result, … }.
 *
 *     options.receiver  string|string[] — Restrict broadcast to these peer names.
 *     options.timeout   number (ms)     — Per-peer timeout.
 *     options.serde     string|number   — Serialisation format (see SERDE below).
 *
 *   conn.cast_nowait(options) → Proxy
 *     Fire-and-forget broadcast to all matching peers.  No result.
 *     Same options as cast() except timeout is ignored.
 *
 *   conn.stream(options) → Promise (async, blocking per chunk)
 *     Iterates an iterable and awaits the remote ack for each chunk before
 *     sending the next one.  Provides natural backpressure.
 *     Default serde: "raw".  Returns a Promise resolving when all chunks are sent.
 *       await conn.stream({ serde: "raw" }).receive_chunk([buf1, buf2]);
 *
 *   conn.stream_nowait(options) → void (fire-and-forget per chunk)
 *     Iterates an iterable and sends each chunk without waiting for a reply.
 *     No backpressure — producer can outpace consumer.
 *     Default serde: "raw".
 *       conn.stream_nowait({ serde: "raw" }).receive_chunk([buf1, buf2]);
 *
 *   conn.waitForMembers(members, options?) → Promise<void>
 *     Block (async) until all listed peer names are visible in the network.
 *     Use this to synchronise a multi-worker scenario before issuing calls
 *     that depend on specific peers being online.
 *
 *     members               string | string[]  — peer name(s) to wait for.
 *     options.timeout       number (ms) | null — max wait; null = forever.
 *     options.interval      number (ms)        — poll interval. Default: 1000.
 *
 *     Example:
 *       await conn.waitForMembers('python-worker');
 *       await conn.waitForMembers(['w1', 'w2'], { timeout: 30000 });
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SERDE — serialisation formats
 * ─────────────────────────────────────────────────────────────────────────────
 *   "msgpack" | 3  — MessagePack (default).  Compact binary; works with
 *                    JSON-serialisable values plus Uint8Array / bytes.
 *                    Encoder and decoder are built into this file.
 *
 *   "json"    | 1  — JSON.  Works with any JSON-serialisable value.
 *
 *   "raw"     | 0  — OPAQUE / raw bytes.  Pass a single Uint8Array or string;
 *                    receive a Uint8Array (or parsed JSON if the bytes happen
 *                    to be valid JSON).  Use when the Python side is decorated
 *                    with @callback and expects bytes.
 *
 *   Note: PICKLE (2) is Python-only and is not supported in the JS client.
 */

const _textEnc = new TextEncoder();
const _textDec = new TextDecoder();

// Compact MessagePack codec matching Python msgpack 1.0 (use_bin_type,
// raw=False).  Covers nil/bool/int/float/str/bin/array/map — enough for
// daffi's [args, kwargs] envelope.
const _mp = (() => {
    const textEnc = _textEnc;
    const textDec = _textDec;

    // Encoding writes into one buffer that doubles when full.
    function encode(value) {
        const w = { buf: new Uint8Array(256), view: null, pos: 0 };
        w.view = new DataView(w.buf.buffer);
        write(w, value);
        return w.buf.subarray(0, w.pos);
    }

    function reserve(w, n) {
        if (w.pos + n <= w.buf.length) return;
        let size = w.buf.length * 2;
        while (size < w.pos + n) size *= 2;
        const next = new Uint8Array(size);
        next.set(w.buf.subarray(0, w.pos));
        w.buf = next;
        w.view = new DataView(next.buffer);
    }
    function u8(w, n) { reserve(w, 1); w.buf[w.pos++] = n; }
    function putUint(w, tag, n, bytes) {
        reserve(w, 1 + bytes);
        const at = w.pos + 1;
        w.buf[w.pos] = tag;
        if (bytes === 1) w.view.setUint8(at, n);
        else if (bytes === 2) w.view.setUint16(at, n);
        else if (bytes === 4) w.view.setUint32(at, n);
        else w.view.setBigUint64(at, BigInt(n));
        w.pos = at + bytes;
    }
    function putInt(w, tag, n, bytes) {
        reserve(w, 1 + bytes);
        const at = w.pos + 1;
        w.buf[w.pos] = tag;
        if (bytes === 1) w.view.setInt8(at, n);
        else if (bytes === 2) w.view.setInt16(at, n);
        else if (bytes === 4) w.view.setInt32(at, n);
        else w.view.setBigInt64(at, BigInt(n));
        w.pos = at + bytes;
    }
    function putBytes(w, bytes) {
        reserve(w, bytes.length);
        w.buf.set(bytes, w.pos);
        w.pos += bytes.length;
    }

    function write(w, v) {
        if (v === null || v === undefined) { u8(w, 0xc0); return; }
        if (v === false) { u8(w, 0xc2); return; }
        if (v === true) { u8(w, 0xc3); return; }
        if (typeof v === 'number') {
            if (Number.isInteger(v) && Number.isSafeInteger(v)) {
                if (v >= 0) {
                    if (v <= 0x7f) u8(w, v);
                    else if (v <= 0xff) putUint(w, 0xcc, v, 1);
                    else if (v <= 0xffff) putUint(w, 0xcd, v, 2);
                    else if (v <= 0xffffffff) putUint(w, 0xce, v, 4);
                    else putUint(w, 0xcf, v, 8);
                } else if (v >= -0x20) {
                    u8(w, v & 0xff);
                } else if (v >= -0x80) {
                    putInt(w, 0xd0, v, 1);
                } else if (v >= -0x8000) {
                    putInt(w, 0xd1, v, 2);
                } else if (v >= -0x80000000) {
                    putInt(w, 0xd2, v, 4);
                } else {
                    putInt(w, 0xd3, v, 8);
                }
                return;
            }
            reserve(w, 9);
            w.buf[w.pos] = 0xcb;
            w.view.setFloat64(w.pos + 1, v);
            w.pos += 9;
            return;
        }
        if (typeof v === 'string') {
            const bytes = textEnc.encode(v);
            headerBin(w, bytes.length, 0xa0, 0xd9, 0xda, 0xdb, true);
            putBytes(w, bytes);
            return;
        }
        if (v instanceof ArrayBuffer) v = new Uint8Array(v);
        if (ArrayBuffer.isView(v) && !(v instanceof DataView)) {
            const bytes = new Uint8Array(v.buffer, v.byteOffset, v.byteLength);
            headerBin(w, bytes.length, 0, 0xc4, 0xc5, 0xc6, false);
            putBytes(w, bytes);
            return;
        }
        if (Array.isArray(v)) {
            headerLen(w, v.length, 0x90, 0xdc, 0xdd, 15);
            for (const item of v) write(w, item);
            return;
        }
        if (typeof v === 'object') {
            const keys = Object.keys(v);
            headerLen(w, keys.length, 0x80, 0xde, 0xdf, 15);
            for (const k of keys) { write(w, k); write(w, v[k]); }
            return;
        }
        throw new TypeError(`msgpack: cannot encode ${typeof v}`);
    }

    function headerBin(w, n, fix, t8, t16, t32, isStr) {
        if (isStr && n <= 31) { u8(w, fix | n); return; }
        if (n <= 0xff) putUint(w, t8, n, 1);
        else if (n <= 0xffff) putUint(w, t16, n, 2);
        else putUint(w, t32, n, 4);
    }
    function headerLen(w, n, fix, t16, t32, fixMax) {
        if (n <= fixMax) u8(w, fix | n);
        else if (n <= 0xffff) putUint(w, t16, n, 2);
        else putUint(w, t32, n, 4);
    }

    function decode(bytes) {
        const buf = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
        const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
        let i = 0;
        function need(n) {
            if (i + n > buf.length) throw new RangeError('msgpack: truncated');
        }
        function u(n) {
            need(n);
            let v;
            if (n === 1) v = view.getUint8(i);
            else if (n === 2) v = view.getUint16(i);
            else if (n === 4) v = view.getUint32(i);
            else v = Number(view.getBigUint64(i));
            i += n;
            return v;
        }
        function s(n) {
            need(n);
            let v;
            if (n === 1) v = view.getInt8(i);
            else if (n === 2) v = view.getInt16(i);
            else if (n === 4) v = view.getInt32(i);
            else v = Number(view.getBigInt64(i));
            i += n;
            return v;
        }
        function read() {
            need(1);
            const b = buf[i++];
            if (b <= 0x7f) return b;
            if (b >= 0xe0) return b - 256;
            if (b >= 0xa0 && b <= 0xbf) return str(b & 0x1f);
            if (b >= 0x90 && b <= 0x9f) return arr(b & 0x0f);
            if (b >= 0x80 && b <= 0x8f) return map(b & 0x0f);
            switch (b) {
                case 0xc0: return null;
                case 0xc2: return false;
                case 0xc3: return true;
                case 0xcc: return u(1);
                case 0xcd: return u(2);
                case 0xce: return u(4);
                case 0xcf: return u(8);
                case 0xd0: return s(1);
                case 0xd1: return s(2);
                case 0xd2: return s(4);
                case 0xd3: return s(8);
                case 0xca: { need(4); const v = view.getFloat32(i); i += 4; return v; }
                case 0xcb: { need(8); const v = view.getFloat64(i); i += 8; return v; }
                case 0xd9: return str(u(1));
                case 0xda: return str(u(2));
                case 0xdb: return str(u(4));
                case 0xc4: return bin(u(1));
                case 0xc5: return bin(u(2));
                case 0xc6: return bin(u(4));
                case 0xdc: return arr(u(2));
                case 0xdd: return arr(u(4));
                case 0xde: return map(u(2));
                case 0xdf: return map(u(4));
                default: throw new TypeError(`msgpack: unsupported type 0x${b.toString(16)}`);
            }
        }
        function str(n) {
            need(n);
            const s = textDec.decode(buf.subarray(i, i + n));
            i += n;
            return s;
        }
        function bin(n) {
            need(n);
            const s = buf.slice(i, i + n);
            i += n;
            return s;
        }
        function arr(n) {
            const a = new Array(n);
            for (let k = 0; k < n; k++) a[k] = read();
            return a;
        }
        function map(n) {
            const o = {};
            for (let k = 0; k < n; k++) o[read()] = read();
            return o;
        }
        const value = read();
        return value;
    }

    return { encode, decode };
})();

function _generateClientName() {
    // location.hostname → bare host only ("localhost", "example.com"), no port/protocol.
    const host = (typeof location !== 'undefined' && location.hostname) ? location.hostname : 'browser';
    const bytes = new Uint32Array(1);
    if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
        crypto.getRandomValues(bytes);
    } else {
        bytes[0] = (Math.random() * 0x100000000) >>> 0;
    }
    return `${host}-0x${bytes[0].toString(16).padStart(8, '0')}`;
}

// Build an ordered list of candidate URLs to probe for app.wasm.
//
// CDN loads (jsdelivr / unpkg / cdnjs):
//   Only one candidate — app.wasm next to daffi.js on the CDN.
//
// Local dev (any other origin):
//   1. Script-relative  — same directory as daffi.js  (best case)
//   2. Page-relative climb — walk up two parent dirs from the HTML page.
//      This handles JetBrains / VS Code "open in browser" workflows where
//      the HTML sits inside examples/01_.../ but app.wasm is in js-client/.
const _CDN_RE = /^https?:\/\/(?:cdn\.jsdelivr\.net|unpkg\.com|cdnjs\.cloudflare\.com)\//;

const _WASM_CANDIDATES = (() => {
    const s = document.currentScript;
    const scriptSrc = s && s.src;

    // CDN: single canonical URL
    if (scriptSrc && _CDN_RE.test(scriptSrc))
        return [ new URL('app.wasm', scriptSrc).href ];

    const seen = new Set();
    const list = [];
    const add  = u => { if (!seen.has(u)) { seen.add(u); list.push(u); } };

    // 1. Script-relative (most reliable for proper dev servers)
    if (scriptSrc) add(new URL('app.wasm', scriptSrc).href);

    // 2. Walk up from the current page URL
    let base = new URL('.', location.href);
    for (let i = 0; i < 3; i++) {
        add(new URL('app.wasm', base).href);
        const up = new URL('..', base);
        if (up.href === base.href) break;
        base = up;
    }

    return list;
})();

// _loadWasm() returns a compiled WebAssembly.Module.
// It probes _WASM_CANDIDATES in order, skipping URLs that return a
// non-OK status or an empty body (some IDE servers do this for .wasm).
async function _loadWasm() {
    const errors = [];
    for (const url of _WASM_CANDIDATES) {
        try {
            // compileStreaming is fastest; it needs Content-Type: application/wasm.
            // If it fails (wrong MIME type or IDE quirk) fall through to arrayBuffer.
            let buf = null;
            try {
                const m = await WebAssembly.compileStreaming(fetch(url));
                return m;   // success
            } catch (_) { /* try arrayBuffer below */ }

            const r = await fetch(url, { cache: 'no-store' });
            if (!r.ok) { errors.push(`${url} → HTTP ${r.status}`); continue; }
            buf = await r.arrayBuffer();
            if (!buf.byteLength) { errors.push(`${url} → empty body`); continue; }
            return await WebAssembly.compile(buf);  // success
        } catch (e) {
            errors.push(`${url} → ${e.message}`);
        }
    }
    throw new TypeError(
        `app.wasm could not be loaded. Tried:\n  ${errors.join('\n  ')}\n` +
        `Tip: run  python3 js-client/serve.py  from the project root.`);
}

function DaffiClient(name, options) {
    // Allow DaffiClient(options) — name omitted entirely.
    if (name !== null && typeof name === 'object') { options = name; name = undefined; }
    options = options || {};
    if (!options.wsUrl) throw new Error(
        '[daffi] options.wsUrl is required — there is no default. ' +
        'Pass the WebSocket URL explicitly, e.g. { wsUrl: "ws://127.0.0.1:5000" }.'
    );
    if (options.authToken && (name === undefined || name === null || name === '')) {
        throw new Error('[daffi] options.authToken requires an explicit client name');
    }
    this.name           = name || _generateClientName();
    this.wsUrl          = options.wsUrl;
    this.wasmPath       = _WASM_CANDIDATES[0];  // informational; actual load probes all candidates
    this.autoreconnect  = options.autoreconnect  || false;
    this.reconnectDelay = options.reconnectDelay != null ? options.reconnectDelay : 2000;
    this.authToken      = options.authToken || '';
    // uuid → waiter of a call still expecting its reply.  A reply with no
    // waiter (its call timed out, or nobody made it) is dropped, never kept.
    this.pendingMessages = {};
    this.eventHandlers   = [];
    this.closed = true;
    const self = this;

    // Compiled WASM module reused across reconnects (avoids re-fetching wasm).
    let _module = null;
    // Single WASM instance shared across reconnects so memory helpers remain valid.
    let _wasmExports    = null;
    let _memory         = null;
    // Current active WebSocket.  Handlers of any other socket ignore events.
    let _socket = null;
    // Set to true when stop() is called so reconnect loop does not restart.
    let _intentionalClose = false;
    // Bumped by connect() and stop(): a reconnect scheduled before either
    // gives up.
    let _epoch = 0;
    // Reconnect attempt counter; reset to 0 after a successful connect.
    let _reconnectAttempt = 0;
    // True while a reconnect setTimeout is pending or _connectSocket is running.
    // Prevents duplicate retry chains.
    let _reconnecting = false;
    // Set by _sendToSocket when the socket could not take a frame.
    let _sendFailed = false;
    // Parsed member list and the wasm membersVersion() it was read at.
    let _membersCache = null;
    let _membersVersion = 0;

    const _decodeString = (ptr, len) =>
        _textDec.decode(new Uint8Array(_memory.buffer, ptr, len));

    // Buffers cross into wasm as [ptr, len]: payloads may contain NUL
    // bytes, and wasm frees them by length.
    const _encodeBuffer = (buf) => {
        const len = buf.byteLength;
        const ptr = _wasmExports.allocUint8(len);
        new Uint8Array(_memory.buffer, ptr, len).set(buf);
        return [ptr, len];
    };

    const _encodeString = (str) => _encodeBuffer(_textEnc.encode(str));

    /** The failure an export reported (it returned null, or -1 for numbers). */
    const _wasmError = () => new Error(
        _decodeString(_wasmExports.lastErrorPtr(), _wasmExports.lastErrorLen()).trim());

    // An OPAQUE reply is parsed as JSON only if its first byte can start a
    // JSON value; binary chunks skip the UTF-8 decode and the parse attempt.
    const _JSON_START = new Set(Array.from('{["-0123456789tfn', c => c.charCodeAt(0)));
    const _mayBeJson = (bytes) => {
        let i = 0;
        if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) i = 3;  // BOM
        while (i < bytes.length && (bytes[i] === 0x20 || bytes[i] === 0x09 || bytes[i] === 0x0a || bytes[i] === 0x0d)) i++;
        return i < bytes.length && _JSON_START.has(bytes[i]);
    };

    // decoder: 0=OPAQUE, 1=JSON, 2=PICKLE(unsupported in JS), 3=MSGPACK.
    // Decoding is synchronous and copies what it returns, so no view into
    // wasm memory outlives the call.
    const _decodePayload = (ptr, len, decoder) => {
        const bytes = new Uint8Array(_memory.buffer, ptr, len);
        if (decoder === 3) {
            const decoded = _mp.decode(bytes);
            // Python serialises return value as [[result], {}]
            return Array.isArray(decoded) ? decoded[0][0] : decoded;
        }
        if (decoder === 0) {
            if (_mayBeJson(bytes)) {
                try { return JSON.parse(_textDec.decode(bytes)); } catch (_) { /* binary */ }
            }
            return bytes.slice();
        }
        return JSON.parse(_textDec.decode(bytes));
    };

    const _initWasm = async () => {
        if (_wasmExports) return; // already done

        if (!_module) _module = await _loadWasm();

        // The module defines and exports its own memory.  Always go through
        // `_memory.buffer`: it is replaced whenever the memory grows.
        // The callbacks below must not throw: an exception would unwind the
        // wasm frames without their cleanup.
        const { exports } = await WebAssembly.instantiate(_module, {
            env: {
                // Only reached from a Zig panic, which is not recoverable.
                _throwError(ptr, len) { throw new Error(_decodeString(ptr, len)); },
                _consoleLog(ptr, len)  { console.log(_decodeString(ptr, len));   },
            },
            window: {
                // Always uses _socket so reconnect transparently replaces the socket.
                _sendToSocket(ptr, len) {
                    const ws = _socket;
                    if (ws && ws.readyState === WebSocket.OPEN) {
                        try {
                            // send() copies the bytes before it returns.
                            ws.send(new Uint8Array(_memory.buffer, ptr, len));
                            return;
                        } catch (err) {
                            console.error('[daffi] send failed:', err);
                        }
                    }
                    _sendFailed = true;
                },

                _storeMessage(ptr, len, uuid, isError, decoder) {
                    try {
                        const waiter = self.pendingMessages[uuid];
                        if (!waiter) return;
                        delete self.pendingMessages[uuid];
                        if (waiter.timeoutId) clearTimeout(waiter.timeoutId);
                        let message;
                        try {
                            message = _decodePayload(ptr, len, decoder);
                        } catch (err) {
                            waiter.reject(`Could not decode the reply: ${err.message}`);
                            return;
                        }
                        if (isError) {
                            const args = message && message.args;
                            const errText = (Array.isArray(args) && Array.isArray(args[0]))
                                ? `Remote exception: "${args[0][0]}(${args[0][2]})"`
                                : String(message);
                            waiter.reject(errText);
                        } else {
                            waiter.resolve(message);
                        }
                    } catch (err) {
                        console.error('[daffi] failed to handle a reply:', err);
                    }
                },

                _triggerEvent(ptr, len) {
                    let event;
                    try {
                        event = JSON.parse(_decodeString(ptr, len));
                    } catch (err) {
                        console.error('[daffi] could not decode an event:', err);
                        return;
                    }
                    if (event.type === 'disconnected') {
                        for (const [uuid, msgData] of Object.entries(self.pendingMessages)) {
                            if (msgData.receiver === event.member) {
                                if (msgData.timeoutId) clearTimeout(msgData.timeoutId);
                                delete self.pendingMessages[uuid];
                                msgData.reject(`"${event.member}" disconnected`);
                            }
                        }
                    } else if (event.type === 'evicted') {
                        // This client was evicted — a new connection with the same
                        // app_name took over its slot.  Do not autoreconnect; surface
                        // the error to all in-flight callers and close intentionally.
                        _intentionalClose = true;
                        self.closed = true;
                        const msg = `Evicted: a new connection with app_name "${self.name}" took over this slot.`;
                        _rejectAllPending(msg);
                        if (_socket) _socket.close();
                    }
                    for (const h of self.eventHandlers) {
                        try { h(event); } catch (err) { console.error('[daffi] event handler failed:', err); }
                    }
                },
            },
        });

        _wasmExports = exports;
        _memory = exports.memory;
    };

    /** Reject every waiter: initClient resets the u16 uuid counter, so a
     *  waiter kept across a reconnect could take another call's reply. */
    const _rejectAllPending = (reason) => {
        const waiters = Object.values(self.pendingMessages);
        self.pendingMessages = {};
        for (const msgData of waiters) {
            if (msgData.timeoutId) clearTimeout(msgData.timeoutId);
            try { msgData.reject(reason); } catch (_) {}
        }
    };

    /** Wait for the reply to `uuid`.  Registered before control returns to
     *  the event loop, so the reply cannot arrive first. */
    const _expect = (uuid, timeout, receiver) => new Promise((resolve, reject) => {
        const previous = self.pendingMessages[uuid];
        if (previous) {
            // The u16 uuid came round while that call was still waiting.
            if (previous.timeoutId) clearTimeout(previous.timeoutId);
            previous.reject('Request id reused before its reply arrived');
        }
        const waiter = { resolve, reject, timeoutId: null, receiver, uuid };
        if (timeout) {
            waiter.timeoutId = setTimeout(() => {
                if (self.pendingMessages[uuid] !== waiter) return;
                // Its late reply then finds no waiter and is dropped.
                delete self.pendingMessages[uuid];
                reject('Operation timed out');
            }, timeout);
        }
        self.pendingMessages[uuid] = waiter;
    });

    const _ensureOpen = () => {
        if (self.closed || !_socket || _socket.readyState !== WebSocket.OPEN) {
            throw new Error('Connection is closed');
        }
    };

    /** Members from the native layer, re-read only when a frame changed them. */
    const _fetchMembers = () => {
        const { getAvailableMembers, membersVersion, free } = _wasmExports;
        const version = membersVersion();
        if (_membersCache !== null && version === _membersVersion) return _membersCache;
        const ptr = getAvailableMembers(self.connNum);
        if (!ptr) throw _wasmError();
        const len = new Uint8Array(_memory.buffer, ptr).indexOf(0);
        const json = _decodeString(ptr, len);
        free(ptr, len + 1);
        _membersCache = JSON.parse(json).members || [];
        _membersVersion = version;
        return _membersCache;
    };

    const _castTargets = (prop, filter) => _fetchMembers().filter(m => {
        if (!m.methods) return false;
        if (m.name === self.name) return false;
        if (!m.methods.includes(prop)) return false;
        return filter ? filter.includes(m.name) : true;
    });

    const _scheduleReconnect = () => {
        if (_intentionalClose || !self.autoreconnect) return;
        if (_reconnecting) return;
        _reconnecting = true;
        _reconnectAttempt += 1;
        const epoch = _epoch;
        const delay = Math.min(self.reconnectDelay * Math.pow(2, _reconnectAttempt - 1), 60000);
        console.log(`[daffi] connection lost — reconnecting in ${(delay / 1000).toFixed(1)} s…`);
        setTimeout(() => {
            if (_intentionalClose || epoch !== _epoch) { _reconnecting = false; return; }
            _connectSocket()
                .then(() => { _reconnecting = false; })
                .catch((err) => {
                    console.warn(`[daffi] reconnect failed: ${err}`);
                    _reconnecting = false;
                    if (epoch === _epoch) _scheduleReconnect();
                });
        }, delay);
    };

    class Handler {
        constructor(receiver, timeout, serde, returnResult) {
            this.receiver     = receiver;
            this.timeout      = timeout;
            this.serde        = serde;       // 0=OPAQUE, 1=JSON, 3=MSGPACK
            this.returnResult = returnResult;
        }

        get connNum() { return self.connNum; }

        /** Send one call.  Throws when it cannot be sent; returns the reply
         *  promise, or null for a fire-and-forget call. */
        send(prop, args) {
            _ensureOpen();
            const { sendMessage, freeSendResult } = _wasmExports;
            let bytes;
            if (this.serde === 1) {
                bytes = _textEnc.encode(JSON.stringify({ args, kwargs: {} }));
            } else if (this.serde === 3) {
                bytes = _mp.encode([args, {}]);
            } else {
                // OPAQUE — single buffer or string
                if (args.length !== 1) throw new Error('OPAQUE serde expects exactly one argument.');
                bytes = args[0] instanceof Uint8Array ? args[0] : _textEnc.encode(args[0]);
            }

            // sendMessage takes ownership of all three buffers, also on failure.
            const payload  = _encodeBuffer(bytes);
            const receiver = _encodeString(this.receiver);
            const funcName = _encodeString(prop);
            _sendFailed = false;
            const msgPtr = sendMessage(...payload, ...receiver, ...funcName, this.serde, this.returnResult, this.connNum);
            if (!msgPtr) throw _wasmError();

            const view           = new DataView(_memory.buffer, msgPtr, 16);
            const uuid           = view.getUint32(0, true);
            const ptrLen         = view.getUint32(4, true);
            const ptr            = view.getUint32(8, true);
            const isJsonFlag     = view.getUint32(12, true);
            const actualReceiver = _decodeString(ptr, ptrLen);
            freeSendResult(msgPtr);
            if (_sendFailed) throw new Error('Connection is closed');

            if (!this.returnResult) return null;
            const reply = _expect(uuid, this.timeout, actualReceiver);
            // JSON payload is {args:[result], kwargs:{}} — unwrap args[0]
            return (isJsonFlag && this.serde === 1) ? reply.then(raw => raw.args[0]) : reply;
        }

        get(target, prop) {
            const handler = this;
            return async (...args) => handler.send(prop, args);
        }
    }

    // Connection does NOT store connNum — it always reads self.connNum so that
    // a transparent reconnect is invisible to existing Connection objects.
    class Connection {
        _serde(opt) {
            if (opt == null) opt = 'msgpack';
            switch (opt) {
                case 'json':    case 1: return 1;
                case 'raw':     case 0: return 0;
                case 'msgpack': case 3: return 3;
                default: throw new Error(`Unknown serde "${opt}". Use "json", "raw", or "msgpack".`);
            }
        }

        /** RPC call — returns a Promise with the result. */
        rpc(options) {
            if (self.closed) throw new Error('Connection is closed');
            options = options || {};
            return new Proxy({}, new Handler(
                options.receiver || '',
                options.timeout  || null,
                this._serde(options.serde),
                true,
            ));
        }

        /** Fire-and-forget — returns immediately, no result. */
        rpc_nowait(options) {
            if (self.closed) throw new Error('Connection is closed');
            options = options || {};
            return new Proxy({}, new Handler(
                options.receiver || '',
                null,
                this._serde(options.serde),
                false,
            ));
        }

        /**
         * Blocking stream — iterate an iterable and await the remote ack for each
         * chunk before sending the next one.  Provides natural backpressure.
         * Default serde: "raw" (OPAQUE).
         */
        stream(options) {
            if (self.closed) throw new Error('Connection is closed');
            options = options || {};
            const serde    = this._serde(options.serde != null ? options.serde : 'raw');
            const timeout  = options.timeout || null;
            const receiver = options.receiver || '';
            return new Proxy({}, {
                get(_, funcName) {
                    return async function(gen) {
                        const chunks = (gen != null && typeof gen[Symbol.iterator] === 'function')
                            ? gen : [gen];
                        const h = new Handler(receiver, timeout, serde, true);
                        for (const chunk of chunks) {
                            await h.send(funcName, [chunk]);
                        }
                    };
                }
            });
        }

        /**
         * Fire-and-forget stream — iterate an iterable and send each chunk without
         * waiting for a reply.  No backpressure.  Throws if a chunk cannot be sent.
         * Default serde: "raw" (OPAQUE).
         */
        stream_nowait(options) {
            if (self.closed) throw new Error('Connection is closed');
            options = options || {};
            const serde    = this._serde(options.serde != null ? options.serde : 'raw');
            const receiver = options.receiver || '';
            return new Proxy({}, {
                get(_, funcName) {
                    return function(gen) {
                        const chunks = (gen != null && typeof gen[Symbol.iterator] === 'function')
                            ? gen : [gen];
                        const h = new Handler(receiver, null, serde, false);
                        for (const chunk of chunks) {
                            h.send(funcName, [chunk]);
                        }
                    };
                }
            });
        }

        /**
         * Return the list of currently connected members from the native layer.
         * Each entry: { name: string, methods: string[] | null }
         */
        _members() {
            return _fetchMembers();
        }

        /**
         * Broadcast a call to every connected peer that exposes the requested
         * method and collect all results.
         *
         * Returns a Promise resolving to { receiverName: result, ... }.
         */
        cast(options) {
            if (self.closed) throw new Error('Connection is closed');
            options = options || {};
            const serde   = this._serde(options.serde);
            const timeout = options.timeout || null;
            const filter  = options.receiver
                ? (Array.isArray(options.receiver) ? options.receiver : [options.receiver])
                : null;

            return new Proxy({}, {
                get(_, prop) {
                    return async (...args) => {
                        _ensureOpen();
                        const targets = _castTargets(prop, filter);
                        if (targets.length === 0) throw new Error(`No connected peer exposes "${prop}"`);
                        const results = await Promise.all(
                            targets.map(async (m) => {
                                const h = new Handler(m.name, timeout, serde, true);
                                const result = await h.send(prop, args);
                                return [m.name, result];
                            })
                        );
                        return Object.fromEntries(results);
                    };
                },
            });
        }

        /**
         * Fire-and-forget broadcast — send to all peers that expose the method,
         * do not wait for any results.  Throws if a call cannot be sent.
         */
        cast_nowait(options) {
            if (self.closed) throw new Error('Connection is closed');
            options = options || {};
            const serde  = this._serde(options.serde);
            const filter = options.receiver
                ? (Array.isArray(options.receiver) ? options.receiver : [options.receiver])
                : null;

            return new Proxy({}, {
                get(_, prop) {
                    return (...args) => {
                        _ensureOpen();
                        for (const m of _castTargets(prop, filter)) {
                            new Handler(m.name, null, serde, false).send(prop, args);
                        }
                    };
                },
            });
        }

        /**
         * Wait until all requested members are visible in the network.
         *
         * Returns a Promise that resolves once every listed peer name appears
         * in the ChannelsMapper.  Use this to synchronise a multi-worker
         * scenario before issuing RPC calls that require specific peers to be
         * online.
         *
         * @param {string|string[]} members     Peer name or array of peer names to wait for.
         * @param {object}          [options]
         * @param {number|null}     [options.timeout=null]   Max wait in ms (null = forever).
         * @param {number}          [options.interval=1000]  Poll interval in ms.
         * @returns {Promise<void>} Resolves when all peers are visible.
         *
         * @example
         * const conn = await client.connect();
         *
         * // Wait for a single worker before calling it.
         * await conn.waitForMembers('python-worker');
         * const result = await conn.rpc({ receiver: 'python-worker' }).add(1, 2);
         *
         * // Wait for multiple workers with a 30-second deadline.
         * await conn.waitForMembers(['worker-1', 'worker-2'], { timeout: 30000 });
         */
        async waitForMembers(members, options) {
            if (self.closed) throw new Error('Connection is closed');
            if (!Array.isArray(members)) members = [members];
            options = options || {};
            const timeout  = options.timeout  != null ? options.timeout  : null;
            const interval = options.interval != null ? options.interval : 1000;
            const deadline = timeout !== null ? Date.now() + timeout : null;
            const needed   = new Set(members);

            while (true) {
                if (self.closed) throw new Error('Connection is closed');
                const current = new Set(this._members().map(m => m.name));
                if ([...needed].every(n => current.has(n))) return;
                if (deadline !== null && Date.now() >= deadline) {
                    const missing = [...needed].filter(n => !current.has(n));
                    throw new Error(
                        `Timed out waiting for members: ${missing.join(', ')}`
                    );
                }
                await new Promise(r => setTimeout(r, interval));
            }
        }
    }

    /** Stop listening to `ws` and close it.  A socket given up on must not
     *  feed frames into, or close, the connection that replaced it. */
    const _discardSocket = (ws) => {
        ws.onopen = ws.onerror = ws.onclose = ws.onmessage = null;
        if (ws.readyState === WebSocket.CONNECTING || ws.readyState === WebSocket.OPEN) {
            try { ws.close(); } catch (_) {}
        }
    };

    /** The established connection on `ws` ended. */
    const _onLost = (ws) => {
        if (ws !== _socket) return;
        _socket = null;
        self.closed = true;
        _membersCache = null;
        _rejectAllPending('Connection closed unexpectedly');
        _scheduleReconnect();
    };

    const _connectSocket = async () => {
        await _initWasm();

        const { initClient, sendHandshake } = _wasmExports;

        if (_socket) _discardSocket(_socket);
        const ws = new WebSocket(self.wsUrl);
        ws.binaryType = 'arraybuffer';
        _socket = ws;

        ws.onmessage = (event) => {
            if (ws !== _socket) return;
            const frame = _encodeBuffer(new Uint8Array(event.data));
            if (_wasmExports.parseAndStoreMessage(...frame, self.connNum) !== 0) {
                console.error(`[daffi] dropped a frame: ${_wasmError().message}`);
            }
        };

        try {
            // Wait for the socket to open.  Reject immediately on error or early
            // close rather than polling so errors surface straight away.
            await new Promise((resolve, reject) => {
                const timer = setTimeout(() => {
                    reject(new Error(
                        `WebSocket open timeout (8 s) — is the daffi server running at ${self.wsUrl}?`));
                }, 8000);

                ws.onopen = () => {
                    clearTimeout(timer);
                    resolve();
                };

                ws.onerror = () => {
                    clearTimeout(timer);
                    reject(new Error(
                        `WebSocket connection failed for ${self.wsUrl} — ` +
                        `verify the daffi server is running and reachable`));
                };

                ws.onclose = (ev) => {
                    clearTimeout(timer);
                    reject(new Error(
                        `WebSocket closed before open (code ${ev.code}) — ` +
                        `target: ${self.wsUrl}`));
                };
            });
            ws.onopen = null;
            ws.onerror = null;
            // Until the handshake completes, a close only fails this attempt.
            ws.onclose = () => {
                if (ws === _socket) _rejectAllPending('Connection closed during the handshake');
            };

            // Drop any leftover pending map before uuid counter resets.
            _rejectAllPending('Connection reset');
            _membersCache = null;
            // Free any previous WASM slot so it doesn't accumulate across reconnects.
            if (self.connNum != null) {
                try { _wasmExports.stopClient(self.connNum); } catch (_) {}
                self.connNum = null;
            }
            const token = self.authToken ? _encodeString(self.authToken) : [0, 0];
            // Numeric exports return -1 on failure.
            const connNum = initClient(..._encodeString(self.name), ...token);
            if (connNum < 0) throw _wasmError();
            self.connNum  = connNum;
            const hsUuid  = sendHandshake(connNum);
            if (hsUuid < 0) throw _wasmError();
            const hsResult = await _expect(hsUuid, 5000, '');
            if (ws !== _socket) throw new Error('Connection attempt superseded');
            ws.onclose = () => _onLost(ws);
            self.closed = false;
            console.log(`[daffi] "${self.name}" connected. type: ${hsResult.meta.type}`);
            _reconnectAttempt = 0; // reset counter on success
            return new Connection();
        } catch (err) {
            if (ws === _socket) {
                _socket = null;
                self.closed = true;
            }
            _discardSocket(ws);
            throw err;
        }
    };

    // ── Public API ────────────────────────────────────────────────────────────

    /** Connect to the server and return a Connection. */
    this.connect = async () => {
        _intentionalClose = false;
        _epoch += 1;
        return _connectSocket();
    };

    /** Gracefully close the connection (will not auto-reconnect). */
    this.stop = () => {
        _intentionalClose = true;
        _epoch += 1;
        self.closed = true;
        _membersCache = null;
        const ws = _socket;
        _socket = null;
        if (ws) _discardSocket(ws);
        _rejectAllPending('Client stopped');
    };

    /** Subscribe to server events (connected / disconnected / etc.). */
    this.addEventHandler = (fn) => self.eventHandlers.push(fn);
}
