---
title: Cache Docker calls following the pattern used by other modules
description: Restructure the Docker integration into a DokkuRadar.Docker namespace with a Cache GenServer that pre-fetches stats and inspects for all containers every 5 minutes.
branch: feature/cache-docker-calls
---

## Overview

Restructure the Docker integration into a `DokkuRadar.Docker` namespace. A `Docker.Client` module holds the raw HTTP calls; a `Docker.Cache` GenServer pre-fetches stats and inspects for all containers every 5 minutes; a `Docker` front-end delegates to the cache. `Collector` is updated to use `Docker` instead of `DockerClient`.

Use TDD throughout: write tests before or alongside each implementation change, and ensure `mix test` passes at the end of every task.

## Tasks

- [x] 1. Create `lib/dokku_radar/docker/client.ex` (`DokkuRadar.Docker.Client`) by moving the raw HTTP functions from `DockerClient` into it; rename `test/dokku_radar/docker_client_test.exs` → `test/dokku_radar/docker/client_test.exs` and update all `DockerClient` references to `Docker.Client`.
- [x] 2. Create `lib/dokku_radar/docker/cache.ex` (`DokkuRadar.Docker.Cache`) using `DokkuCli.Cache` with a 5-minute interval. `load/0` calls `Docker.Client.list_containers/0`, then fetches stats and inspect for every container, returning `{:update, %{stats: %{id => map()}, inspects: %{id => map()}}}`. Expose `container_stats/1` and `container_inspect/1` `handle_call` clauses; add tests for the cache.
- [x] 3. Replace `lib/dokku_radar/docker_client.ex` with `lib/dokku_radar/docker.ex` (`DokkuRadar.Docker`) as a thin front-end delegating to `Docker.Cache`; update `test/support/mocks.ex` (replace `DockerClient.Mock` with `Docker.Mock`) and `config/test.exs`.
- [x] 4. Update `lib/dokku_radar/collector.ex`: rename `@docker_client` → `@docker` backed by `DokkuRadar.Docker`; update `test/dokku_radar/collector_test.exs` to use `DokkuRadar.Docker.Mock`.
- [x] 5. Add `DokkuRadar.Docker.Cache` to the supervised children in `lib/dokku_radar/application.ex`.
- [x] 6. Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [x] 7. Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/docker_client.ex` → `lib/dokku_radar/docker.ex`
- `lib/dokku_radar/docker/client.ex` (new)
- `lib/dokku_radar/docker/cache.ex` (new)
- `lib/dokku_radar/collector.ex`
- `lib/dokku_radar/application.ex`
- `test/support/mocks.ex`
- `config/test.exs`
- `test/dokku_radar/docker_client_test.exs` → `test/dokku_radar/docker/client_test.exs`
- `test/dokku_radar/collector_test.exs`

## Acceptance Criteria

- `Docker.Client` encapsulates the Docker socket HTTP calls.
- `Docker.Cache` pre-fetches stats and inspects for all containers on startup and every 5 minutes; `container_stats/1` and `container_inspect/1` are served from cache.
- `Docker` front-end mirrors the `@callback` API of the old `DockerClient`.
- `Collector` makes no direct Docker API calls at scrape time.
- All tests pass.
