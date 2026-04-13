---
title: Apply namespace + cache pattern to `Git`, `Certs`, and `Ps` domains
description: Reorganise Git, Certs, and Ps metrics domains into namespaces, each with a pure parser sub-module, a Cache GenServer owning all DokkuCli calls, and a thin front-end for Collector.
branch: feature/namespace-cache-git-certs-ps
---

## Overview

Following the pattern established by `DokkuRadar.Services`, reorganise the `Git`,
`Certs`, and `Ps` metrics domains into namespaces. Each domain gets a pure parser
sub-module, a `Cache` GenServer that owns all DokkuCli calls, and a thin front-end
module for `Collector`. After this work, no module outside a `*.Cache` GenServer
should call `DokkuRadar.DokkuCli` directly.

## Tasks

**Git domain**
- [x] 1. Create `lib/dokku_radar/git/report.ex` as `DokkuRadar.Git.Report` — pure parser with a `parse/1` function that handles multi-app `git:report` output (tracks `=====>` section headers, extracts `Git last updated at:` field) and returns `%{app_name => unix_timestamp}`.
- [x] 2. Create `lib/dokku_radar/git/cache.ex` as `DokkuRadar.Git.Cache` — GenServer; calls `git:report` once (no app argument) via DokkuCli, delegates parsing to `Git.Report.parse/1`, caches the resulting map, exposes `last_deploy_timestamps/0` returning `{:ok, %{app_name => unix_timestamp}}`.
- [x] 3. Create `lib/dokku_radar/git.ex` as `DokkuRadar.Git` — thin front-end with `@callback last_deploy_timestamps()`, delegates to `Git.Cache`.
- [x] 4. Delete `lib/dokku_radar/git_report.ex`.

**Certs domain**
- [x] 5. Create `lib/dokku_radar/certs/report.ex` as `DokkuRadar.Certs.Report` — pure parser; move the `parse/1` + `parse_expiry_line/1` logic from current `certs.ex` here.
- [x] 6. Create `lib/dokku_radar/certs/cache.ex` as `DokkuRadar.Certs.Cache` — GenServer; calls `certs:report` via DokkuCli, caches parsed result, exposes `list/0`.
- [x] 7. Rewrite `lib/dokku_radar/certs.ex` as `DokkuRadar.Certs` — thin front-end with `@callback list()`, delegates to `Certs.Cache`.

**Ps domain**
- [x] 8. Create `lib/dokku_radar/ps/report.ex` as `DokkuRadar.Ps.Report` — pure parser; move `parse/1` + `parse_status_line/1` from `ps_report.ex` here.
- [x] 9. Create `lib/dokku_radar/ps/scale.ex` as `DokkuRadar.Ps.Scale` — pure parser; move `parse/1` from `ps_scale.ex` here.
- [x] 10. Create `lib/dokku_radar/ps/cache.ex` as `DokkuRadar.Ps.Cache` — GenServer; calls `ps:report` once (no app argument) to get all entries, extracts app names, then calls `ps:scale` per-app; caches both results; exposes `list/0` and `scale/1`.
- [x] 11. Create `lib/dokku_radar/ps.ex` as `DokkuRadar.Ps` — thin front-end with `@callback list()` and `@callback scale/1`, delegates to `Ps.Cache`.
- [x] 12. Delete `lib/dokku_radar/ps_report.ex` and `lib/dokku_radar/ps_scale.ex`.

**Update call sites**
- [x] 13. Update `DokkuRadar.Collector`: replace `@ps_report_client`/`@ps_scale_client`/`@git_report_client` module attributes with `@ps_client`/`@git_client` (keeping `@certs_client` as-is, backed by `DokkuRadar.Certs`); replace `fetch_git_reports/2` (per-app loop calling `report/1`) with a single call to `@git_client.last_deploy_timestamps()`; replace per-app `fetch_all_scales/2` with per-app calls to `@ps_client.scale/1`; replace `fetch_cert_expiries/1` with `@certs_client.list()`; replace `@ps_report_client.list()` with `@ps_client.list()`.
- [x] 14. Update `DokkuRadar.Application`: add `DokkuRadar.Git.Cache`, `DokkuRadar.Certs.Cache`, `DokkuRadar.Ps.Cache` to the supervision tree.
- [ ] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/git_report.ex` → deleted
- `lib/dokku_radar/git/report.ex` (new)
- `lib/dokku_radar/git/cache.ex` (new)
- `lib/dokku_radar/git.ex` (new)
- `lib/dokku_radar/certs.ex` (rewritten as front-end)
- `lib/dokku_radar/certs/report.ex` (new)
- `lib/dokku_radar/certs/cache.ex` (new)
- `lib/dokku_radar/ps_report.ex` → deleted
- `lib/dokku_radar/ps_scale.ex` → deleted
- `lib/dokku_radar/ps/report.ex` (new)
- `lib/dokku_radar/ps/scale.ex` (new)
- `lib/dokku_radar/ps/cache.ex` (new)
- `lib/dokku_radar/ps.ex` (new)
- `lib/dokku_radar/collector.ex`
- `lib/dokku_radar/application.ex`

## Acceptance Criteria

- Each domain (Git, Certs, Ps) follows the namespace/cache pattern from `DokkuRadar.Services`.
- `*.Report` and `*.Scale` modules are pure parsers — no `DokkuRadar.DokkuCli` calls.
- Only `*.Cache` GenServers call `DokkuRadar.DokkuCli`.
- `DokkuRadar.Collector` references only `DokkuRadar.Git`, `DokkuRadar.Certs`, and `DokkuRadar.Ps` — not the old `GitReport`, `PsReport`, `PsScale` module names.
- `DokkuRadar.Application` starts all three new Cache GenServers.
- `mix test` passes with no references to old module names in `lib/` or `test/`.
