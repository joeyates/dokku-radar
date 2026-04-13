---
title: Use Dokku CLI Instead of Filesystem/Docker
description: Refactor metric collection to use Dokku CLI commands (via SSH) instead of reading the filesystem or Docker API directly, where equivalent data is available.
branch: feature/use-dokku-cli-instead-of-filesystem-docker
---

## Overview

Replace filesystem reads and Docker container listings with Dokku CLI calls for
all metrics where equivalent data exists. Metrics that have no CLI equivalent
(container restarts, CPU usage, memory usage) continue to use the Docker API.

Four Dokku commands provide the needed data:

| Metric | Command | Invocation |
|---|---|---|
| SSL cert expiry | `certs:report` | once (all apps) |
| Process running counts + states | `ps:report` | once (all apps) |
| Configured process scale | `ps:scale <app>` | once per app |
| Last deploy timestamp | `git:report <app>` | once per app |

### Relevant output formats

**`dokku certs:report`** (all apps, no argument):
```
=====> blog-cms ssl information
       Ssl expires at:                Jul  1 08:39:08 2026 GMT
```

**`dokku ps:report`** (all apps, no argument):
```
=====> blog-cms ps information
       Status web 1:                  running (CID: 37d851b84ba)
```

**`dokku ps:scale <app>`**:
```
-----> Scaling for blog-cms
proctype: qty
--------: ---
release: 0
web:  1
```

**`dokku git:report <app>`**:
```
=====> blog-cms git information
       Git last updated at:           1775125215
```

## Tasks

- [x] Create `DokkuRadar.Certs` module: calls `certs:report` once, parses `Ssl expires at:` (format `Jul  1 08:39:08 2026 GMT`) per app into a `%{app => DateTime.t()}` map; add `@callback list() :: {:ok, %{String.t() => DateTime.t()}} | {:error, term()}`; add `DokkuRadar.Certs.Mock` to `test/support/mocks.ex` and `config/test.exs`.
- [x] Update `DokkuRadar.Collector`: add `@certs_client` compile-env attribute; replace `fetch_all_cert_expiries/3` (per-app loop) with a single `certs_client.list/0` call; update `ssl_cert_expiry_metric/1` accordingly.
- [x] Remove `cert_expiry/1` callback and implementation from `DokkuRadar.FilesystemReader`; delete `DokkuRadar.Letsencrypt` (superseded by `Certs`).
- [x] Create `DokkuRadar.PsReport` module: calls `ps:report` once, parses `=====> <app>` headers and `Status <type> <N>: <state> (CID: <cid>)` lines into a structure usable for both `processes_running` and `container_state` metrics; add `@callback list() :: {:ok, [map()]} | {:error, term()}`; add `DokkuRadar.PsReport.Mock` to `test/support/mocks.ex` and `config/test.exs`.
- [x] Update `DokkuRadar.Collector`: add `@ps_report` compile-env attribute; replace `processes_running_metric` and `container_state_metric` to consume `PsReport.list/0` output (container label drops to process index instead of container name).
- [x] Create `DokkuRadar.PsScale` module: calls `ps:scale <app>` per app, parses the `proctype: qty` table (skip header lines starting with `----` or `proctype`) into `%{process_type => count}`; add `@callback scale(String.t()) :: {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}`; add `DokkuRadar.PsScale.Mock` to `test/support/mocks.ex` and `config/test.exs`.
- [x] Update `DokkuRadar.Collector`: add `@ps_scale` compile-env attribute; replace `fetch_all_scales/3` (which called `filesystem_reader.app_scale`) with calls to `ps_scale.scale/1` per app; remove `app_scale/2` callback and implementation from `DokkuRadar.FilesystemReader`.
- [x] Create `DokkuRadar.GitReport` module: calls `git:report <app>` per app, parses the `Git last updated at:` Unix integer timestamp; add `@callback report(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}`; add `DokkuRadar.GitReport.Mock` to `test/support/mocks.ex` and `config/test.exs`.
- [ ] Update `DokkuRadar.Collector`: add `@git_report` compile-env attribute; replace `last_deploy_metric` (which used Docker container `"Created"` timestamps) with `GitReport.report/1` calls per app.
- [ ] Clean up `DokkuRadar.Collector`: if `list_containers` output is no longer used for anything beyond feeding `container_inspect` and `container_stats`, derive the app/container list from `PsReport` output instead and remove the `@docker_client` `list_containers` dependency if possible; retain `container_inspect` (restarts) and `container_stats` (CPU/memory).
- [x] Delete `DokkuRadar.FilesystemReader` if no callbacks remain; otherwise remove unused callbacks and update `@callback` declarations accordingly.
- [ ] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] Mark the plan as done.

## Principal Files

- `lib/dokku_radar/collector.ex`
- `lib/dokku_radar/filesystem_reader.ex` (to be shrunk or deleted)
- `lib/dokku_radar/letsencrypt.ex` (to be deleted)
- `lib/dokku_radar/dokku_cli.ex`
- `config/test.exs`
- `test/support/mocks.ex`
- New: `lib/dokku_radar/certs.ex`
- New: `lib/dokku_radar/ps_report.ex`
- New: `lib/dokku_radar/ps_scale.ex`
- New: `lib/dokku_radar/git_report.ex`

## Acceptance Criteria

- No metrics are read from `/var/lib/dokku`
- `dokku certs:report` is called once per scrape (not once per app)
- `processes_configured` derives from `ps:scale` CLI output
- `processes_running` and `container_state` derive from `ps:report` CLI output
- `last_deploy` derives from `git:report` CLI output
- Docker API is still used for `container_restarts_total`, `cpu_usage_seconds_total`, and `memory_usage_bytes`
- All tests pass
