# JavaScript Browser Examples

These examples connect a **browser** to a running Python daffi service or router
via WebSocket.  The same port accepts both native TCP (Python clients) and browser
WebSocket connections simultaneously — no extra gateway needed.

## Table of Contents

| # | Folder | Topology | Serde |
|---|--------|----------|-------|
| 01 | `01_service_json/` | Browser → Service | JSON |
| 02 | `02_service_msgpack/` | Browser → Service | MSGPACK |
| 03 | `03_router_json/` | Browser → Router → Python Worker | JSON |
| 04 | `04_router_msgpack/` | Browser → Router → Python Worker | MSGPACK |

## Quick Start

### 1. Build the WASM client module

```bash
# From repo root
zig build
# Produces zig-out/lib/app.wasm
```

### 2. Start an HTTP server from the repo root

The HTML pages load `/zig-out/lib/app.wasm` via an absolute path, so they
**must** be served over HTTP (not opened as `file://`).

```bash
# Python 3 — serves on http://localhost:8080
python3 -m http.server 8080
```

### 3. Run a specific example

```bash
# Terminal 1 — Python service / router
python examples/js/01_service_json/1_service.py

# Browser — open the HTML page
http://localhost:8080/examples/js/01_service_json/index.html
```

For router examples start the worker too:

```bash
# Terminal 1
python examples/js/03_router_json/1_router.py

# Terminal 2
python examples/js/03_router_json/2_worker.py

# Browser
http://localhost:8080/examples/js/03_router_json/index.html
```

## Architecture

```
Browser (WebSocket)
   │
   │  ws://127.0.0.1:PORT
   │
Python Server ── native TCP ── Python Clients / Workers
```

The browser loads `app.wasm` (compiled from Zig) which handles the daffi
message framing entirely in the browser.  The Python server speaks the same
binary wire format for both TCP and WebSocket frames.

## Client API (daffi-client.js)

```javascript
const client = new DaffiClient("my-browser-app", {
    wsUrl:    "ws://127.0.0.1:5010",   // daffi server WebSocket URL
    wasmPath: "/zig-out/lib/app.wasm", // path relative to HTTP server root
});

// Subscribe to connect/disconnect events before connecting
client.addEventHandler(event => {
    console.log(event.type, event.member); // "connected" | "disconnected"
});

const conn = await client.connect();   // performs daffi handshake

// Blocking RPC — returns a Promise
const result = await conn.rpc({ serde: "json",    timeout: 5000 }).add(3, 4);
const result = await conn.rpc({ serde: "msgpack", timeout: 5000 }).compute(data);

// Fire-and-forget
conn.rpc_nowait({ serde: "json" }).log_event(payload);

// Pin call to specific worker (router topology)
const result = await conn.rpc({ serde: "json", receiver: "worker-1" }).process(item);
```

### Serde options

| `serde` value | Encoding | Notes |
|---|---|---|
| `"json"` / `1` | JSON `{args:[…], kwargs:{}}` | Default. Works with any JSON-serialisable data. |
| `"msgpack"` / `3` | msgpack `[[args], {}]` | Requires `msgpack-lite` or `@msgpack/msgpack` loaded before `daffi-client.js`. |
| `"raw"` / `0` | OPAQUE pass-through | Single `Uint8Array` or `string` argument only. |

### MSGPACK library

Load before `daffi-client.js`:

```html
<!-- msgpack-lite (UMD — exposes globalThis.msgpack) -->
<script src="https://unpkg.com/msgpack-lite/dist/msgpack.min.js"></script>
<script src="../daffi-client.js"></script>
```
