# Build Dokku Radar — a Prometheus exporter for Dokku installations

Status: [ ]

## Description

Create a self-hosted monitoring tool that exposes Dokku-semantic metrics (app
process state, container health, deploy info, SSL expiry) as a Prometheus
endpoint. The tool runs as a Dokku app alongside standard Prometheus and
Grafana, using only the Docker socket and Dokku data directory as read-only
data sources — no CLI invocations or SSH.

## Technical Specifics

- Implementation language: Elixir
- Exporter app reads from `/var/run/docker.sock` (Docker labels, container
  state, restart counts, CPU/memory stats) and `/var/lib/dokku` (scale config,
  SSL certs)
- Single `GET /metrics` endpoint returning Prometheus text format; `GET
  /health` for health checks
- Ships a `Dockerfile` for containerised deployment
- Deliverables: exporter app, reference `prometheus.yml`, reference Grafana
  dashboard JSON, and setup documentation
- Open questions: scale config file path, Let's Encrypt cert paths, exporter
  port selection, optional `/metrics` auth
