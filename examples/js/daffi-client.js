'use strict';

/**
 * DaffiClient — browser WebSocket client for daffi.
 *
 * Based on js-client/app.js, extended with:
 *  - configurable WebSocket URL and WASM path
 *  - msgpack serde support (serde: "msgpack" | 3)
 *  - decoder-aware _storeMessage (uses the 5th decoder param added in wasm.zig)
 *
 * Supported serde values in rpc() / rpc_nowait():
 *   "json" | 1  — JSON-encoded args/result (default)
 *   "raw"  | 0  — OPAQUE: pass a single Uint8Array or string, get raw bytes back
 *   "msgpack" | 3 — msgpack-encoded; requires MessagePack global (msgpack-lite CDN)
 *
 * Usage:
 *   const client = new DaffiClient("my-app", {
 *     wsUrl:    "ws://127.0.0.1:5001",
 *     wasmPath: "/zig-out/lib/app.wasm",
 *   });
 *   const conn = await client.connect();
 *   const result = await conn.rpc({ timeout: 5000 }).add(3, 4);
 */
function DaffiClient(name, options) {
    options = options || {};
    this.name = name;
    this.wsUrl = options.wsUrl || 'ws://127.0.0.1:5000';
    this.wasmPath = options.wasmPath || '/zig-out/lib/app.wasm';
    this.pendingMessages = {};
    this.eventHandlers = [];
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
            const buffer = new TextEncoder().encode(string);
            const pointer = allocUint8(buffer.length + 1);
            const slice = new Uint8Array(memory.buffer, pointer, buffer.length + 1);
            slice.set(buffer);
            slice[buffer.length] = 0;
            return pointer;
        };

        const encodeBuffer = (buffer) => {
            const len = buffer.byteLength;
            const pointer = allocUint8(len);
            new Uint8Array(memory.buffer, pointer, len).set(buffer);
            return pointer;
        };

        const encodeBufferZ = (buffer) => {
            const len = buffer.byteLength;
            const pointer = allocUint8(len + 1);
            const slice = new Uint8Array(memory.buffer, pointer, len + 1);
            slice.set(buffer);
            slice[len] = 0;
            return pointer;
        };

        // ── msgpack helper (optional — only needed for serde="msgpack") ─────
        const _mp = () => {
            const lib = globalThis.msgpack || globalThis.MessagePack;
            if (!lib) throw new Error(
                'msgpack library not loaded. Add a script tag for msgpack-lite or @msgpack/msgpack before using serde="msgpack".'
            );
            return lib;
        };

        // ── WASM imports ────────────────────────────────────────────────────
        // The WASM is built as a position-independent dynamic library
        // (linkage = .dynamic, pic = true in build.zig).  All five PIC-mode
        // symbols must be supplied by the host at instantiation time.
        const INITIAL_PAGES = 256;  // 16 MB
        const memory = new WebAssembly.Memory({ initial: INITIAL_PAGES, maximum: 65536 });
        // Indirect-call table — size 128 covers typical Zig stdlib usage.
        const indirectFunctionTable = new WebAssembly.Table({ initial: 128, element: 'anyfunc' });
        // Stack grows downward from the top of initial memory.
        const stackPointer = new WebAssembly.Global({ value: 'i32', mutable: true  }, INITIAL_PAGES * 65536);
        const memoryBase    = new WebAssembly.Global({ value: 'i32', mutable: false }, 0);
        const tableBase     = new WebAssembly.Global({ value: 'i32', mutable: false }, 1);

        const {
            exports: { allocUint8, free, sendHandshake, sendMessage, parseAndStoreMessage, initClient },
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

                // decoder: 0=OPAQUE, 1=JSON, 2=PICKLE, 3=MSGPACK
                // (5th param added in wasm.zig; older JS ignores it safely)
                _storeMessage(pointer, length, uuid, isError, decoder) {
                    let message;
                    if (decoder === 3) {
                        // MSGPACK — decode binary payload
                        const raw = new Uint8Array(memory.buffer, pointer, length);
                        const mp = _mp();
                        const decoded = mp.decode ? mp.decode(raw.slice()) : mp.decode(raw.slice());
                        // Python serializes return value as [[result], {}]
                        message = Array.isArray(decoded) ? decoded[0][0] : decoded;
                    } else if (decoder === 0) {
                        // OPAQUE — give back a copy of the raw bytes
                        // If the bytes look like JSON, parse them; otherwise return Uint8Array.
                        const text = decodeString(pointer, length);
                        try { message = JSON.parse(text); } catch { message = new Uint8Array(memory.buffer, pointer, length).slice(); }
                    } else {
                        // JSON (default) — { args: [result], kwargs: {} }
                        message = JSON.parse(decodeString(pointer, length));
                    }

                    const msgData = self.pendingMessages[uuid];
                    if (msgData && !Array.isArray(msgData)) {
                        if (msgData.timeoutId) window.clearTimeout(msgData.timeoutId);
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
                                if (msgData.timeoutId) window.clearTimeout(msgData.timeoutId);
                                delete self.pendingMessages[msgData.uuid];
                                msgData.reject(`"${event.member}" disconnected`);
                            }
                        }
                    }
                    for (const handler of self.eventHandlers) handler(event);
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
                    if (msgData.timeoutId) window.clearTimeout(msgData.timeoutId);
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

        // ── Proxy handler ────────────────────────────────────────────────────
        class Handler {
            constructor(receiver, timeout, serde, returnResult, connNum) {
                this.receiver = receiver;
                this.timeout = timeout;
                this.serde = serde;         // 0=OPAQUE, 1=JSON, 3=MSGPACK
                this.returnResult = returnResult;
                this.connNum = connNum;
            }

            get(target, prop) {
                const handler = this;
                const fn = async (...args) => {
                    let argsZ;
                    if (handler.serde === 1) {
                        // JSON: standard {args, kwargs} wrapper
                        argsZ = encodeStringZ(JSON.stringify({ args, kwargs: {} }));
                    } else if (handler.serde === 3) {
                        // MSGPACK: encode [[args], {}] with msgpack-lite
                        const mp = _mp();
                        const encoded = mp.encode ? mp.encode([args, {}]) : mp.encode([args, {}]);
                        argsZ = encodeBufferZ(encoded instanceof Uint8Array ? encoded : new Uint8Array(encoded));
                    } else {
                        // OPAQUE: single buffer or string argument
                        if (args.length === 1) {
                            if (!handler.returnResult && args[0] instanceof GeneratorFunctionT) {
                                for (const arg of args[0]()) fn(arg);
                                return undefined;
                            }
                            const buf = args[0] instanceof Uint8Array ? args[0] : new TextEncoder().encode(args[0]);
                            argsZ = encodeBufferZ(buf);
                        } else {
                            throw new Error('OPAQUE serde expects exactly one argument (Uint8Array or string).');
                        }
                    }

                    const receiverZ = encodeStringZ(handler.receiver);
                    const funcNameZ = encodeStringZ(prop);
                    const msgPtr = sendMessage(argsZ, receiverZ, funcNameZ, handler.serde, handler.returnResult, handler.connNum);

                    if (!handler.returnResult) { free(msgPtr); return; }

                    const view = new DataView(memory.buffer, msgPtr, 16);
                    const uuid        = view.getUint32(0, true);
                    const ptrLen      = view.getUint32(4, true);
                    const ptr         = view.getUint32(8, true);
                    const isJsonFlag  = view.getUint32(12, true);
                    const actualReceiver = decodeString(ptr, ptrLen);

                    const raw = handler.timeout
                        ? await handler._waitWithTimeout(uuid, handler.timeout, actualReceiver)
                        : await handler._wait(uuid, actualReceiver);

                    // For JSON serde, wasm.zig payload is {args:[result], kwargs:{}}
                    // so we unwrap args[0].  For msgpack/opaque, _storeMessage already
                    // resolved to the final value.
                    return (isJsonFlag && handler.serde === 1) ? raw.args[0] : raw;
                };
                return fn;
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
                    case 'json': case 1:    return 1;
                    case 'raw':  case 0:    return 0;
                    case 'msgpack': case 3: return 3;
                    default: throw new Error(`Unknown serde "${opt}". Use "json", "raw", or "msgpack".`);
                }
            }

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
        }

        // ── Handshake ─────────────────────────────────────────────────────────
        await waitForOpen(socket);
        self.closed = false;
        const connNum = initClient(encodeStringZ(self.name));
        self.connNum = connNum;
        const hsUuid = sendHandshake(encodeStringZ(password), connNum);
        const hsHandler = new Handler('', null, 1, true, connNum);
        const handshake = await hsHandler._waitWithTimeout(hsUuid, 5000, '');
        console.log(`[daffi] "${self.name}" connected. type: ${handshake.meta.type}`);
        return new Connection(connNum);
    };

    this.addEventHandler = (fn) => self.eventHandlers.push(fn);
}
