---
title: Fix `DokkuRadar.Collector` — align with actual types
description: Fix type mismatches in DokkuRadar.Collector so ps_reports, scale, and status entries are handled with correct struct access, and use DokkuRemote/project structs in place of plain maps.
branch: bugfix/fix-collector-types
---

## Overview

`DokkuRadar.Collector` was written against stale assumptions about the shape of data returned by its dependencies. Now that `Ps.Cache`, `Git.Cache`, `Certs.Cache`, and `Services.Cache` all delegate to `DokkuRemote`, the collector must use the correct structs. There are also a few places where plain maps should be replaced with defined structs for better type enforcement.

Key problems:

- `fetch_all_stats` / `fetch_all_inspects` access `report.cid`, but `DokkuRemote.Commands.Ps.Report.t()` has no `cid` field — container IDs live on `status_entries[].cid` (`StatusEntry.t()`).
- `container_state_metric` and `container_restarts_metric` iterate `ps_reports` as flat entries with `entry.app / entry.cid / entry.process_type / entry.process_index / entry.state`; `ps_reports` is actually `%{app_name => Report.t()}` and state must be derived from `StatusEntry.running`.
- `cpu_usage_metric` and `memory_usage_metric` have the same flat-iteration bug.
- `processes_configured_metric` iterates a `scale` value as a plain `{process_type, count}` map, but `Ps.Cache.scale/1` returns a `DokkuRemote.Commands.Ps.Scale.t()` struct — the proctypes map is at `scale.proctypes`.
- `processes_running_metric` emits label `"process_name"` but downstream (Grafana queries, paired metric) expects `"process_type"`.
- Callback specs for `DokkuRadar.Ps` use `[map()]` / `%{String.t() => non_neg_integer()}` instead of the real struct types.
- The `defstruct` for service data is defined inside `DokkuRadar.Services.Cache` rather than in a dedicated module.
- Tests use plain map helpers (`ps_entry/5`) and bare `%{"web" => 1}` scale maps instead of `Report.t()` / `StatusEntry.t()` / `Scale.t()` structs.

## Tasks

- [ ] 1. Move the service struct `defstruct [:type, :name, links: [], status: "running"]` from `DokkuRadar.Services.Cache` into `DokkuRadar.Services.Service`, and update `Services.Cache` to alias and use `DokkuRadar.Services.Service` by name.
- [ ] 2. Update `DokkuRadar.Ps` callback specs:
  - `list/0` → `{:ok, %{String.t() => DokkuRemote.Commands.Ps.Report.t()}} | {:error, term()}`
  - `scale/1` → `{:ok, DokkuRemote.Commands.Ps.Scale.t()} | {:error, term()}`
  Also update the matching specs in `DokkuRadar.Ps.Cache`.
- [ ] 3. Fix `fetch_all_stats/1` and `fetch_all_inspects/1` in `Collector`: iterate `{_app_name, report}` pairs and then each `status_entry` in `report.status_entries` to build the `cid`-keyed map.
- [ ] 4. Fix `container_state_metric/1`: iterate `{app_name, report}` pairs, then `report.status_entries`; use `entry.process_name` for the `"process_type"` label, `entry.index` for `"process_index"`, `entry.cid` for `"container_id"`, and derive `state` from `if entry.running, do: "running", else: "exited"`.
- [ ] 5. Fix `container_restarts_metric/2`: same structural change — nested iteration over ps_reports and status_entries to look up `inspects_by_id[entry.cid]`.
- [ ] 6. Fix `cpu_usage_metric/2` and `memory_usage_metric/2`: nested iteration over ps_reports and status_entries to look up `stats_by_id[entry.cid]`; use `report.app_name` for the `"app"` label.
- [ ] 7. Fix `processes_configured_metric/1`: change `Enum.map(scale, ...)` to `Enum.map(scale.proctypes, ...)`.
- [ ] 8. Fix `processes_running_metric/1`: change the label key from `"process_name"` to `"process_type"`.
- [ ] 9. Update `collector_test.exs`: replace the `ps_entry/5` plain-map helper with helpers that build `DokkuRemote.Commands.Ps.Report.t()` (with `status_entries: [StatusEntry.t()]`), and replace bare `%{"web" => 1}` scale results with `%DokkuRemote.Commands.Ps.Scale{app_name: ..., proctypes: ...}`.
- [ ] 10. Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] 11. Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/collector.ex`
- `lib/dokku_radar/ps.ex`
- `lib/dokku_radar/ps/cache.ex`
- `lib/dokku_radar/services/service.ex`
- `lib/dokku_radar/services/cache.ex`
- `test/dokku_radar/collector_test.exs`
- `deps/dokku_remote/lib/dokku_remote/commands/ps/report.ex` (reference only)
- `deps/dokku_remote/lib/dokku_remote/commands/ps/report/status_entry.ex` (reference only)
- `deps/dokku_remote/lib/dokku_remote/commands/ps/scale.ex` (reference only)

## Acceptance Criteria

- `mix test` passes with no failures.
- No access to a `.cid` field on `Report.t()` anywhere in `Collector` (CIDs come exclusively from `StatusEntry.t()`).
- `processes_configured_metric` accesses `scale.proctypes`, not `scale` directly.
- Both `processes_running` and `container_state` emit `"process_type"` (not `"process_name"`) as a label.
- `DokkuRadar.Services.Service` is a standalone module with the service struct.
- Test helpers produce `DokkuRemote.Commands.Ps.Report.t()` and `DokkuRemote.Commands.Ps.Scale.t()` structs rather than plain maps.
- Collector output is compatible with all Prometheus queries in `grafana/dashboard.json`.
