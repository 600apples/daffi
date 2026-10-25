# Changelog

All notable changes to this project are documented in this file.

## 4.0.0

### Breaking

- `Router` and `Service` take addresses through `transports`: one
  `TCPTransport` or `UnixTransport`, or a sequence of them. Every listener
  shares that node's membership. `Client` takes a single `transport`.
  `host`, `port`, and `unix_sock_path` are gone.
- `start()` binds every transport in parallel and starts accepting on all of
  them at once, under one native handle. All or nothing: if one transport
  cannot be bound, none stays bound and the error names that address; if a
  later step of `start()` fails, every peer that already connected is
  dropped, every listener is closed and the workers are stopped.
  `stop()` stops every listener at the same moment. Duplicate transports are
  rejected. `dfcore.startServer` takes the whole listener list;
  `dfcore.addListener` is gone.

### Added

- Python 3.15 support (classifiers, CI test matrix and prebuilt wheels).
- TLS client verifies the server host name (DNS name or IP address) against
  the certificate when `ca_file` is given, and sends SNI.
- Optional evented execution model for the native core, selected with
  `DAFFI_EXECUTION_MODEL=evented` (default `threads`). Connections of
  Routers, Services and Clients are multiplexed over a few kqueue/epoll
  event-loop threads (`DAFFI_EVENT_LOOPS`, default: CPU count capped at 4)
  instead of one OS thread each. `dfcore.getExecutionModel()` reports the
  active model.

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
