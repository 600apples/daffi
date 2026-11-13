# Daffi

High-performance RPC for Python.

[![Performance](https://img.shields.io/badge/Performance-Native%20Core-blue)](#)
[![Transports](https://img.shields.io/badge/Transports-TCP%20%7C%20Unix-green)](#)
[![Python](https://img.shields.io/badge/Python-3.10%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Daffi is a lightweight inter-process communication framework powered by a compiled native core. 
Connect Python applications, distribute workloads, and exchange data with minimal overhead.

---

## Why Daffi?

- **No external broker required** — Establish direct connections without additional infrastructure.
- **Simple remote calls** — Invoke remote functions through familiar Python interfaces.
- **Multiple communication patterns** — Support RPC, broadcast, and streaming.
- **Native runtime** — Choose between threaded and event-driven connection handling.
- **Efficient data transfer** — Exchange large binary payloads with minimal overhead.

---

## Installation

```bash
pip install daffi
```

Requires Python 3.10 or newer.

---

## Two topologies

Daffi supports two primary communication topologies:

| Topology                     | Description                                                                                |
|------------------------------|--------------------------------------------------------------------------------------------|
| **Client → Service**         | A Service exposes callbacks; Clients call them directly.                                   |
| **Client → Router → Worker** | A Router forwards calls between Callers and Workers. Workers can join or leave at runtime. |

See [Architecture](architecture.md) for diagrams and component roles, or jump to [Getting Started](getting-started.md) for runnable examples.

---

## Documentation

| Topic                      | Page                                            |
|----------------------------|-------------------------------------------------|
| Direct Client → Service    | [Direct topology](usage/service.md)             |
| Router and workers         | [Router and workers](usage/router.md)           |
| `rpc` / `cast` / `stream`  | [Communication patterns](usage/call-styles.md)  |
| Wire formats               | [Serialization](usage/serialization.md)         |
| `@callback` and `workers`  | [Callbacks and concurrency](usage/callbacks.md) |
| `threads` vs `evented`     | [Native runtime](usage/runtime.md)              |
| TCP, Unix, multi-transport | [Transports](usage/transports.md)               |
| Membership notifications   | [Event handlers](usage/events.md)               |
| TLS                        | [Security](usage/tls.md)                        |
| Asyncio API                | [Async interface](usage/aio.md)                 |
