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
 *   <script src="https://cdn.jsdelivr.net/gh/600apples/daffi@2.0.0/js-client/daffi.js"></script>
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

// Compact MessagePack codec matching Python msgpack 1.0 (use_bin_type,
// raw=False).  Covers nil/bool/int/float/str/bin/array/map — enough for
// daffi's [args, kwargs] envelope.
const _mp = (() => {
    const textEnc = new TextEncoder();
    const textDec = new TextDecoder();

    function encode(value) {
        const out = [];
        write(out, value);
        let total = 0;
        for (const chunk of out) total += chunk.length;
        const buf = new Uint8Array(total);
        let off = 0;
        for (const chunk of out) { buf.set(chunk, off); off += chunk.length; }
        return buf;
    }

    function u8(n) { return Uint8Array.of(n); }
    function putUint(tag, n, bytes) {
        const a = new Uint8Array(1 + bytes);
        const view = new DataView(a.buffer);
        view.setUint8(0, tag);
        if (bytes === 1) view.setUint8(1, n);
        else if (bytes === 2) view.setUint16(1, n);
        else if (bytes === 4) view.setUint32(1, n);
        else view.setBigUint64(1, BigInt(n));
        return a;
    }
    function putInt(tag, n, bytes) {
        const a = new Uint8Array(1 + bytes);
        const view = new DataView(a.buffer);
        view.setUint8(0, tag);
        if (bytes === 1) view.setInt8(1, n);
        else if (bytes === 2) view.setInt16(1, n);
        else if (bytes === 4) view.setInt32(1, n);
        else view.setBigInt64(1, BigInt(n));
        return a;
    }

    function write(out, v) {
        if (v === null || v === undefined) { out.push(u8(0xc0)); return; }
        if (v === false) { out.push(u8(0xc2)); return; }
        if (v === true) { out.push(u8(0xc3)); return; }
        if (typeof v === 'number') {
            if (Number.isInteger(v) && Number.isSafeInteger(v)) {
                if (v >= 0) {
                    if (v <= 0x7f) out.push(u8(v));
                    else if (v <= 0xff) out.push(putUint(0xcc, v, 1));
                    else if (v <= 0xffff) out.push(putUint(0xcd, v, 2));
                    else if (v <= 0xffffffff) out.push(putUint(0xce, v, 4));
                    else out.push(putUint(0xcf, v, 8));
                } else if (v >= -0x20) {
                    out.push(u8(v & 0xff));
                } else if (v >= -0x80) {
                    out.push(putInt(0xd0, v, 1));
                } else if (v >= -0x8000) {
                    out.push(putInt(0xd1, v, 2));
                } else if (v >= -0x80000000) {
                    out.push(putInt(0xd2, v, 4));
                } else {
                    out.push(putInt(0xd3, v, 8));
                }
                return;
            }
            const a = new Uint8Array(9);
            const view = new DataView(a.buffer);
            view.setUint8(0, 0xcb);
            view.setFloat64(1, v);
            out.push(a);
            return;
        }
        if (typeof v === 'string') {
            const bytes = textEnc.encode(v);
            headerBin(out, bytes.length, 0xa0, 0xd9, 0xda, 0xdb, true);
            out.push(bytes);
            return;
        }
        if (v instanceof ArrayBuffer) v = new Uint8Array(v);
        if (ArrayBuffer.isView(v) && !(v instanceof DataView)) {
            const bytes = new Uint8Array(v.buffer, v.byteOffset, v.byteLength);
            headerBin(out, bytes.length, 0, 0xc4, 0xc5, 0xc6, false);
            out.push(bytes);
            return;
        }
        if (Array.isArray(v)) {
            headerLen(out, v.length, 0x90, 0xdc, 0xdd, 15);
            for (const item of v) write(out, item);
            return;
        }
        if (typeof v === 'object') {
            const keys = Object.keys(v);
            headerLen(out, keys.length, 0x80, 0xde, 0xdf, 15);
            for (const k of keys) { write(out, k); write(out, v[k]); }
            return;
        }
        throw new TypeError(`msgpack: cannot encode ${typeof v}`);
    }

    function headerBin(out, n, fix, t8, t16, t32, isStr) {
        if (isStr && n <= 31) { out.push(u8(fix | n)); return; }
        if (n <= 0xff) out.push(putUint(t8, n, 1));
        else if (n <= 0xffff) out.push(putUint(t16, n, 2));
        else out.push(putUint(t32, n, 4));
    }
    function headerLen(out, n, fix, t16, t32, fixMax) {
        if (n <= fixMax) out.push(u8(fix | n));
        else if (n <= 0xffff) out.push(putUint(t16, n, 2));
        else out.push(putUint(t32, n, 4));
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
    this.pendingMessages = {};
    this.eventHandlers   = [];
    this.closed = true;
    const self = this;

    // Compiled WASM module reused across reconnects (avoids re-fetching wasm).
    let _module = null;
    // Single WASM instance shared across reconnects so memory helpers remain valid.
    let _wasmExports    = null;
    let _memory         = null;
    let _decodeString   = null;
    let _encodeString   = null;
    let _encodeBuffer   = null;
    // Current active WebSocket.
    let _socket = null;
    // Set to true when stop() is called so reconnect loop does not restart.
    let _intentionalClose = false;
    // Reconnect attempt counter; reset to 0 after a successful connect.
    let _reconnectAttempt = 0;
    // True while a reconnect setTimeout is pending or _connectSocket is running.
    // Prevents duplicate retry chains when both onclose and the open-timeout
    // fire for the same failed attempt.
    let _reconnecting = false;

    const _initWasm = async () => {
        if (_wasmExports) return; // already done

        if (!_module) _module = await _loadWasm();

        // The module defines and exports its own memory.  Always go through
        // `_memory.buffer`: it is replaced whenever the memory grows.
        const { exports } = await WebAssembly.instantiate(_module, {
            env: {
                _throwError(ptr, len) { throw new Error(_decodeString(ptr, len)); },
                _consoleLog(ptr, len)  { console.log(_decodeString(ptr, len));   },
            },
            window: {
                // Always uses _socket so reconnect transparently replaces the socket.
                _sendToSocket(ptr, len) {
                    if (_socket && _socket.readyState === WebSocket.OPEN) {
                        _socket.send(_memory.buffer.slice(ptr, ptr + len));
                    }
                },

                // decoder: 0=OPAQUE, 1=JSON, 2=PICKLE(unsupported in JS), 3=MSGPACK
                _storeMessage(ptr, len, uuid, isError, decoder) {
                    let message;
                    if (decoder === 3) {
                        const raw = new Uint8Array(_memory.buffer, ptr, len).slice();
                        const decoded = _mp.decode(raw);
                        // Python serialises return value as [[result], {}]
                        message = Array.isArray(decoded) ? decoded[0][0] : decoded;
                    } else if (decoder === 0) {
                        const text = _decodeString(ptr, len);
                        try { message = JSON.parse(text); } catch { message = new Uint8Array(_memory.buffer, ptr, len).slice(); }
                    } else {
                        message = JSON.parse(_decodeString(ptr, len));
                    }

                    const msgData = self.pendingMessages[uuid];
                    if (msgData && !Array.isArray(msgData)) {
                        if (msgData.timeoutId) clearTimeout(msgData.timeoutId);
                        delete self.pendingMessages[uuid];
                        if (isError) {
                            const errText = (message && message.args)
                                ? `Remote exception: "${message.args[0][0]}(${message.args[0][2]})"`
                                : String(message);
                            msgData.reject(errText);
                        } else {
                            msgData.resolve(message);
                        }
                    } else {
                        self.pendingMessages[uuid] = [message, isError];
                    }
                },

                _triggerEvent(ptr, len) {
                    const event = JSON.parse(_decodeString(ptr, len));
                    if (event.type === 'disconnected') {
                        for (const [uuid, msgData] of Object.entries(self.pendingMessages)) {
                            if (!Array.isArray(msgData) && msgData.receiver === event.member) {
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
                    for (const h of self.eventHandlers) h(event);
                },
            },
        });

        _wasmExports = exports;
        _memory = exports.memory;
        const { allocUint8 } = exports;

        _decodeString = (ptr, len) =>
            new TextDecoder().decode(new Uint8Array(_memory.buffer, ptr, len));

        // Buffers cross into wasm as [ptr, len]: payloads may contain NUL
        // bytes, and wasm frees them by length.
        _encodeBuffer = (buf) => {
            const len = buf.byteLength;
            const ptr = allocUint8(len);
            new Uint8Array(_memory.buffer, ptr, len).set(buf);
            return [ptr, len];
        };

        _encodeString = (str) => _encodeBuffer(new TextEncoder().encode(str));
    };

    /** Reject waiters and drop early-arrival entries so u16 uuids cannot
     *  satisfy a later RPC after reconnect resets the counter. */
    const _rejectAllPending = (reason) => {
        for (const msgData of Object.values(self.pendingMessages)) {
            if (!Array.isArray(msgData)) {
                if (msgData.timeoutId) clearTimeout(msgData.timeoutId);
                try { msgData.reject(reason); } catch (_) {}
            }
        }
        self.pendingMessages = {};
    };

    const _scheduleReconnect = () => {
        if (_intentionalClose || !self.autoreconnect) return;
        // Guard against double-scheduling: both socket.onclose and the open-
        // timeout promise rejection can fire for the same failed attempt.
        if (_reconnecting) return;
        _reconnecting = true;
        _reconnectAttempt += 1;
        const delay = Math.min(self.reconnectDelay * Math.pow(2, _reconnectAttempt - 1), 60000);
        console.log(`[daffi] connection lost — reconnecting in ${(delay / 1000).toFixed(1)} s…`);
        setTimeout(() => {
            if (_intentionalClose) { _reconnecting = false; return; }
            _connectSocket()
                .then(() => { _reconnecting = false; })
                .catch((err) => {
                    console.warn(`[daffi] reconnect failed: ${err}`);
                    _reconnecting = false;
                    _scheduleReconnect();
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

        get(target, prop) {
            const handler = this;
            return async (...args) => {
                const { sendMessage, freeSendResult } = _wasmExports;
                let payload;
                if (handler.serde === 1) {
                    payload = _encodeString(JSON.stringify({ args, kwargs: {} }));
                } else if (handler.serde === 3) {
                    const enc = _mp.encode([args, {}]);
                    payload = _encodeBuffer(enc instanceof Uint8Array ? enc : new Uint8Array(enc));
                } else {
                    // OPAQUE — single buffer or string
                    if (args.length !== 1) throw new Error('OPAQUE serde expects exactly one argument.');
                    const buf = args[0] instanceof Uint8Array ? args[0] : new TextEncoder().encode(args[0]);
                    payload = _encodeBuffer(buf);
                }

                // sendMessage takes ownership of all three buffers.
                const receiver = _encodeString(handler.receiver);
                const funcName = _encodeString(prop);
                const msgPtr   = sendMessage(...payload, ...receiver, ...funcName, handler.serde, handler.returnResult, handler.connNum);

                const view           = new DataView(_memory.buffer, msgPtr, 16);
                const uuid           = view.getUint32(0, true);
                const ptrLen         = view.getUint32(4, true);
                const ptr            = view.getUint32(8, true);
                const isJsonFlag     = view.getUint32(12, true);
                const actualReceiver = _decodeString(ptr, ptrLen);
                freeSendResult(msgPtr);

                if (!handler.returnResult) return;

                const raw = handler.timeout
                    ? await handler._waitWithTimeout(uuid, handler.timeout, actualReceiver)
                    : await handler._wait(uuid, actualReceiver);

                // JSON payload is {args:[result], kwargs:{}} — unwrap args[0]
                return (isJsonFlag && handler.serde === 1) ? raw.args[0] : raw;
            };
        }

        _wait(uuid, receiver) {
            return new Promise((resolve, reject) => {
                const existing = self.pendingMessages[uuid];
                if (existing && Array.isArray(existing)) {
                    const [msg, isError] = existing;
                    delete self.pendingMessages[uuid];
                    return isError ? reject(msg) : resolve(msg);
                }
                self.pendingMessages[uuid] = { resolve, reject, timeoutId: null, receiver, uuid };
            });
        }

        _waitWithTimeout(uuid, timeout, receiver) {
            return new Promise((resolve, reject) => {
                const timeoutId = setTimeout(() => {
                    delete self.pendingMessages[uuid];
                    reject('Operation timed out');
                }, timeout);
                const existing = self.pendingMessages[uuid];
                if (existing && Array.isArray(existing)) {
                    clearTimeout(timeoutId);
                    const [msg, isError] = existing;
                    delete self.pendingMessages[uuid];
                    return isError ? reject(msg) : resolve(msg);
                }
                self.pendingMessages[uuid] = { resolve, reject, timeoutId, receiver, uuid };
            });
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
                        for (const chunk of chunks) {
                            const h = new Handler(receiver, timeout, serde, true);
                            await h.get({}, funcName)(chunk);
                        }
                    };
                }
            });
        }

        /**
         * Fire-and-forget stream — iterate an iterable and send each chunk without
         * waiting for a reply.  No backpressure.
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
                        for (const chunk of chunks) {
                            const h = new Handler(receiver, null, serde, false);
                            h.get({}, funcName)(chunk);
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
            const { getAvailableMembers, free } = _wasmExports;
            const ptr = getAvailableMembers(self.connNum);
            const len = new Uint8Array(_memory.buffer, ptr).indexOf(0);
            const json = _decodeString(ptr, len);
            free(ptr, len + 1);
            return JSON.parse(json).members || [];
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
            const conn = this;

            return new Proxy({}, {
                get(_, prop) {
                    return async (...args) => {
                        const members = conn._members();
                        const targets = members.filter(m => {
                            if (!m.methods) return false;
                            if (m.name === self.name) return false;
                            if (!m.methods.includes(prop)) return false;
                            if (filter) return filter.some(f => m.name.startsWith(f));
                            return true;
                        });
                        if (targets.length === 0) throw new Error(`No connected peer exposes "${prop}"`);
                        const results = await Promise.all(
                            targets.map(async (m) => {
                                const h = new Handler(m.name, timeout, serde, true);
                                const result = await h.get({}, prop)(...args);
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
         * do not wait for any results.
         */
        cast_nowait(options) {
            if (self.closed) throw new Error('Connection is closed');
            options = options || {};
            const serde  = this._serde(options.serde);
            const filter = options.receiver
                ? (Array.isArray(options.receiver) ? options.receiver : [options.receiver])
                : null;
            const conn = this;

            return new Proxy({}, {
                get(_, prop) {
                    return (...args) => {
                        const members = conn._members();
                        const targets = members.filter(m => {
                            if (!m.methods) return false;
                            if (m.name === self.name) return false;
                            if (!m.methods.includes(prop)) return false;
                            if (filter) return filter.some(f => m.name.startsWith(f));
                            return true;
                        });
                        for (const m of targets) {
                            new Handler(m.name, null, serde, false).get({}, prop)(...args);
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

    const _connectSocket = async () => {
        await _initWasm();

        const { initClient, sendHandshake } = _wasmExports;

        _socket = new WebSocket(self.wsUrl);
        _socket.binaryType = 'arraybuffer';

        _socket.onmessage = (event) => {
            const buf = new Uint8Array(event.data);
            _wasmExports.parseAndStoreMessage(..._encodeBuffer(buf), self.connNum);
        };

        _socket.onclose = () => {
            // Reject waiters and clear early-arrival entries — initClient
            // resets the u16 uuid counter, so leftovers would mis-resolve.
            _rejectAllPending('Connection closed unexpectedly');
            self.closed = true;
            _scheduleReconnect();
        };

        // Wait for the socket to open.  Reject immediately on error or early
        // close rather than polling so errors surface straight away.
        // The previously-registered onclose (reconnect logic) is captured and
        // restored in BOTH the success and failure paths so it is never lost.
        const _savedOnClose = _socket.onclose;
        await new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                _socket.onclose = _savedOnClose;
                reject(new Error(
                    `WebSocket open timeout (8 s) — is the daffi server running at ${self.wsUrl}?`));
            }, 8000);

            _socket.onopen = () => {
                clearTimeout(timer);
                _socket.onopen  = null;
                _socket.onerror = null;
                _socket.onclose = _savedOnClose;  // restore before resolving
                resolve();
            };

            _socket.onerror = () => {
                clearTimeout(timer);
                _socket.onopen  = null;
                _socket.onerror = null;
                _socket.onclose = _savedOnClose;
                reject(new Error(
                    `WebSocket connection failed for ${self.wsUrl} — ` +
                    `verify the daffi server is running and reachable`));
            };

            _socket.onclose = (ev) => {
                clearTimeout(timer);
                _socket.onopen  = null;
                _socket.onerror = null;
                _socket.onclose = _savedOnClose;
                reject(new Error(
                    `WebSocket closed before open (code ${ev.code}) — ` +
                    `target: ${self.wsUrl}`));
            };
        });

        self.closed = false;
        // Drop any leftover pending map before uuid counter resets.
        _rejectAllPending('Connection reset');
        // Free any previous WASM slot so it doesn't accumulate across reconnects.
        if (self.connNum != null) {
            try { _wasmExports.stopClient(self.connNum); } catch (_) {}
            self.connNum = null;
        }
        const token = self.authToken ? _encodeString(self.authToken) : [0, 0];
        const connNum = initClient(..._encodeString(self.name), ...token);
        self.connNum  = connNum;
        const hsUuid  = sendHandshake(connNum);
        const hsResult = await new Handler('', null, 1, true)
            ._waitWithTimeout(hsUuid, 5000, '');
        console.log(`[daffi] "${self.name}" connected. type: ${hsResult.meta.type}`);
        _reconnectAttempt = 0; // reset counter on success
        return new Connection();
    };

    // ── Public API ────────────────────────────────────────────────────────────

    /** Connect to the server and return a Connection. */
    this.connect = async () => {
        return _connectSocket();
    };

    /** Gracefully close the connection (will not auto-reconnect). */
    this.stop = () => {
        _intentionalClose = true;
        self.closed = true;
        if (_socket) _socket.close();
    };

    /** Subscribe to server events (connected / disconnected / etc.). */
    this.addEventHandler = (fn) => self.eventHandlers.push(fn);
}
