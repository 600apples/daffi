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
 *   <!-- Load the JS client (pin to a specific release tag) -->
 *   <script src="https://cdn.jsdelivr.net/gh/600apples/daffi@2.0.0/js-client/daffi.js"></script>
 *
 *   <!-- (optional) msgpack-lite — only needed for serde: "msgpack" -->
 *   <script src="https://unpkg.com/msgpack-lite/dist/msgpack.min.js"></script>
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
 *   const conn   = await client.connect();          // optional password string
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
 * ─────────────────────────────────────────────────────────────────────────────
 * client.connect(password?) → Promise<Connection>
 * ─────────────────────────────────────────────────────────────────────────────
 *   password  string (optional) — Server password, if configured.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * client.addEventHandler(fn)
 * ─────────────────────────────────────────────────────────────────────────────
 *   Subscribe to server-side events.  fn receives an event object:
 *     { type: "connected" | "disconnected", member: string }
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
 *   "json"    | 1  — JSON (default).  Works with any JSON-serialisable value.
 *
 *   "raw"     | 0  — OPAQUE / raw bytes.  Pass a single Uint8Array or string;
 *                    receive a Uint8Array (or parsed JSON if the bytes happen
 *                    to be valid JSON).  Use when the Python side is decorated
 *                    with @callback and expects bytes.
 *
 *   "msgpack" | 3  — Binary MessagePack.  More compact than JSON for
 *                    structured data.  Requires msgpack-lite to be loaded
 *                    before this file:
 *                      <script src="https://unpkg.com/msgpack-lite/dist/msgpack.min.js"></script>
 *
 *   Note: PICKLE (2) is Python-only and is not supported in the JS client.
 */
function _generateClientName() {
    // location.hostname → bare host only ("localhost", "example.com"), no port/protocol.
    const host = (typeof location !== 'undefined' && location.hostname) ? location.hostname : 'browser';
    const rand = (Math.random() * 0x100000000) >>> 0;   // unsigned 32-bit random
    return `${host}-0x${rand.toString(16).padStart(8, '0')}`;
}

// CDN URL for the WASM binary — pinned to the release tag, not user-configurable.
const _WASM_URL = 'https://cdn.jsdelivr.net/gh/600apples/daffi@2.0.0/js-client/app.wasm';

