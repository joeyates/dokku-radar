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

## Tasks

- [ ] Initialise the Mix project (`dokku_radar`), OTP application skeleton, and
      `mix.exs` with dependencies: `plug`, `bandit`, `req` >= 0.5.17 (for
      Docker socket HTTP), `jason`
- [ ] Implement `DokkuRadar.DockerClient` — a `Req`-based HTTP client over the
      Unix socket at `/var/run/docker.sock`; expose `list_containers/0` and
      `container_stats/1`
- [ ] Implement `DokkuRadar.FilesystemReader` — reads scale config from
      `/var/lib/dokku/data/ps/` and SSL cert files from
      `/var/lib/dokku/certs/` and
      `/var/lib/dokku/data/letsencrypt/certs/` (handles both managed and
      user-supplied cert cases)
- [ ] Implement `DokkuRadar.Collector` — coordinates Docker and filesystem
      reads; maps raw data onto the metric structs defined in the plan
- [ ] Implement `DokkuRadar.PrometheusFormatter` — serialises metric structs to
      Prometheus text exposition format (no external library; the format is
      simple enough to generate directly)
- [ ] Implement `DokkuRadar.Router` (Plug) with `GET /metrics` (calls Collector,
      returns `text/plain; charset=utf-8`) and `GET /health` (returns `200 ok`)
- [ ] Wire up `DokkuRadar.Application` with a Bandit endpoint on port 9110 and a
      `Req` base request configured for the Unix socket
- [ ] Write `Dockerfile` — multi-stage: `elixir:1.18-alpine` builder producing a
      Mix release; `alpine` runtime stage; `EXPOSE 9110`
- [ ] Write `config/prometheus.yml` — scrape job `dokku_radar` targeting
      `dokku-radar.web.1:9110`; include a second optional job stub for
      `node_exporter`
- [ ] Write `grafana/dashboard.json` — importable dashboard with panels:
      configured vs running process counts, container restart rate, SSL
      days-remaining timeline, last deploy timestamps
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
- `docs/setup.md` covers the entire setup path in order:
  1. Create the `monitoring` Dokku network
  2. Deploy and configure `dokku-radar` (volume mounts, network attachment, no
     proxy)
  3. Deploy and configure `prometheus` (storage mount, network attachment,
     `prometheus.yml`)
  4. Deploy and configure `grafana` (storage mount, import dashboard)
  5. Verify the stack is working (sample `curl` commands against each app)
  6. Optional next steps: expose `grafana` and `prometheus` via HTTPS, add
     `node_exporter`
  7. Document the HTTP availability gap: Dokku Radar confirms containers are
     running but cannot verify that apps are responding correctly to HTTP
     requests. Recommend deploying
     [`blackbox_exporter`](https://github.com/prometheus/blackbox_exporter) as
     a fourth monitoring Dokku app to probe app domains; note that this is
     outside the scope of this project.
