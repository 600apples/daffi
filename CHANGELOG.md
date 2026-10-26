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
- Optional evented runtime for the native core, selected with
  `runtime=Runtime.EVENTED` (or `"evented"`) on a `Router`, `Service`,
  or `Client`. The default, when `runtime` is omitted, is `threads`.
  Connections are multiplexed over a few kqueue/epoll event-loop threads
  (`DAFFI_EVENT_LOOPS`, default: CPU count capped at 4) instead of one OS
  thread each. The choice is once per process and applies to clients as
  well as servers; a later constructor that disagrees raises
  `InitializationError`. `dfcore.getRuntime()` reports the active model.

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


## 3.0.1

### Added

- Async interface (`daffi.aio`).
- Lifecycle events and per-connection stop file descriptors.
- Release workflow that builds and publishes wheels on tag push.
