# Changelog

All notable changes to this project are documented in this file.

## 4.0.0

### Breaking

- `Router`, `Service`, and `Client` all take addresses through `transport`.
  `Client` accepts a single `TCPTransport` or `UnixTransport`. `Router` and
  `Service` accept one transport or a sequence of them; every listener shares
  that node's membership. `host`, `port`, and `unix_sock_path` are gone.
- `start()` binds every transport in parallel and starts accepting on all of
  them at once, under one native handle. All or nothing: if one transport
  cannot be bound, none stays bound and the error names that address; if a
  later step of `start()` fails, every peer that already connected is
  dropped, every listener is closed and the workers are stopped.
  `stop()` stops every listener at the same moment. Duplicate transports are
  rejected. `dfcore.addListeners` binds the whole listener list and
  `dfcore.startServer` starts accepting; `dfcore.addListener` is gone.

### Added

- Python 3.15 support (classifiers, CI test matrix and prebuilt wheels).
- TLS client verifies the server host name (DNS name or IP address) against
  the certificate when `ca` is given, and sends SNI.
- Native runtime for the core, selected with `runtime` on a `Router`,
  `Service`, or `Client`. The default, when `runtime` is omitted, is
  `threads`: one OS thread per connection. Pass `runtime=Runtime.EVENTED`
  (or `"evented"`) to multiplex connections over a few kqueue/epoll
  event-loop threads (`DAFFI_EVENT_LOOPS`, default: one per CPU, capped at
  64). The choice is once per process and applies to clients as well as
  servers; a later constructor that disagrees raises `InitializationError`.
  `dfcore.getRuntime()` reports the active model.

### Changed

- Migrated to Zig 0.17
- **TLS:** the minimum protocol version is now TLS 1.2.
- `stop()` on a `Service` / `Router` now blocks until the native server has
  fully shut down, so the port can be rebound right after it returns.
- A listener whose `accept` keeps failing (for example the process is out of
  file descriptors) pauses 50 ms and tries again. Its sibling listeners keep
  accepting in the meantime.
- A Unix socket file deleted while the server is running is bound again
  within a second. A path another process has taken over is left alone, and
  connections that were already open stay open.
- Server slots are reused after `stop()`, so a process can start and stop
  servers any number of times (the limit of 256 is now on servers running
  at the same time).
- **Signals:** the native layer no longer installs SIGINT/SIGTERM handlers
  that ended the process with `_exit(0)`. Python stops every running app and
  then defers to the handler that was installed before: Ctrl+C raises
  `KeyboardInterrupt` as usual, a user handler is called, and a default
  action (e.g. SIGTERM) terminates the process with that signal.
- Waiting for a response happens in the native layer with the GIL released.
  Each response wakes only the call it belongs to (in `daffi.aio`, only that
  call's future), instead of every waiter on the client.
- A service whose task queue is full answers further requests with a
  `ServiceOverloaded` error instead of queueing them without limit.
- The Router answers a request it cannot deliver with a `ReceiverNotFound`
  or `DeliveryFailed` error, so the caller no longer waits out its timeout.
- An error raised by an `OPAQUE` callback is sent back as JSON.
- In `daffi.aio`, synchronous callbacks run in the default executor so a slow
  one does not block the event loop; `async def` callbacks are awaited.
- Writes to a peer that makes no progress for 5 s fail and drop that
  connection. TLS handshakes and protocol detection of an accepted
  connection must finish within 5 s overall.
- The evented runtime runs at most 1024 blocking jobs (TLS handshakes,
  WebSocket sessions) at once; further connections are refused.

### Fixed

- One callback, serialization, send or event-handler error no longer stops
  the dispatcher for every connection in the process; the caller gets the
  error.
- A response that arrives after its call was cancelled, interrupted or
  failed is dropped; it can no longer reach a later call that reuses the
  request id.
- A reply is decoded only with the serialization format of its request (or
  JSON for errors), so a peer cannot make a JSON caller unpickle data.
- More than 1024 open descriptors no longer break waiting for responses or
  tasks.
- `stop()` no longer races a send on the same connection, writes to a closed
  descriptor, or deadlocks against a stop started by a server shutdown.
- A WebSocket ping no longer disconnects the client, and control frames are
  never written into the middle of another frame.
- Eviction (another connection took this client's name) is reported as
  `Evicted`, and a disconnect during a call as `Disconnected`. An evicted
  client no longer reconnects and takes its name back.
- Automatic reconnect releases the previous connection; re-handshakes, Unix
  socket restores and failed writes no longer leak memory or descriptors.
- A connection whose write failed partway is closed instead of left with a
  corrupt stream.


## 3.0.1

### Added

- Async interface (`daffi.aio`).
- Lifecycle events and per-connection stop file descriptors.
- Release workflow that builds and publishes wheels on tag push.
