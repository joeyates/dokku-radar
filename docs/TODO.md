# Build Dokku Radar — a Prometheus exporter for Dokku installations

Status: [x]

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

# Fix `dokku_app_last_deploy_timestamp` Grafana panel

Status: [x]

## Description

The "Last Deploy Timestamps" table panel shows NaN for all rows except one, because the Grafana panel is misconfigured: a `reduce` transformation collapses per-app rows into summary columns, and the `dateTimeFromNow` unit is applied to all fields (including the string `app` column).

## Technical Specifics

- In `grafana/dashboard.json`, panel "Last Deploy Timestamps":
  - Replace the `reduce` transformation with `filterFieldsByName` (keeping `app` and `Value`) followed by `organize` (renaming `Value` → `Last Deploy`)
  - Move `unit: dateTimeFromNow` from `fieldConfig.defaults` to a field-level override on the `Last Deploy` column only
  - Update `options.sortBy` to reference `"Last Deploy"` instead of `"Value"`
- The backend metric and Prometheus query are correct — no Elixir changes needed
