'use strict';

/**
 * DaffiClient — browser WebSocket + WASM client for daffi.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DISTRIBUTION — using daffi.js from a CDN
 * ─────────────────────────────────────────────────────────────────────────────
 * daffi.js ships together with app.wasm in the js-client/ folder of the
 * repository.  Both files are required; daffi.js loads app.wasm at runtime
 * via WebAssembly.compileStreaming() and the server must serve it with the
 * correct MIME type (application/wasm).
 *
 * The simplest way to consume them without hosting your own copy is via the
 * jsDelivr CDN, which serves any public GitHub file automatically:
 *
 *   <!-- 1. Load the JS client (replace TAG with a git tag or commit hash) -->
 *   <script src="https://cdn.jsdelivr.net/gh/600apples/daffi@TAG/js-client/daffi.js"></script>
 *
 *   <!-- 2. (optional) msgpack-lite — only needed for serde: "msgpack" -->
 *   <script src="https://unpkg.com/msgpack-lite/dist/msgpack.min.js"></script>
 *
 *   <script>
 *     const client = new DaffiClient("my-app", {
 *       wsUrl:    "ws://127.0.0.1:5000",
 *       // Point wasmPath at the same CDN release so the browser can fetch it:
 *       wasmPath: "https://cdn.jsdelivr.net/gh/600apples/daffi@TAG/js-client/app.wasm",
 *     });
 *   </script>
 *
 * For local development both files can live in the same directory.  The
 * default wasmPath ("./app.wasm") then resolves relative to the HTML page.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * QUICK START
 * ─────────────────────────────────────────────────────────────────────────────
 *   const client = new DaffiClient("my-app", { wsUrl: "ws://127.0.0.1:5000" });
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
 * DaffiClient(name, options)
 * ─────────────────────────────────────────────────────────────────────────────
 *   name              string   — Unique name for this browser client.
 *
 *   options.wsUrl     string   — WebSocket URL of the daffi Service or Router.
 *                                Default: "ws://127.0.0.1:5000"
 *
 *   options.wasmPath  string   — Absolute URL path to app.wasm served by your
 *                                HTTP server.
 *                                Default: "/zig-out/lib/app.wasm"
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
 *     Awaits all results and returns { peerName: result, … }.
 *
 *     options.receiver  string|string[] — Restrict broadcast to these peer names.
 *     options.timeout   number (ms)     — Per-peer timeout.
 *     options.serde     string|number   — Serialisation format (see SERDE below).
 *
 *   conn.cast_nowait(options) → Proxy
 *     Fire-and-forget broadcast to all matching peers.  No result.
 *     Same options as cast() except timeout is ignored.
 *
 *   conn.stream(options) → Proxy
 *     Alias for rpc_nowait().  Accepts generator functions as the single
 *     argument to send a sequence of OPAQUE messages:
 *       conn.stream({ serde: "raw" }).pipe(function* () { yield buf1; yield buf2; });
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
function DaffiClient(name, options) {
    options = options || {};
    this.name       = name;
    this.wsUrl      = options.wsUrl      || 'ws://127.0.0.1:5000';
    this.wasmPath   = options.wasmPath   || './app.wasm';
    this.pendingMessages = {};
    this.eventHandlers   = [];
    this.closed = true;
    const self = this;

    this.connect = async (password) => {
        password = password || '';
        const module = await WebAssembly.compileStreaming(fetch(self.wasmPath));

        const GeneratorFunctionT = (function* () { yield undefined; }).constructor;

        // ── memory helpers ──────────────────────────────────────────────────
        const decodeString = (pointer, length) =>
            new TextDecoder().decode(new Uint8Array(memory.buffer, pointer, length));

        const encodeStringZ = (string) => {
            const buf = new TextEncoder().encode(string);
            const ptr = allocUint8(buf.length + 1);
            const slice = new Uint8Array(memory.buffer, ptr, buf.length + 1);
            slice.set(buf);
            slice[buf.length] = 0;
            return ptr;
        };

        const encodeBuffer = (buffer) => {
            const len = buffer.byteLength;
            const ptr = allocUint8(len);
            new Uint8Array(memory.buffer, ptr, len).set(buffer);
            return ptr;
        };

        const encodeBufferZ = (buffer) => {
            const len = buffer.byteLength;
            const ptr = allocUint8(len + 1);
            const slice = new Uint8Array(memory.buffer, ptr, len + 1);
            slice.set(buffer);
            slice[len] = 0;
            return ptr;
        };

        // ── optional msgpack helper ─────────────────────────────────────────
        const _mp = () => {
            const lib = globalThis.msgpack || globalThis.MessagePack;
            if (!lib) throw new Error(
                'msgpack library not loaded. ' +
                'Add <script src="https://unpkg.com/msgpack-lite/dist/msgpack.min.js"> before app.js.'
            );
            return lib;
        };

        // ── WASM PIC-mode imports ───────────────────────────────────────────
        // app.wasm is built as a position-independent dynamic library
        // (linkage = .dynamic in build.zig).  The five symbols below are
        // required by every PIC WASM module and must come from the host.
        const INITIAL_PAGES = 256;                                          // 16 MB
        const memory        = new WebAssembly.Memory({ initial: INITIAL_PAGES, maximum: 65536 });
        const indirectFunctionTable = new WebAssembly.Table({ initial: 128, element: 'anyfunc' });
        // Stack grows downward from the top of initial memory.
        const stackPointer  = new WebAssembly.Global({ value: 'i32', mutable: true  }, INITIAL_PAGES * 65536);
        const memoryBase    = new WebAssembly.Global({ value: 'i32', mutable: false }, 0);
        const tableBase     = new WebAssembly.Global({ value: 'i32', mutable: false }, 0);

        const {
            exports: { allocUint8, free, sendHandshake, sendMessage, parseAndStoreMessage, initClient, getAvailableMembers },
        } = await WebAssembly.instantiate(module, {
            env: {
                memory,
                __indirect_function_table: indirectFunctionTable,
                __stack_pointer:           stackPointer,
                __memory_base:             memoryBase,
                __table_base:              tableBase,
                _throwError(pointer, length) { throw new Error(decodeString(pointer, length)); },
                _consoleLog(pointer, length)  { console.log(decodeString(pointer, length));   },
            },
            window: {
                _sendToSocket(pointer, length) {
                    socket.send(memory.buffer.slice(pointer, pointer + length));
                },

                // decoder: 0=OPAQUE, 1=JSON, 2=PICKLE(unsupported in JS), 3=MSGPACK
                _storeMessage(pointer, length, uuid, isError, decoder) {
                    let message;
                    if (decoder === 3) {
                        const raw = new Uint8Array(memory.buffer, pointer, length).slice();
                        const decoded = _mp().decode(raw);
                        // Python serialises return value as [[result], {}]
                        message = Array.isArray(decoded) ? decoded[0][0] : decoded;
                    } else if (decoder === 0) {
                        const text = decodeString(pointer, length);
                        try { message = JSON.parse(text); } catch { message = new Uint8Array(memory.buffer, pointer, length).slice(); }
                    } else {
                        // JSON (default)
                        message = JSON.parse(decodeString(pointer, length));
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

                _triggerEvent(pointer, length) {
                    const event = JSON.parse(decodeString(pointer, length));
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

        // ── WebSocket ────────────────────────────────────────────────────────
        const socket = new WebSocket(self.wsUrl);
        socket.binaryType = 'arraybuffer';

        socket.onmessage = (event) => {
            const buffer = new Uint8Array(event.data);
            parseAndStoreMessage(encodeBuffer(buffer), buffer.byteLength, self.connNum);
        };

        socket.onclose = () => {
            for (const msgData of Object.values(self.pendingMessages)) {
                if (!Array.isArray(msgData)) {
                    if (msgData.timeoutId) clearTimeout(msgData.timeoutId);
                    delete self.pendingMessages[msgData.uuid];
                    msgData.reject('Connection closed unexpectedly');
                }
            }
            self.closed = true;
        };

        const waitForOpen = (sock) => new Promise((resolve, reject) => {
            let attempts = 0;
            const iv = setInterval(() => {
                if (attempts++ > 20) { clearInterval(iv); reject(new Error('Connection timeout')); }
                else if (sock.readyState === sock.OPEN) { clearInterval(iv); resolve(); }
            }, 200);
        });

        // ── Proxy handler ─────────────────────────────────────────────────────
        class Handler {
            constructor(receiver, timeout, serde, returnResult, connNum) {
                this.receiver     = receiver;
                this.timeout      = timeout;
                this.serde        = serde;       // 0=OPAQUE, 1=JSON, 3=MSGPACK
                this.returnResult = returnResult;
                this.connNum      = connNum;
            }

            get(target, prop) {
                const handler = this;
                return async (...args) => {
                    let argsZ;
                    if (handler.serde === 1) {
                        argsZ = encodeStringZ(JSON.stringify({ args, kwargs: {} }));
                    } else if (handler.serde === 3) {
                        const enc = _mp().encode([args, {}]);
                        argsZ = encodeBufferZ(enc instanceof Uint8Array ? enc : new Uint8Array(enc));
                    } else {
                        // OPAQUE — single buffer or string
                        if (args.length !== 1) throw new Error('OPAQUE serde expects exactly one argument.');
                        if (!handler.returnResult && args[0] instanceof GeneratorFunctionT) {
                            for (const arg of args[0]()) handler.get(target, prop)(arg);
                            return;
                        }
                        const buf = args[0] instanceof Uint8Array ? args[0] : new TextEncoder().encode(args[0]);
                        argsZ = encodeBufferZ(buf);
                    }

                    const receiverZ  = encodeStringZ(handler.receiver);
                    const funcNameZ  = encodeStringZ(prop);
                    const msgPtr     = sendMessage(argsZ, receiverZ, funcNameZ, handler.serde, handler.returnResult, handler.connNum);

                    if (!handler.returnResult) { free(msgPtr); return; }

                    const view           = new DataView(memory.buffer, msgPtr, 16);
                    const uuid           = view.getUint32(0, true);
                    const ptrLen         = view.getUint32(4, true);
                    const ptr            = view.getUint32(8, true);
                    const isJsonFlag     = view.getUint32(12, true);
                    const actualReceiver = decodeString(ptr, ptrLen);

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

        // ── Connection ────────────────────────────────────────────────────────
        class Connection {
            constructor(connNum) { this.connNum = connNum; }

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
                    this.connNum,
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
                    this.connNum,
                ));
            }

            /** Stream — alias for rpc_nowait, accepts generator functions. */
            stream(options) { return this.rpc_nowait(options); }

            /**
             * Return the list of currently connected members from the native layer.
             * Each entry: { name: string, methods: string[] | null }
             * Members representing this client have "(this app)" appended to their name.
             */
            _members() {
                const ptr = getAvailableMembers(this.connNum);
                const json = decodeString(ptr, new Uint8Array(memory.buffer, ptr).indexOf(0));
                free(ptr);
                return JSON.parse(json).members || [];
            }

            /**
             * Broadcast a call to every connected peer that exposes the requested
             * method and collect all results.
             *
             * Returns a Promise resolving to { receiverName: result, ... }.
             *
             * Options:
             *   receiver  — string | string[] — restrict broadcast to these names
             *   timeout   — ms (default: no timeout)
             *   serde     — "json" | "msgpack" | "raw"  (default: "json")
             *
             * Example:
             *   const results = await conn.cast({ timeout: 5000 }).add(1, 2);
             *   // { "worker-1": 3, "worker-2": 3 }
             */
            cast(options) {
                if (self.closed) throw new Error('Connection is closed');
                options = options || {};
                const serde   = this._serde(options.serde);
                const timeout = options.timeout || null;
                const filter  = options.receiver
                    ? (Array.isArray(options.receiver) ? options.receiver : [options.receiver])
                    : null;
                const connNum = this.connNum;
                const conn    = this;

                return new Proxy({}, {
                    get(_, prop) {
                        return async (...args) => {
                            const members = conn._members();
                            const targets = members.filter(m => {
                                if (!m.methods) return false;           // no callbacks (e.g. JS client)
                                if (m.name.endsWith('(this app)')) return false;
                                if (!m.methods.includes(prop)) return false;
                                if (filter) return filter.some(f => m.name.startsWith(f));
                                return true;
                            });
                            if (targets.length === 0) throw new Error(`No connected peer exposes "${prop}"`);
                            const results = await Promise.all(
                                targets.map(async (m) => {
                                    const h = new Handler(m.name, timeout, serde, true, connNum);
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
             *
             * Options: same as cast() except timeout is ignored.
             */
            cast_nowait(options) {
                if (self.closed) throw new Error('Connection is closed');
                options = options || {};
                const serde  = this._serde(options.serde);
                const filter = options.receiver
                    ? (Array.isArray(options.receiver) ? options.receiver : [options.receiver])
                    : null;
                const connNum = this.connNum;
                const conn    = this;

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
                                new Handler(m.name, null, serde, false, connNum).get({}, prop)(...args);
                            }
                        };
                    },
                });
            }
        }

        // ── Handshake ─────────────────────────────────────────────────────────
        await waitForOpen(socket);
        self.closed  = false;
        const connNum = initClient(encodeStringZ(self.name));
        self.connNum  = connNum;
        const hsUuid  = sendHandshake(encodeStringZ(password), connNum);
        const hsResult = await new Handler('', null, 1, true, connNum)
            ._waitWithTimeout(hsUuid, 5000, '');
        console.log(`[daffi] "${self.name}" connected. type: ${hsResult.meta.type}`);
        return new Connection(connNum);
    };

    /** Subscribe to server events (connected / disconnected / etc.). */
    this.addEventHandler = (fn) => self.eventHandlers.push(fn);
}
