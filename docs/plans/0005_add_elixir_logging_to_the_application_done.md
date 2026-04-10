---
title: Add Elixir logging to the application
description: Add structured Logger.info / Logger.debug / Logger.warning calls to every module that interacts with an external system: DokkuCli (SSH), DockerClient (Docker socket), FilesystemReader (filesystem), Collector (orchestration), and ServiceCache (cache lifecycle).
branch: feature/add-logging
---

## Overview

Instrument all modules that perform I/O so operators can observe SSH call attempts, Docker API calls, filesystem reads, and cache refresh cycles in the application log.

## Tasks

- [x] Add `require Logger` to `DokkuRadar.DokkuCli`; add `Logger.debug` before each SSH call (include `host` / `service_type`), `Logger.info` on success (include result count), and `Logger.warning` on error (include `exit_code` and first ~200 chars of output).
- [x] Add `require Logger` to `DokkuRadar.DockerClient`; add `Logger.debug` before each Docker API call (include endpoint / container ID) and `Logger.warning` on non-200 responses or errors.
- [x] Add `require Logger` to `DokkuRadar.FilesystemReader`; add `Logger.debug` before each `File.read/1` (include path) and `Logger.warning` on `{:error, reason}` returns.
- [x] Add `require Logger` to `DokkuRadar.Collector`; add `Logger.info` at the start of a collect cycle (include container count after listing), and `Logger.warning` if `list_containers` fails.
- [x] Add `require Logger` to `DokkuRadar.ServiceCache`; add `Logger.info` at the start and end of `load/1` and `refresh_services/1`, and `Logger.debug` inside `fetch_all_services/2` for each service-type step.
- [x] Use keyword-list structured logging (`Logger.info("...", key: val)`) throughout rather than string interpolation.
- [x] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [x] Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/dokku_cli.ex`
- `lib/dokku_radar/docker_client.ex`
- `lib/dokku_radar/filesystem_reader.ex`
- `lib/dokku_radar/collector.ex`
- `lib/dokku_radar/service_cache.ex`

## Acceptance Criteria

- Running with default log level produces `info`-level lines for each SSH call result, each Docker API call result, and each cache refresh cycle.
- Running with `debug` level additionally shows one line per call attempt (SSH, Docker, filesystem) and one line per service-type fetch step.
- All error / non-200 / `{:error, _}` paths produce `warning`-level lines with relevant context (exit code, HTTP status, POSIX reason, etc.).
- No string interpolation is used for log metadata — values are passed as keyword-list arguments.
