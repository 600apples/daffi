# Changelog

All notable changes to this project are documented in this file.

## 3.1.0


### Added

- Python 3.15 support (classifiers, CI test matrix and prebuilt wheels).
- TLS client verifies the server host name (DNS name or IP address) against
  the certificate when `ca_file` is given, and sends SNI.

### Changed

- Migrated to Zig 0.17
- **TLS:** the minimum protocol version is now TLS 1.2.
- `stop()` on a `Service` / `Router` now blocks until the native server has
  fully shut down, so the port can be rebound right after it returns.
- Server slots are reused after `stop()`, so a process can start and stop
  servers any number of times (the limit of 256 is now on servers running
  at the same time).


## 3.0.1

### Added

- Async interface (`daffi.aio`).
- Lifecycle events and per-connection stop file descriptors.
- Release workflow that builds and publishes wheels on tag push.
