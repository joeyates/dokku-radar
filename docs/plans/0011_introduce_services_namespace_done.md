---
title: Introduce `DokkuRadar.Services` namespace
description: Move ServiceCache and its companion modules into a DokkuRadar.Services sub-namespace, and introduce a thin DokkuRadar.Services front-end module for Collector.
branch: feature/introduce-services-namespace
---

## Overview

Move the four sibling modules of the `ServiceCache` GenServer into a
`DokkuRadar.Services` sub-namespace, rename the GenServer itself to
`DokkuRadar.Services.Cache`, and introduce a thin `DokkuRadar.Services`
front-end module that hides the cache from `Collector`. The `defstruct`
currently on `DokkuRadar.ServiceCache` migrates to `DokkuRadar.Services.Cache`.
All call sites — `Collector`, `Application`, `config/test.exs`,
`test/support/mocks.ex`, and test files — are updated.

## Tasks

- [x] Rename `DokkuRadar.ServicePlugins` → `DokkuRadar.Services.ServicePlugins`; move to `lib/dokku_radar/services/service_plugins.ex`.
- [x] Rename `DokkuRadar.ServicePlugin` → `DokkuRadar.Services.ServicePlugin`; move to `lib/dokku_radar/services/service_plugin.ex`.
- [x] Rename `DokkuRadar.Service` → `DokkuRadar.Services.Service`; move to `lib/dokku_radar/services/service.ex`.
- [x] Rename `DokkuRadar.ServiceCache` → `DokkuRadar.Services.Cache`; move to `lib/dokku_radar/services/cache.ex`; move the `defstruct` with it.
- [x] Create `lib/dokku_radar/services.ex` as `DokkuRadar.Services` with a `@callback service_links()` and a delegating implementation that calls `DokkuRadar.Services.Cache.service_links/0`.
- [x] Update `DokkuRadar.Collector`: change `@service_cache` to reference `DokkuRadar.Services`; update struct references from `%DokkuRadar.ServiceCache{}` to `%DokkuRadar.Services.Cache{}`.
- [x] Update `DokkuRadar.Application`: replace `DokkuRadar.ServiceCache` child with `DokkuRadar.Services.Cache`.
- [x] Update `config/test.exs`: rename all four old keys to their new module names; add `"DokkuRadar.Services": DokkuRadar.Services.Mock`.
- [x] Update `test/support/mocks.ex`: rename all four `Mox.defmock` entries; add `DokkuRadar.Services.Mock`.
- [x] Update test files: rename module aliases and struct references in `service_test.exs`, `service_plugin_test.exs`, `service_plugins_test.exs`, and `collector_test.exs`.
- [x] Delete old source files `service_cache.ex`, `service.ex`, `service_plugin.ex`, `service_plugins.ex`.
- [ ] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/service_cache.ex` → `lib/dokku_radar/services/cache.ex`
- `lib/dokku_radar/service.ex` → `lib/dokku_radar/services/service.ex`
- `lib/dokku_radar/service_plugin.ex` → `lib/dokku_radar/services/service_plugin.ex`
- `lib/dokku_radar/service_plugins.ex` → `lib/dokku_radar/services/service_plugins.ex`
- `lib/dokku_radar/services.ex` (new)
- `lib/dokku_radar/collector.ex`
- `lib/dokku_radar/application.ex`
- `config/test.exs`
- `test/support/mocks.ex`
- `test/dokku_radar/service_test.exs`
- `test/dokku_radar/service_plugin_test.exs`
- `test/dokku_radar/service_plugins_test.exs`
- `test/dokku_radar/collector_test.exs`

## Acceptance Criteria

- All four companion modules live under `lib/dokku_radar/services/` with `DokkuRadar.Services.*` module names.
- `DokkuRadar.Services.Cache` is the only module that calls `ServicePlugins`, `ServicePlugin`, and `Service`.
- `DokkuRadar.Services` is the only entry point for `Collector`; it has a `@callback service_links()` and a mock.
- `mix test` passes with no references to the old module names anywhere in `lib/` or `test/`.
