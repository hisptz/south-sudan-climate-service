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
  country_code: SS

data_dir: ./data
plugins_dir: ./plugins/
```

Copy `.env` and set the config path:

```bash
CLIMATE_SERVICE_CONFIG=/path/to/climate-service.yaml
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
  -e CLIMATE_SERVICE_CONFIG=/app/climate-service.yaml \
  south-sudan-climate-service
```

A pre-built image is published to the GitHub Container Registry on every push to `main`:

```bash
docker pull ghcr.io/hisptz/south-sudan-climate-service:latest
```

## Project Structure

```
.
├── climate-service.yaml   # Service configuration (extent, data paths)
├── data/                  # Local data storage (artifacts, downloads, jobs)
├── plugins/               # Custom plugins loaded at runtime
├── Dockerfile
├── Makefile
└── pyproject.toml
```

## CI/CD

GitHub Actions builds and publishes the Docker image to `ghcr.io` on:
- Push to `main` → tagged as `latest`
- Git tags → tagged with the version

## License

See [open-climate-service](https://github.com/dhis2/open-climate-service) for upstream licensing.
