---
title: Extract `DokkuRadar.DokkuCli.Cache` shared GenServer macro
description: Extract shared GenServer boilerplate from the four cache modules into a `DokkuRadar.DokkuCli.Cache` macro, unify state to a single `data` field, pass interval via `use`, and fix three bugs in `Services.Cache`.
branch: feature/extract-dokku-cli-cache-macro
---

## Overview

Extract the shared GenServer boilerplate from `Certs.Cache`, `Git.Cache`, `Ps.Cache`, and `Services.Cache` into a `DokkuRadar.DokkuCli.Cache` macro. Each module will `use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(N)` and retain only its domain-specific `handle_call` clauses and `load/0`. Unify all modules to a single `data` field in state. Fix three bugs in `Services.Cache` uncovered during the refactor.

The macro declares `@callback load() :: {:update, term()} | {:error, term()}` and a raising default `def load/0`, marked `defoverridable`. Each cache module implements it as a public `def load/0` with `@impl true`.

## Tasks

- [x] 1. Create `test/dokku_radar/dokku_cli/cache_test.exs` with tests for the shared macro (start, status, refresh cast ignored when task running, refresh cast triggers reload, interval-based reload, error handling) using a minimal `TestCache` module defined in the test file.
- [x] 2. Create `lib/dokku_radar/dokku_cli/cache.ex` — the `__using__/1` macro with `interval:` keyword option, injecting: `@callback load/0`, raising default `def load/0` + `defoverridable load: 0`; `start_link/1`, `status/1`, `refresh/1`; `init/1`, `handle_continue(:load, ...)`, two `handle_cast(:refresh, ...)` clauses, `handle_call(:status, ...)`, all `handle_info/2` clauses (task update, error, DOWN, `:refresh` without running task, `:refresh` with running task — kill, clear, restart immediately); `initiate_load/1`, `demonitor/1`, `maybe_enqueue_refresh/1`; mark `handle_call/3` and `handle_info/2` as `defoverridable`.
- [x] 3. Refactor `Certs.Cache` to `use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)`, replace `expiries` state field with `data`, retain only domain-specific `handle_call` clauses and `@impl true def load/0`; update `test/dokku_radar/certs/cache_test.exs` to match.
- [x] 4. Refactor `Git.Cache` to `use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)`, replace `timestamps` state field with `data`, retain only domain-specific `handle_call` and `@impl true def load/0`; update `test/dokku_radar/git/cache_test.exs` to match.
- [x] 5. Refactor `Ps.Cache` to `use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)`, replace `entries`/`scales` with `data: %{entries:, scales:}`, change `load/0` to return `{:update, %{entries:, scales:}}`, retain domain-specific `handle_call` clauses; update `test/dokku_radar/ps/cache_test.exs` to match.
- [x] 6. Refactor `Services.Cache` to `use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)`, replace separate `plugins`/`services`/`service_links` fields with `data: %{plugins:, services:, service_links:}`, change `load/0` to return `{:update, %{...}}`; fix all three bugs: (1) `maybe_enqueue_refresh` called after `:update`; (2) kill-and-restart clears `update_task` and calls `initiate_load` immediately; (3) `load/0` returns `{:update, %{...}}`; update `test/dokku_radar/service_cache_test.exs` to match.
- [ ] 7. Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] 8. Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/dokku_cli/cache.ex` (new)
- `test/dokku_radar/dokku_cli/cache_test.exs` (new)
- `lib/dokku_radar/certs/cache.ex`
- `test/dokku_radar/certs/cache_test.exs`
- `lib/dokku_radar/git/cache.ex`
- `test/dokku_radar/git/cache_test.exs`
- `lib/dokku_radar/ps/cache.ex`
- `test/dokku_radar/ps/cache_test.exs`
- `lib/dokku_radar/services/cache.ex`
- `test/dokku_radar/service_cache_test.exs`

## Acceptance Criteria

- `DokkuRadar.DokkuCli.Cache` macro exists and all shared boilerplate lives only there.
- `interval:` is passed at `use` time; no `@default_refresh_interval` attribute in any cache module.
- All four cache modules use `use DokkuRadar.DokkuCli.Cache, interval: ...` and contain only domain-specific `handle_call` clauses and `def load/0` with `@impl true`.
- All state maps use a unified `data` field (nil until loaded).
- All three `Services.Cache` bugs are fixed.
- `mix test` passes with no failures.
