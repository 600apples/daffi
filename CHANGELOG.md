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
- **Security:** a `Service` or `Router` refuses PICKLE requests from
  WebSocket peers with a `SerdeNotAllowed` error, and a `Router` drops PICKLE
  replies from them. Any web page can open a WebSocket to a local server,
  and unpickling runs code the sender chooses.
- `rpc_nowait()` sends exactly one call with the arguments it is given.
  It used to send one call per item when the first argument was a list or
  other iterable, and dropped keyword arguments; use `stream_nowait()` to
  send a sequence item by item.
- **Security:** a request is only accepted from a peer that has completed
  the handshake, under the name it registered; a request naming another
  peer as its sender gets `UnknownSender`. A Router only accepts a reply
  from the peer it routed the request to.
- **TLS:** a client with `tls=True` and no `ca` verifies the server against
  the system trust store; before, it encrypted without verifying. Pass
  `verify=False` on the transport for the old behaviour.
- A Unix socket path reaches the native layer as `unix:<path>`; a TCP host
  that does not resolve is an error and is never used as a socket path. A
  server refuses to bind over a file that is not a socket, or over a socket
  another server is still accepting on, instead of deleting it.
- wasm exports: `initClient(name, name_len, token, token_len)`; payloads
  cross as pointer and length, and `freeSendResult` releases a send result.
  Use the `daffi.js` and `app.wasm` of the same release.
- `daffi.exceptions` exports `DaffiError`, the base of every daffi
  exception. `BaseException` is still importable from `daffi.exceptions`
  as an alias, but `from daffi.exceptions import *` no longer shadows the
  built-in `BaseException`.
- Logging goes through one `daffi` logger (the app name is in the record as
  `daffi_app`) instead of one logger per app name, and propagates to the
  application's handlers. daffi prints to the console itself only while
  the root logger has no handlers.

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
- `serdes=` on `Service`, `Client` and their async counterparts: the
  `SerdeFormat` values accepted in incoming requests. A request in another
  format is answered with a `SerdeNotAllowed` error before its payload is
  decoded. The default accepts every format; leave out `PICKLE` unless every
  peer is trusted.
- `auth_token=` on `Router`, `Service`, `Client` and their async
  counterparts (`authToken` in the JS client): a shared secret every peer
  must send in its handshake. A peer without it is disconnected before it
  can call anything or take a name.
- `allowed_origins=` on a listening `TCPTransport`: the web pages that may
  open a WebSocket to it. Other upgrades are refused with 403.
- `callbacks=` on `Service`, `Client` and their async counterparts: the
  callbacks this node offers. Default: every registered callback.
- `verify=` on `TCPTransport` and `UnixTransport` (see Breaking).
- `rpc()` and `rpc_nowait()` accept a list of receivers and send to
  whichever of them is connected, taking turns.
- `dfcore.missingMembers(conn_num, names)`: the names that are not
  connected, read from the native membership.
- `DAFFI_FRAME_STALL_MS` (default 30000): a connection whose half-received
  message gets no further bytes for that long is closed.

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
  that ended the process with `_exit(0)`. A signal with the default action
  (e.g. SIGTERM) terminates the process at once, with that signal. Ctrl+C
  stops every running app and `join()` returns, also when the kernel
  delivers the signal to one of daffi's threads; under `asyncio.run` on
  Python 3.11+ it raises `KeyboardInterrupt` as usual. A handler the program
  installed before daffi is still called.
- `stop()` returns at once. Callbacks still running are abandoned (async
  ones are cancelled) and their replies dropped; queued tasks are discarded.
  Worker threads no longer keep the process alive after it.
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
  WebSocket sessions) at once; further connections are refused. WebSocket
  sessions may take at most 768 of them, so idle browser tabs cannot use up
  the pool.
- A service's task queue also has a byte limit (256 MiB), and messages
  still being received share a 1 GiB budget across the process. Past
  either, requests get `ServiceOverloaded` or the connection is closed. A
  Router answers `RouterOverloaded` past 2^20 requests in flight.
- Large messages are sent as header and payload in one `writev`, without
  copying the payload.
- In the evented runtime a connection reads at most 16 messages per turn,
  so a busy peer cannot starve the others on its loop. A write to a slow
  peer no longer blocks the event loop: what the socket does not take is
  queued (up to 64 MiB per connection, after which the connection is
  closed) and sent by a pool thread.
- Response timeouts, the accept loop and Unix socket restores use the
  monotonic clock, so a wall-clock change no longer cuts them short or
  stretches them.
- `Client.connect()` fails at once when the kernel refuses the connection,
  instead of waiting out the connect timeout.
- asyncio waiters take a list of uuids that arrived, instead of probing
  every pending call on each wakeup.
- Growing the open-file limit on macOS clamps to `kern.maxfilesperproc`
  when `setrlimit` refuses a value above it.

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
- `stop()` on an async `Service` or `Router` did not stop the server:
  listeners, the dispatcher and peer connections stayed open and `join()`
  never returned. Affects 3.0.x.
- Eviction (another connection took this client's name) is reported as
  `Evicted`, and a disconnect during a call as `Disconnected`. An evicted
  client no longer reconnects and takes its name back.
- Automatic reconnect releases the previous connection; re-handshakes, Unix
  socket restores and failed writes no longer leak memory or descriptors.
- A connection whose write failed partway is closed instead of left with a
  corrupt stream.
- A message whose text payload or names are not valid UTF-8 no longer stops
  the dispatcher, after which the node answered nothing. Such a payload
  reaches the callback as `bytes`.
- `start()` after `stop()` (or `connect()` after `stop()` on a client)
  resets the stopped state: the second `stop()` used to do nothing and leave
  the port open, and `join()` returned at once.
- A callback that runs on the shared poller thread (`workers=1`) and makes a
  blocking call no longer deadlocks when the answer has to come through
  another node of the same process: polling moves to a new thread first.
- A request with uuid 0 no longer aborts the receiving process.
- Request ids still waiting for a response are not reused, and a response
  goes to the connection that sent the request, not to a reconnected
  client that took the same name.
- A WebSocket message split over several frames no longer reads freed
  memory.
- The JS client passes payloads containing NUL bytes intact and no longer
  leaks the memory of send results.
- Publishing a service's callbacks no longer races a peer's handshake.
- A peer that handshakes again while a write to it is stalled no longer
  freezes routing through the Router.
- `@alias` works above and below `@callback`.
- `stream_nowait()` in `daffi.aio` uses the requested `serde`.
- The poller no longer spins at full CPU when `kevent`/`epoll_wait` fails.
- A client handler's method list and token are no longer leaked.
- A peer name copied for the channel map is no longer leaked when the map
  cannot grow.


## 3.0.1

### Added

- Async interface (`daffi.aio`).
- Lifecycle events and per-connection stop file descriptors.
- Release workflow that builds and publishes wheels on tag push.
