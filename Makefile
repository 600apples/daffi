.DEFAULT_GOAL := help

PYTEST      ?= pytest
PYTEST_OPTS ?= -v

# ── Tests ─────────────────────────────────────────────────────────────────────

.PHONY: test
test:  ## Run unit + integration tests (requires built dfcore extension)
	$(PYTEST) tests/unit tests/integration $(PYTEST_OPTS)

.PHONY: test-unit
test-unit:  ## Run unit tests only — fast, no server subprocess required
	$(PYTEST) tests/unit $(PYTEST_OPTS)

.PHONY: test-integration
test-integration:  ## Run integration tests — spawns Service / Router subprocesses
	$(PYTEST) tests/integration $(PYTEST_OPTS)

.PHONY: test-interruptions
test-interruptions:  ## Run connection-interruption tests (SIGSTOP / SIGKILL / restart)
	$(PYTEST) tests/integration/test_interruptions.py $(PYTEST_OPTS)

.PHONY: test-serde
test-serde:  ## Run serialisation-format tests (PICKLE / JSON / OPAQUE / MSGPACK)
	$(PYTEST) tests/integration/test_serde.py $(PYTEST_OPTS)

.PHONY: test-cov
test-cov:  ## Run all tests with coverage report
	$(PYTEST) tests/unit tests/integration \
	    --cov=daffi --cov-report=term-missing --cov-report=html $(PYTEST_OPTS)

.PHONY: ci
ci: test test-unit test-integration test-serde perf perf-concurrency perf-bigmsg  ## Full CI run: unit → integration (incl. interruptions + serde) → all benchmarks

# ── Performance benchmarks (not pytest — run as plain scripts) ───────────────

.PHONY: perf
perf:  ## Sequential RPC benchmark (100 k calls × layout × serde)
	python3 tests/perf/perf_benchmark.py

.PHONY: perf-concurrency
perf-concurrency:  ## Concurrent-clients benchmark (200 clients × 3 scenarios)
	python3 tests/perf/concurrency_benchmark.py

.PHONY: perf-bigmsg
perf-bigmsg:  ## Big-message throughput benchmark (1 KiB → 28 MiB)
	python3 tests/perf/big_message_benchmark.py

# ── Docs ──────────────────────────────────────────────────────────────────────

.PHONY: docs
docs:  ## Serve the documentation locally (hot-reload on file changes)
	hatch run docs:serve

.PHONY: docs-build
docs-build:  ## Build the documentation site into mkdocs_files/
	hatch run docs:build

.PHONY: docs-clean
docs-clean:  ## Remove the generated docs output directory
	hatch run docs:clean

# ── Build ─────────────────────────────────────────────────────────────────────

.PHONY: build
build:  ## Build WASM (ReleaseFast) + Python C extension — no debug prints
	zig build -Doptimize=ReleaseFast
	zig build python

.PHONY: dev
dev:  ## Build C extension in Debug mode — enables connection debug prints
	python3 setup.py build_ext --debug --inplace

.PHONY: wasm
wasm:  ## Compile app.wasm only (ReleaseFast); override with OPTIMIZE=Debug
	zig build -Doptimize=$(if $(OPTIMIZE),$(OPTIMIZE),ReleaseFast)

.PHONY: ext
ext:  ## Build the Python C extension (dfcore) in-place
	zig build python

# ── Help ──────────────────────────────────────────────────────────────────────

.PHONY: help
help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
