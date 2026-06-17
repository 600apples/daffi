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

.PHONY: test-overflow
test-overflow:  ## Run ClientMessageStore overflow / StoreFull tests
	$(PYTEST) tests/integration/test_store_overflow.py $(PYTEST_OPTS)

.PHONY: test-timeouts
test-timeouts:  ## Run timeout-behaviour tests (rpc, cast, rpc_nowait)
	$(PYTEST) tests/integration/test_timeouts.py $(PYTEST_OPTS)

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

# ── Wheels ────────────────────────────────────────────────────────────────────
# Prerequisites (install once):
#   pipx install cibuildwheel          # wheel builder
#   pip install twine                  # PyPI uploader
#   Docker must be running for Linux targets.
#
# Linux wheels  : run inside manylinux Docker containers.
#   x86_64  → works out of the box (native Docker).
#   aarch64 → requires QEMU binfmt on the host first:
#               sudo apt-get install -y qemu-user-static   # Debian/Ubuntu
#             …or once Docker-based:
#               make wheels-qemu
#
# macOS wheels  : must be executed ON a macOS machine (the binary must be
#                 compiled for the target OS natively).  Run on both an
#                 Apple Silicon and an Intel Mac to cover both arches, or
#                 let CI handle macOS.

WHEELHOUSE ?= wheelhouse
# Honour a pre-installed cibuildwheel binary (pipx) or fall back to the
# module form (pip install cibuildwheel).
CIBW        = cibuildwheel --output-dir $(WHEELHOUSE)

# Architectures to build locally.  Override on the command line to add
# aarch64 once QEMU is set up, e.g.:  make wheels-linux LINUX_ARCHS=x86_64,aarch64
LINUX_ARCHS ?= x86_64

.PHONY: wheels wheels-linux wheels-linux-all wheels-macos wheels-qemu wheels-ci wheels-upload wheels-clean

wheels: wheels-linux  ## Build local Linux wheels; use wheels-ci to build Linux+macOS via GitHub Actions

wheels-linux:  ## Build Linux manylinux wheels — requires Docker (see LINUX_ARCHS)
	@echo "==> Building Linux manylinux wheels (cp310..cp313 × $(LINUX_ARCHS))..."
	$(CIBW) --platform linux --archs $(LINUX_ARCHS) .

wheels-linux-all:  ## Build Linux manylinux wheels for x86_64 AND aarch64 — needs QEMU
	@echo "==> Building Linux manylinux wheels (cp310..cp313 × x86_64 + aarch64)..."
	@echo "    If aarch64 fails, run: sudo apt-get install -y qemu-user-static"
	$(CIBW) --platform linux --archs x86_64,aarch64 .

wheels-macos:  ## Build macOS wheels for the native host arch — run on macOS
	@echo "==> Building macOS wheels (native arch: $$(uname -m))..."
	$(CIBW) --platform macos .

wheels-qemu:  ## Register QEMU binfmt handlers for multi-arch emulation (run once)
	@echo "==> Registering QEMU binfmt handlers for aarch64 emulation..."
	@# On Debian/Ubuntu the package-level install is the most reliable method:
	@#   sudo apt-get install -y qemu-user-static
	@# It writes to /proc/sys/fs/binfmt_misc directly via update-binfmts.
	@# The Docker-only fallback below works on some setups but not all.
	@if command -v apt-get >/dev/null 2>&1; then \
	    echo "Debian/Ubuntu detected — running: sudo apt-get install -y qemu-user-static"; \
	    sudo apt-get install -y qemu-user-static; \
	else \
	    echo "Non-Debian system — trying Docker-based binfmt registration..."; \
	    docker run --rm --privileged tonistiigi/binfmt --install all; \
	fi
	@echo "Registered handlers:"
	@ls /proc/sys/fs/binfmt_misc/ 2>/dev/null || echo "(none visible — may need a re-login)"

wheels-ci:  ## Trigger GitHub Actions to build all wheels (Linux + macOS), then download them
	@echo "==> Triggering wheels.yml on GitHub Actions …"
	gh workflow run wheels.yml --ref main
	@echo "Waiting 15 s for the run to be registered …"
	sleep 15
	$(eval RUN_ID := $(shell gh run list --workflow=wheels.yml --limit 1 --json databaseId --jq '.[0].databaseId'))
	@echo "Run ID: $(RUN_ID)"
	@echo "Waiting for all jobs to finish (this may take 10–15 minutes) …"
	gh run watch $(RUN_ID)
	gh run download $(RUN_ID) --dir $(WHEELHOUSE)/
	@echo ""
	@echo "  Wheels downloaded to $(WHEELHOUSE)/."

wheels-upload:  ## Upload all wheels in $(WHEELHOUSE)/ to PyPI
	@echo "==> Uploading $(WHEELHOUSE)/*.whl to PyPI..."
	@echo "    Set TWINE_PASSWORD=<your-token> and optionally TWINE_USERNAME=__token__"
	TWINE_USERNAME=$${TWINE_USERNAME:-__token__} twine upload --non-interactive $(WHEELHOUSE)/*.whl

wheels-clean:  ## Remove the wheelhouse/ directory
	rm -rf $(WHEELHOUSE)

# ── Release ───────────────────────────────────────────────────────────────────
# Prerequisites (install once): pip install hatch
#
# Usage:
#   make release-patch   # 3.0.0 → 3.0.1
#   make release-minor   # 3.0.0 → 3.1.0
#   make release-major   # 3.0.0 → 4.0.0
#
# Each target bumps the version in daffi/__about__.py, commits, tags, and
# pushes.  The tag push triggers the "Build & Publish Wheels" GitHub Action
# which builds wheels for all platforms and publishes to PyPI automatically.
#
# Requires a remote named "origin" with push access.

.PHONY: release-patch release-minor release-major _release

release-patch: _check-clean  ## Bump patch (x.y.Z), tag, push → triggers PyPI release
	@hatch version patch
	@$(MAKE) _release

release-minor: _check-clean  ## Bump minor (x.Y.0), tag, push → triggers PyPI release
	@hatch version minor
	@$(MAKE) _release

release-major: _check-clean  ## Bump major (X.0.0), tag, push → triggers PyPI release
	@hatch version major
	@$(MAKE) _release

_release:
	$(eval NEW_VERSION := $(shell hatch version))
	git add daffi/__about__.py
	git commit -m "chore: release $(NEW_VERSION)"
	git tag "$(NEW_VERSION)"
	git push origin HEAD --follow-tags
	@echo ""
	@echo "  Released $(NEW_VERSION) — wheels.yml is now building on GitHub Actions."

_check-clean:
	@if [ -n "$$(git status --porcelain)" ]; then \
	    echo "Error: working tree is not clean. Commit or stash your changes first."; \
	    exit 1; \
	fi

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
