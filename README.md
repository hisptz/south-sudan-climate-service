# South Sudan Climate Service

A climate data API service for South Sudan, built on top of the [open-climate-service](https://github.com/dhis2/open-climate-service) framework. It exposes climate datasets (temperature, precipitation, indices, etc.) via a REST/OpenEO-compatible API for the South Sudan geographic extent.

## Requirements

- Python 3.13+
- [uv](https://docs.astral.sh/uv/) package manager

## Setup

Install dependencies:

```bash
make install
```

Configure the service by editing `climate-service.yaml`:

```yaml
id: south-sudan-climate-service
name: South Sudan Climate Service

extent:
  name: South Sudan
  bbox: [23.15, 3.20, 36.40, 12.70]  # [xmin, ymin, xmax, ymax] WGS84
  country_code: SSD   # ISO 3166-1 alpha-3

data_dir: ./data
```

Create `.env` from the example (it points `CLIMATE_SERVICE_CONFIG` at `climate-service.yaml`):

```bash
cp .env.example .env
```

## Running

```bash
make run
```

The API will be available at `http://localhost:8000`.

## Docker

Build and run with Docker:

```bash
docker build -t south-sudan-climate-service .

docker run -p 8000:8000 \
  -v $(pwd)/data:/app/data \
  south-sudan-climate-service
```

`climate-service.yaml` is baked into the image. Each build re-resolves `open-climate-service` to the latest commit on upstream `main`, so a rebuild picks up upstream changes even when `uv.lock` pins an older commit. For ERA5-Land, mount credentials with `-v ~/.ecmwfdatastoresrc:/home/ocs/.ecmwfdatastoresrc:ro`.

A pre-built image is published to the GitHub Container Registry on every push to `main`:

```bash
docker pull ghcr.io/hisptz/south-sudan-climate-service:latest
```

## Project Structure

```
.
├── climate-service.yaml   # Service configuration (extent, data paths)
├── .env.example           # Points CLIMATE_SERVICE_CONFIG at climate-service.yaml
├── data/                  # Local data storage (artifacts, downloads, jobs)
├── Dockerfile
├── Makefile
└── pyproject.toml
```

## CI/CD

GitHub Actions builds and publishes the Docker image to `ghcr.io` on:
- Push to `main` → tagged as `latest`
- Git tags → tagged with the version
- Manual run (`workflow_dispatch`) → rebuild against the latest upstream `main`

## License

See [open-climate-service](https://github.com/dhis2/open-climate-service) for upstream licensing.