function DaffiClient(name, options) {
    // Allow DaffiClient(options) — name omitted entirely.
    if (name !== null && typeof name === 'object') { options = name; name = undefined; }
    options = options || {};
    if (!options.wsUrl) throw new Error(
        '[daffi] options.wsUrl is required — there is no default. ' +
        'Pass the WebSocket URL explicitly, e.g. { wsUrl: "ws://127.0.0.1:5000" }.'
    );
    this.name           = name || _generateClientName();
    this.wsUrl          = options.wsUrl;
    this.wasmPath       = _WASM_URL;
    this.autoreconnect  = options.autoreconnect  || false;
    this.reconnectDelay = options.reconnectDelay != null ? options.reconnectDelay : 2000;
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
    let _encodeStringZ  = null;
    let _encodeBuffer   = null;
    let _encodeBufferZ  = null;
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

    const _mp = () => {
        const lib = globalThis.msgpack || globalThis.MessagePack;
        if (!lib) throw new Error(
            'msgpack library not loaded. ' +
            'Add <script src="https://unpkg.com/msgpack-lite/dist/msgpack.min.js"> before daffi.js.'
        );
        return lib;
    };

    const _initWasm = async () => {
        if (_wasmExports) return; // already done

        if (!_module) _module = await WebAssembly.compileStreaming(fetch(self.wasmPath));

        const INITIAL_PAGES = 256; // 16 MB
        _memory = new WebAssembly.Memory({ initial: INITIAL_PAGES, maximum: 65536 });
        const indirectFunctionTable = new WebAssembly.Table({ initial: 128, element: 'anyfunc' });
        const stackPointer = new WebAssembly.Global({ value: 'i32', mutable: true  }, INITIAL_PAGES * 65536);
        const memoryBase   = new WebAssembly.Global({ value: 'i32', mutable: false }, 0);
        const tableBase    = new WebAssembly.Global({ value: 'i32', mutable: false }, 0);

        const { exports } = await WebAssembly.instantiate(_module, {
            env: {
                memory: _memory,
                __indirect_function_table: indirectFunctionTable,
                __stack_pointer:           stackPointer,
                __memory_base:             memoryBase,
                __table_base:              tableBase,
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
                        const decoded = _mp().decode(raw);
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
                        for (const msgData of Object.values(self.pendingMessages)) {
                            if (!Array.isArray(msgData) && msgData.receiver === event.member) {
                                if (msgData.timeoutId) clearTimeout(msgData.timeoutId);
                                delete self.pendingMessages[msgData.uuid];
                                msgData.reject(`"${event.member}" disconnected`);
                            }
                        }
                    }
                    for (const h of self.eventHandlers) h(event);
                },
            },
        });

        _wasmExports = exports;
        const { allocUint8 } = exports;

        _decodeString = (ptr, len) =>
            new TextDecoder().decode(new Uint8Array(_memory.buffer, ptr, len));

        _encodeStringZ = (str) => {
            const buf = new TextEncoder().encode(str);
            const ptr = allocUint8(buf.length + 1);
            const sl  = new Uint8Array(_memory.buffer, ptr, buf.length + 1);
            sl.set(buf); sl[buf.length] = 0;
            return ptr;
        };

        _encodeBuffer = (buf) => {
            const len = buf.byteLength;
            const ptr = allocUint8(len);
            new Uint8Array(_memory.buffer, ptr, len).set(buf);
            return ptr;
        };

        _encodeBufferZ = (buf) => {
            const len = buf.byteLength;
            const ptr = allocUint8(len + 1);
            const sl  = new Uint8Array(_memory.buffer, ptr, len + 1);
            sl.set(buf); sl[len] = 0;
            return ptr;
        };
    };

    const _scheduleReconnect = (password) => {
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
            _connectSocket(password)
                .then(() => { _reconnecting = false; })
                .catch((err) => {
                    console.warn(`[daffi] reconnect failed: ${err}`);
                    _reconnecting = false;
                    _scheduleReconnect(password);
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
                const { sendMessage, free } = _wasmExports;
                let argsZ;
                if (handler.serde === 1) {
                    argsZ = _encodeStringZ(JSON.stringify({ args, kwargs: {} }));
                } else if (handler.serde === 3) {
                    const enc = _mp().encode([args, {}]);
                    argsZ = _encodeBufferZ(enc instanceof Uint8Array ? enc : new Uint8Array(enc));
                } else {
                    // OPAQUE — single buffer or string
                    if (args.length !== 1) throw new Error('OPAQUE serde expects exactly one argument.');
                    const buf = args[0] instanceof Uint8Array ? args[0] : new TextEncoder().encode(args[0]);
                    argsZ = _encodeBufferZ(buf);
                }

                const receiverZ = _encodeStringZ(handler.receiver);
                const funcNameZ = _encodeStringZ(prop);
                const msgPtr    = sendMessage(argsZ, receiverZ, funcNameZ, handler.serde, handler.returnResult, handler.connNum);

                if (!handler.returnResult) { free(msgPtr); return; }

                const view           = new DataView(_memory.buffer, msgPtr, 16);
                const uuid           = view.getUint32(0, true);
                const ptrLen         = view.getUint32(4, true);
                const ptr            = view.getUint32(8, true);
                const isJsonFlag     = view.getUint32(12, true);
                const actualReceiver = _decodeString(ptr, ptrLen);

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
                self.pendingMessages[uuid] = { resolve, reject, timeoutId: null, receiver };
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
                self.pendingMessages[uuid] = { resolve, reject, timeoutId, receiver };
            });
        }
    }

    // Connection does NOT store connNum — it always reads self.connNum so that
    // a transparent reconnect is invisible to existing Connection objects.
    class Connection {
        _serde(opt) {
            switch (opt || 'json') {
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
            const json = _decodeString(ptr, new Uint8Array(_memory.buffer, ptr).indexOf(0));
            free(ptr);
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
                            if (m.name.endsWith('(this app)')) return false;
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
                            if (m.name.endsWith('(this app)')) return false;
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
         * The " (this app)" suffix added by the native layer to the current
         * client's own entry is stripped before comparison, so it is safe to
         * pass the current client's own name if needed.
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
                const current = new Set(
                    this._members().map(m => m.name.replace(/ \(this app\)$/, ''))
                );
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

    const _connectSocket = async (password) => {
        await _initWasm();

        const { initClient, sendHandshake } = _wasmExports;

        _socket = new WebSocket(self.wsUrl);
        _socket.binaryType = 'arraybuffer';

        _socket.onmessage = (event) => {
            const buf = new Uint8Array(event.data);
            _wasmExports.parseAndStoreMessage(_encodeBuffer(buf), buf.byteLength, self.connNum);
        };

        _socket.onclose = () => {
            // Reject any outstanding RPC promises.
            for (const msgData of Object.values(self.pendingMessages)) {
                if (!Array.isArray(msgData)) {
                    if (msgData.timeoutId) clearTimeout(msgData.timeoutId);
                    delete self.pendingMessages[msgData.uuid];
                    msgData.reject('Connection closed unexpectedly');
                }
            }
            self.closed = true;
            _scheduleReconnect(password);
        };

        // Wait for the socket to open (up to 4 s).
        await new Promise((resolve, reject) => {
            let attempts = 0;
            const iv = setInterval(() => {
                if (attempts++ > 20) { clearInterval(iv); reject(new Error('WebSocket open timeout')); }
                else if (_socket.readyState === WebSocket.OPEN) { clearInterval(iv); resolve(); }
            }, 200);
        });

        self.closed = false;
        // Free any previous WASM slot so it doesn't accumulate across reconnects.
        if (self.connNum != null) {
            try { _wasmExports.stopClient(self.connNum); } catch (_) {}
            self.connNum = null;
        }
        const connNum = initClient(_encodeStringZ(self.name));
        self.connNum  = connNum;
        const hsUuid  = sendHandshake(_encodeStringZ(password), connNum);
        const hsResult = await new Handler('', null, 1, true)
            ._waitWithTimeout(hsUuid, 5000, '');
        console.log(`[daffi] "${self.name}" connected. type: ${hsResult.meta.type}`);
        _reconnectAttempt = 0; // reset counter on success
        return new Connection();
    };

    // ── Public API ────────────────────────────────────────────────────────────

    /** Connect to the server and return a Connection. */
    this.connect = async (password) => {
        password = password || '';
        return _connectSocket(password);
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
