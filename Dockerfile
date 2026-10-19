# Base container
FROM python:3.14-slim AS base
# ============================================================
# Stage 1: builder
# Install uv, resolve and install all dependencies into .venv
# ============================================================
FROM base AS builder

# Copy uv binary from the official distroless image.
# Pin to a specific version for reproducible builds.
COPY --from=ghcr.io/astral-sh/uv:0.11.21 /uv /uvx /bin/

# ── System build dependencies ──────────────────────────────
# python:3.14-slim ships almost nothing. We need:
#
#   git             – uv clones open-climate-service directly from
#                     GitHub (git+https://...), this must be present
#                     before uv sync runs.
#
#   build-essential – meta-package that pulls in gcc, g++, make,
#                     and the standard C headers. Required to compile
#                     C extensions in the dependency tree:
#                       - numpy (C)
#                       - numcodecs (C/Cython, used by zarr)
#                       - aiohttp (C, used by openeo stack)
#                       - multidict / frozenlist (C, aiohttp deps)
#
#   python3-dev     – provides Python.h and the distutils headers
#                     that Cython-based wheels need at compile time.
#
#   libffi-dev      – cffi (pulled in by cryptography / aiohttp)
#                     links against libffi at build time.
#
#   pkg-config      – some packages (e.g. aiohttp) call pkg-config
#                     during their build to locate system libs.
#
# We clean apt lists afterwards so they don't bloat the layer.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        build-essential \
        python3-dev \
        libffi-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Tell uv never to try to download Python — use the one in this image.
ENV UV_PYTHON_DOWNLOADS=never

# UV_LINK_MODE=copy is required in Docker because the uv cache mount
# and the target .venv are on different filesystems. Without this,
# uv tries to hardlink/reflink and silently falls back or errors.
ENV UV_LINK_MODE=copy

# Compile .pyc files at build time so the container starts faster.
ENV UV_COMPILE_BYTECODE=1

WORKDIR /app

COPY pyproject.toml uv.lock ./

# ── Cache-bust on new open-climate-service commits ─────────────
# open-climate-service is installed straight from its GitHub `main`
# branch (see pyproject.toml / uv.lock). Docker's ADD instruction for
# a remote URL re-checks the response (ETag/Last-Modified) on every
# build and busts the layer cache — and everything after it — when
# the resource changed, i.e. whenever `main` gets new commits. This
# is what forces the steps below to actually re-run instead of being
# served from a stale cached layer.
ADD https://api.github.com/repos/dhis2/open-climate-service/commits/main /tmp/open-climate-service-head.json

# Re-resolve open-climate-service to the current tip of `main` (the
# committed uv.lock may pin an older commit), then install. --locked
# still guards the rest of the dependency tree against drift.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv lock --upgrade-package open-climate-service \
    && uv sync --locked

# Instance config is baked into the image (copied in the runtime stage).
COPY climate-service.yaml ./


# ============================================================
# Stage 2: runtime
# Minimal image — only Python, the venv, and instance files.
# No uv, no git, no build tools.
# ============================================================
FROM base AS runner

# ── Runtime-only system libraries ──────────────────────────
# The compiled C extensions (.so files) inside the venv link against
# shared libraries that must exist in the runtime image too. The
# build tools (gcc, headers) are NOT needed, only the runtime libs:
#
#   libgomp1    – OpenMP runtime, linked by numpy's BLAS routines.
#   libstdc++6  – C++ standard library, linked by several extensions.
#   libexpat1   - C library for parsing XML files
#
# python:3.14-slim already ships libgcc-s1 and glibc,
# so we only need to add what's missing at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgomp1 \
        libstdc++6 \
        libexpat1 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system ocs \
    && useradd --system --gid ocs --create-home ocs

WORKDIR /app

# Copy the fully-resolved virtual environment from the builder.
COPY --from=builder /app/.venv /app/.venv

# Copy instance files needed at runtime.
COPY --from=builder /app/climate-service.yaml ./

# Create the data folder and give the non-root user ownership of /app.
RUN mkdir -p /app/data && chown -R ocs:ocs /app

# Put the venv on PATH so uvicorn and all installed entry points
# are found without needing `uv run`.
ENV PATH="/app/.venv/bin:$PATH"

# open-climate-service reads its config from this env var.
# Override at runtime with -e or docker-compose environment:.
ENV CLIMATE_SERVICE_CONFIG=/app/climate-service.yaml

# data/ is volume-mounted at runtime — downloaded Zarr stores
# should not live inside the container image.
# ERA5-Land credentials can be mounted read-only at
# /home/ocs/.ecmwfdatastoresrc.
VOLUME ["/app/data"]

USER ocs

EXPOSE 8000

CMD ["uvicorn", "open_climate_service.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000"]