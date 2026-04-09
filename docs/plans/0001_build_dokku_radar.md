---
title: Build Dokku Radar — a Prometheus exporter for Dokku installations
description: An Elixir Prometheus exporter for Dokku installations, running as a Dokku app alongside off-the-shelf Prometheus and Grafana apps, with a complete self-hoster setup guide.
branch: feature/build-dokku-radar
---

## Overview

Dokku Radar is an Elixir application that exposes Dokku-semantic metrics as a
Prometheus endpoint. It runs as a Dokku app alongside two off-the-shelf Dokku
apps — `prometheus` and `grafana` — on a shared private network. The exporter
reads exclusively from the Docker socket and the Dokku data directory (both
read-only mounts); no CLI or SSH access is required. The project ships the
exporter, a reference `prometheus.yml`, an importable Grafana dashboard, and a
complete self-hoster setup guide.

## Assumed Context

The self-hoster is running [Dokku](https://dokku.com/) on a single VPS. The
monitoring stack consists of exactly three Dokku apps:

- **`prometheus`** — deployed from the official `prom/prometheus` Docker image;
  config supplied via `prometheus.yml` committed to a git repo or
  volume-mounted; data persisted via a Dokku-managed storage mount at
  `/prometheus`.
- **`grafana`** — deployed from the official `grafana/grafana` Docker image;
  data persisted via a Dokku-managed storage mount at `/var/lib/grafana`.
- **`dokku-radar`** — this project; mounted read-only on
  `/var/run/docker.sock` and `/var/lib/dokku`.

All three apps are attached to a private Dokku network called `monitoring`. The
`dokku-radar` app is never exposed publicly (no domains assigned, no proxy
enabled). `prometheus` and `grafana` may optionally be exposed via the Dokku
proxy (HTTPS via Let's Encrypt).

All names (`monitoring`, `dokku-radar`, `prometheus`, `grafana`) are defaults
that the self-hoster may change. Changing an app name requires updating the
scrape target in `prometheus.yml` (pattern: `<app-name>.web.1:<port>`). The
exporter port is read from the `PORT` environment variable (Dokku sets this
automatically); `9110` is the fallback used in local/direct `docker run` usage.

## Tasks

- [x] Initialise the Mix project (`dokku_radar`), OTP application skeleton, and
      `mix.exs` with dependencies: `plug`, `bandit`, `req` >= 0.5.17 (for
      Docker socket HTTP), `jason`
- [x] Implement `DokkuRadar.DockerClient` — a `Req`-based HTTP client over the
      Unix socket at `/var/run/docker.sock`; expose `list_containers/0` and
      `container_stats/1`
- [x] Implement `DokkuRadar.FilesystemReader` — reads scale config from
      `/var/lib/dokku/data/ps/` and SSL cert expiry from
      `/home/dokku/<app>/tls/` (prefers `server.letsencrypt.crt` over
      `server.crt`, matching `dokku letsencrypt:list` logic)
- [x] Implement `DokkuRadar.Collector` — coordinates Docker and filesystem
      reads; maps raw data onto the metric structs defined in the plan
- [x] Implement `DokkuRadar.PrometheusFormatter` — serialises metric structs to
      Prometheus text exposition format (no external library; the format is
      simple enough to generate directly)
- [x] Implement `DokkuRadar.Router` (Plug) with `GET /metrics` (calls Collector,
      returns `text/plain; charset=utf-8`) and `GET /health` (returns `200 ok`)
- [x] Wire up `DokkuRadar.Application` with a Bandit endpoint on the port read
      from `System.get_env("PORT", "9110")` (Dokku injects `PORT` at runtime;
      `9110` is the local/`docker run` fallback) and a `Req` base request
      configured for the Unix socket
- [x] Write `Dockerfile` — multi-stage: `elixir:1.18-alpine` builder producing a
      Mix release; `alpine` runtime stage; `EXPOSE 9110`; include OCI labels
      (`org.opencontainers.image.source`, `org.opencontainers.image.description`)
      so GHCR links the image to the GitHub repository
- [x] Write `config/prometheus.yml` — scrape job `dokku_radar` targeting
      `dokku-radar.web.1:9110`; include a second optional job stub for
      `node_exporter`
- [x] Write `grafana/dashboard.json` — importable dashboard with panels:
      configured vs running process counts, container restart rate, SSL
      days-remaining timeline, last deploy timestamps
- [x] Write `.github/workflows/publish.yml` — GitHub Actions workflow that
      builds and pushes the Docker image to
      `ghcr.io/joeyates/dokku-radar` on every pushed tag matching `v*`;
      uses `docker/build-push-action` with GHCR login via `GITHUB_TOKEN`
- [ ] Write `README.md` — project landing page: one-paragraph description, a
      prerequisites list (Dokku installation with `dokku-network` plugin, git,
      Docker), link to `docs/setup.md`, a metrics reference table, and a
      "Quick start" snippet showing
      `dokku git:from-image dokku-radar ghcr.io/joeyates/dokku-radar:latest`
- [ ] Write `prometheus/Dockerfile` — wraps the official `prom/prometheus`
      image and copies `config/prometheus.yml` into the image at
      `/etc/prometheus/prometheus.yml`; this is the canonical way to deliver
      Prometheus config as a Dokku app (git push, no manual volume editing)
- [ ] Write `docs/setup.md` — complete self-hoster guide (see Acceptance
      Criteria)
- [ ] Ask the user for feedback on the state of the implementation and carry out
      any requested corrections.
- [ ] Mark the plan as "done".

## Principal Files

- `mix.exs`
- `lib/dokku_radar/application.ex`
- `lib/dokku_radar/docker_client.ex`
- `lib/dokku_radar/filesystem_reader.ex`
- `lib/dokku_radar/collector.ex`
- `lib/dokku_radar/prometheus_formatter.ex`
- `lib/dokku_radar/router.ex`
- `Dockerfile`
- `config/prometheus.yml`
- `grafana/dashboard.json`
- `prometheus/Dockerfile`
- `.github/workflows/publish.yml`
- `README.md`
- `docs/setup.md`

## Acceptance Criteria

- `GET /metrics` responds with valid Prometheus text format containing all
  metrics: `dokku_app_processes_configured`, `dokku_app_processes_running`,
  `dokku_container_state`, `dokku_container_restarts_total`,
  `dokku_app_last_deploy_timestamp`, `dokku_ssl_cert_expiry_timestamp`,
  `dokku_app_cpu_usage_seconds_total`, `dokku_app_memory_usage_bytes`
- `GET /health` responds `200 OK`
- `docker build` succeeds and the container starts cleanly on port 9110
- `config/prometheus.yml` is complete and directly usable; no edits required
  beyond replacing the target hostname if the app name differs
- `grafana/dashboard.json` imports via Grafana UI without errors and all panels
  display data
- `README.md` states the prerequisites (working Dokku install, `dokku-network`
  plugin enabled, git, Docker on the host) before any setup steps
- `docs/setup.md` covers the entire setup path in order:
  1. Prerequisites check — confirm Dokku version, network plugin, and that
     the user can `git push` to the host
  1a. Customising names — table listing every name used (`monitoring`,
      `dokku-radar`, `prometheus`, `grafana`) alongside every file and command
      where each name must be substituted if changed; note that changing an app
      name changes its internal network hostname and therefore the scrape target
      in `prometheus.yml`
  2. Create the `monitoring` Dokku network
  3. Deploy `dokku-radar` from GHCR via
     `dokku git:from-image dokku-radar ghcr.io/joeyates/dokku-radar:latest`;
     configure volume mounts for Docker socket and Dokku data dir, network
     attachment, and explicitly `dokku proxy:disable dokku-radar` so it is
     never exposed publicly
  4. Deploy `prometheus` by git-pushing the `prometheus/` subdirectory
     (containing `Dockerfile` + `prometheus.yml`); attach storage mount for
     persistence; attach to `monitoring` network
  5. Deploy `grafana` from the official image; attach storage mount; attach to
     `monitoring` network; show exact UI steps to add Prometheus as a
     datasource (URL: `http://prometheus.web.1:9090`) and import
     `grafana/dashboard.json` (Dashboards → New → Import → Upload JSON file)
  6. Verify the stack: sample `curl` commands to `GET /health` and
     `GET /metrics` on `dokku-radar`, and a check that Prometheus targets page
     shows the exporter as UP
  7. Troubleshooting section covering the three most common failures:
     - Docker socket permission denied (add the app's container user to the
       `docker` group, or adjust socket permissions)
     - Prometheus cannot reach exporter (verify both apps are on the
       `monitoring` network; check `dokku network:info monitoring`)
     - Grafana datasource `Bad Gateway` (confirm Prometheus app is running and
       the datasource URL uses the internal network hostname, not `localhost`)
  8. Optional next steps: expose `grafana` and `prometheus` via HTTPS with
     Let's Encrypt, add `node_exporter` for host-level metrics
  9. Document the HTTP availability gap: Dokku Radar confirms containers are
     running but cannot verify that apps are responding correctly to HTTP
     requests. Recommend deploying
     [`blackbox_exporter`](https://github.com/prometheus/blackbox_exporter) as
     a fourth monitoring Dokku app to probe app domains; note that this is
     outside the scope of this project.
