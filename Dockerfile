# ============================================================
# Stage 1: builder
# Install uv, resolve and install all dependencies into .venv
# ============================================================
FROM python:3.14-slim-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*


# Copy uv binary from the official distroless image.
# Pin to a specific version for reproducible builds.
COPY --from=ghcr.io/astral-sh/uv:0.7.12 /uv /uvx /bin/

# Tell uv never to try to download Python — use the one in this image.
ENV UV_PYTHON_DOWNLOADS=never

# UV_LINK_MODE=copy is required in Docker because the uv cache mount
# and the target .venv are on different filesystems. Without this,
# uv tries to hardlink/reflink and silently falls back or errors.
ENV UV_LINK_MODE=copy

# Compile .pyc files at build time so the container starts faster.
ENV UV_COMPILE_BYTECODE=1

WORKDIR /app

# ── Dependency installation layer ──────────────────────────────
# Mount pyproject.toml and uv.lock without COPY so this layer is
# only invalidated when those two files change, not when your
# config yaml or plugins change.
# --no-install-project: install transitive deps but not the project
# itself (there is no project to install — package = false).
# --locked: assert uv.lock is consistent with pyproject.toml.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# ── Copy the rest of the instance files ────────────────────────
# This layer is invalidated frequently (config changes, new plugins),
# but the dependency layer above is already cached.
COPY climate-service.yaml ./

# Final sync. Since package = false in pyproject.toml there is
# nothing more to "install", but this validates the environment
# is complete and consistent with the lockfile.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked


# ============================================================
# Stage 2: runtime
# Minimal image — only Python, the venv, and instance files.
# No uv, no git, no build tools.
# ============================================================
FROM python:3.14-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends libexpat1 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the fully-resolved virtual environment from the builder.
COPY --from=builder /app/.venv /app/.venv

# Copy instance files needed at runtime.
COPY --from=builder /app/climate-service.yaml ./

# Put the venv on PATH so uvicorn and all installed entry points
# are found without needing `uv run`.
ENV PATH="/app/.venv/bin:$PATH"

# open-climate-service reads its config from this env var.
# Override at runtime with -e or docker-compose environment:.
ENV CLIMATE_SERVICE_CONFIG=/app/climate-service.yaml

# data/ is volume-mounted at runtime — downloaded Zarr stores
# should not live inside the container image.
VOLUME ["/app/data"]

EXPOSE 8000

CMD ["uvicorn", "open_climate_service.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000"]