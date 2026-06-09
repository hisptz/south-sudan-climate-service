# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make install    # install dependencies via uv
make run        # start API at http://localhost:8000 (loads .env automatically)
```

`make run` sources `.env` before launching, so `CLIMATE_SERVICE_CONFIG` must point to `climate-service.yaml`.

## Architecture

This is a thin configuration layer on top of the upstream [open-climate-service](https://github.com/dhis2/open-climate-service) framework. There is **no application source code in this repo** — the entire API is provided by `open_climate_service.main:app` (a FastAPI/uvicorn app installed as a git dependency).

This repo's job is to configure and extend that framework for South Sudan:

- **`climate-service.yaml`** — primary config: service identity, geographic extent (bbox for South Sudan in WGS84), `data_dir`, and `plugins_dir`.
- **`data/`** — runtime data storage: `artifacts/`, `downloads/`, `jobs/`, `openeo_jobs/`. Mounted as a volume in Docker; not committed.
- **`plugins/`** — drop Python plugin files here to extend the upstream framework at runtime. Currently empty.

## Dependency management

Uses [uv](https://docs.astral.sh/uv/). `open-climate-service` is pinned to the `main` branch of `github.com/dhis2/open-climate-service`. To update it: `uv lock --upgrade-package open-climate-service`.

## Docker

The Dockerfile is a two-stage build: `builder` runs `uv sync --frozen --no-dev`, `runtime` copies the venv and `climate-service.yaml`. The `data/` dir is a `VOLUME` — always mount it at runtime. The image is published to `ghcr.io/hisptz/south-sudan-climate-service` via GitHub Actions on pushes to `main` and on tags.
