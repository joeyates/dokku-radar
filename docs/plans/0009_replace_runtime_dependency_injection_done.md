---
title: Replace runtime dependency injection
description: Replace ad-hoc runtime dependency injection in Collector and Router with Application.compile_env module attributes, consistent with ServiceCache.
branch: chore/replace-runtime-dependency-injection
---

## Overview

`DokkuRadar.Collector` injects its three dependencies via keyword opts at call-time. `DokkuRadar.Router` injects its collector via `conn.private` and overrides `init/1`/`call/2`. Both patterns are inconsistent with the `Application.compile_env` module-attribute approach used by `DokkuRadar.ServiceCache`. This task makes all four modules consistent.

## Tasks

- [x] In `lib/dokku_radar/collector.ex`, add `@docker_client`, `@filesystem_reader`, and `@service_cache` module attributes backed by `Application.compile_env/3`; replace the three `Keyword.get(opts, ...)` calls with those attributes; simplify `collect/1` to `collect/0`.
- [x] In `lib/dokku_radar/router.ex`, add `@collector Application.compile_env(...)` module attribute; replace `conn.private[:collector] || DokkuRadar.Collector` with `@collector`; delete the `init/1`/`call/2` overrides.
- [x] In `config/test.exs`, add the four missing mock entries: `"DokkuRadar.DockerClient"`, `"DokkuRadar.FilesystemReader"`, `"DokkuRadar.ServiceCache"`, and `"DokkuRadar.Collector"`.
- [x] In `test/dokku_radar/collector_test.exs`, remove `@opts`, update every `Collector.collect(@opts)` call to `Collector.collect()`, and fix the `collect` mock expectation to take no opts.
- [x] In `test/dokku_radar/router_test.exs`, remove the `collector:` argument from `Router.init/1`, simplify `@opts`, and update the `collect` mock expectation arity.
- [x] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [x] Mark the plan as "done".

## Principal Files

- lib/dokku_radar/collector.ex
- lib/dokku_radar/router.ex
- config/test.exs
- test/dokku_radar/collector_test.exs
- test/dokku_radar/router_test.exs
- lib/dokku_radar/service_cache.ex *(reference pattern)*

## Acceptance Criteria

- `DokkuRadar.Collector.collect/0` reads its three dependencies from `Application.compile_env`-backed module attributes.
- `DokkuRadar.Router` reads its collector from an `Application.compile_env`-backed module attribute; the `init/1`/`call/2` overrides are removed.
- `config/test.exs` configures all four mock modules.
- All tests pass (`mix test`) and code is formatted (`mix check-formatted`).
