---
title: Expose linked service presence and health metrics
description: Add Prometheus metrics for Dokku service presence and health via SSH-based Dokku CLI calls, with a background GenServer cache to keep scrape latency low.
branch: feature/linked-service-metrics
---

## Overview

Introduce a `DokkuRadar.DokkuCli` module that SSHes to `dokku@<host>` to query installed service plugins and their status/links. A `DokkuRadar.ServiceCache` GenServer polls the CLI on a timer and caches results so the `/metrics` endpoint reads from memory with no SSH latency. Two new Prometheus metrics are exposed: `dokku_service_linked` and `dokku_service_status`.

## Tasks

- [ ] Add `openssh-client` to the Alpine runner image in `Dockerfile`.
- [ ] Add `DokkuRadar.DokkuCli.Behaviour` defining the CLI contract.
- [ ] Implement `DokkuRadar.DokkuCli` — SSH wrapper using `System.cmd/3`, parsing `dokku plugin:list` and `dokku <type>:list` output.
- [ ] Add `DokkuRadar.ServiceCache` GenServer: refreshes plugin list every 5 minutes and per-service status every 30 s (configurable); exposes `get/0`.
- [ ] Register `ServiceCache` in the application supervision tree.
- [ ] Add `dokku_service_linked` and `dokku_service_status` metric builders to `DokkuRadar.Collector`.
- [ ] Add `MockDokkuCli` for tests, following the `DockerClient` mock pattern.
- [ ] Document SSH key setup steps in `docs/setup.md`.
- [ ] Add two Grafana panels to `grafana/dashboard.json`:
  - A **Table** panel "Linked Services" showing one row per `(app, service_type, service_name)` with a `Status` column that value-maps `1` → `Running` (green) / `0` → `Stopped` (red), using a PromQL join: `dokku_service_linked * on(service_type, service_name) group_left() dokku_service_status`.
  - A **Stat** panel "Services Down" showing count of linked services that are currently stopped: `count(dokku_service_linked * on(service_type, service_name) group_left() dokku_service_status == 0)`.
- [ ] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] Mark the plan as "done".

## Principal Files

- `Dockerfile`
- `lib/dokku_radar/dokku_cli/behaviour.ex`
- `lib/dokku_radar/dokku_cli.ex`
- `lib/dokku_radar/service_cache.ex`
- `lib/dokku_radar/application.ex`
- `lib/dokku_radar/collector.ex`
- `test/support/mock_dokku_cli.ex`
- `docs/setup.md`
- `config/config.exs`
- `grafana/dashboard.json`

## Acceptance Criteria

- `Dockerfile` runner stage installs `openssh-client`.
- `dokku plugin:list` output is parsed to detect known service types; unknown types are ignored unless listed in `extra_service_types` config.
- `dokku <type>:list` output yields linked apps and service running status.
- `GET /metrics` returns `dokku_service_linked` and `dokku_service_status` gauges with correct labels.
- Scrape latency is not directly affected by SSH call duration.
- All new modules have unit tests using `MockDokkuCli`.
- `docs/setup.md` describes generating an SSH keypair and mounting the private key.
- Grafana dashboard includes a "Linked Services" table panel and a "Services Down" stat panel.
