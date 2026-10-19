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

- **`climate-service.yaml`** — primary config: service identity, geographic extent (bbox for South Sudan in WGS84, `country_code` as ISO alpha-3 `SSD`), and `data_dir`. Schema reference: upstream `climate-service.yaml.example`.
- **`data/`** — runtime data storage: `artifacts/`, `downloads/`, `jobs/`, `openeo_jobs/`. Mounted as a volume in Docker; not committed.
- **`plugins/`** — not present yet. To add instance plugins, create it, uncomment `plugins_dir` in the config, and `COPY` it in the Dockerfile.

## Dependency management

Uses [uv](https://docs.astral.sh/uv/). `open-climate-service[server,xarray,dhis2]` tracks the `main` branch of `github.com/dhis2/open-climate-service`. To update it locally: `uv lock --upgrade-package open-climate-service`. The Docker build does this itself on every build. This setup mirrors the generic `hisptz/ocs-docker` image, except that this repo bakes in its config.

## Docker

The Dockerfile is a two-stage build. `builder` busts the cache on new upstream commits (via `ADD` of the GitHub commits API), runs `uv lock --upgrade-package open-climate-service && uv sync --locked`. `runner` copies the venv and `climate-service.yaml` and runs as non-root user `ocs`. The `data/` dir is a `VOLUME` — always mount it at runtime. The image is published to `ghcr.io/hisptz/south-sudan-climate-service` via GitHub Actions on pushes to `main` and on tags.
