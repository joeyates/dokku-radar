---
title: Accept Container ID Abbreviations
description: Make Docker.Cache lookups work with Dokku's 12-character abbreviated container IDs by replacing exact Map.get lookups with prefix-matching Enum.find.
branch: feature/accept-container-id-abbreviations
---

## Overview

Dokku abbreviates Docker container IDs (`cid`s) from 64 to 12 characters. The `handle_call/3` clauses in `DokkuRadar.Docker.Cache` currently look up stats and inspect data via `Map.get/3`, which requires an exact key match and therefore returns `{:error, :not_found}` when an abbreviated ID is supplied. This plan replaces those lookups with `Enum.find/2` prefix-matching so that both full and abbreviated IDs resolve correctly.

## Tasks

- [x] 1. In `lib/dokku_radar/docker/cache.ex`, replace both `Map.get(stats/inspects, id, {:error, :not_found})` lookups with an `Enum.find` that matches any stored key whose full ID starts with the supplied `id`; return `{:error, :not_found}` when no match is found.
- [x] 2. Update `test/dokku_radar/docker/cache_test.exs`: expand `@container_id` to a full 64-character ID (as stored by Docker), add a `@container_id_short` (first 12 characters), and add tests verifying that both the full and abbreviated IDs resolve correctly for `container_stats` and `container_inspect`.
- [ ] 3. Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] 4. Mark the plan as done.

## Principal Files

- `lib/dokku_radar/docker/cache.ex`
- `test/dokku_radar/docker/cache_test.exs`

## Acceptance Criteria

- `container_stats/2` and `container_inspect/2` return correct data when called with a 12-character abbreviated ID that is a prefix of a stored full 64-character ID.
- Exact full-ID lookups continue to work.
- Unknown IDs still return `{:error, :not_found}`.
- `mix test` passes.
