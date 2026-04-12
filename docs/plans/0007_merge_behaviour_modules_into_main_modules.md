---
title: Merge behaviour modules into main modules
description: Move @callback declarations from separate *.Behaviour submodules into their parent modules, delete the behaviour.ex files, and update mocks to reference the main modules.
branch: chore/merge-behaviour-modules
---

## Overview

Move `@callback` declarations from separate `*.Behaviour` submodules into their parent modules (as already done in `DokkuRadar.ServiceCache`). Delete the now-redundant `behaviour.ex` files. `DokkuCli`'s behaviour file is deleted but no `@callback`s are added yet. Update the mocks file to reference the main modules.

## Tasks

- [x] Move `@callback` declarations from `DokkuRadar.DockerClient.Behaviour` into `DokkuRadar.DockerClient`; remove `@behaviour` and `@impl true`; delete `lib/dokku_radar/docker_client/behaviour.ex`
- [x] Move `@callback` declarations from `DokkuRadar.FilesystemReader.Behaviour` into `DokkuRadar.FilesystemReader`; remove `@behaviour` and `@impl true`; delete `lib/dokku_radar/filesystem_reader/behaviour.ex`
- [x] Move `@callback` declarations from `DokkuRadar.Service.Behaviour` into `DokkuRadar.Service`; remove `@behaviour` and `@impl true`; delete `lib/dokku_radar/service/behaviour.ex`
- [x] Move `@callback` declarations from `DokkuRadar.ServicePlugin.Behaviour` into `DokkuRadar.ServicePlugin`; delete `lib/dokku_radar/service_plugin/behaviour.ex`
- [ ] Move `@callback` declarations from `DokkuRadar.ServicePlugins.Behaviour` into `DokkuRadar.ServicePlugins`; delete `lib/dokku_radar/service_plugins/behaviour.ex`
- [ ] Move `@callback` declarations from `DokkuRadar.Collector.Behaviour` into `DokkuRadar.Collector`; remove `@behaviour` and `@impl true`; delete `lib/dokku_radar/collector/behaviour.ex`
- [ ] Delete `lib/dokku_radar/dokku_cli/behaviour.ex` (no `@callback`s added to `DokkuCli` yet)
- [ ] Update `test/support/mocks.ex`: change each `for: DokkuRadar.X.Behaviour` to `for: DokkuRadar.X`; remove the `DokkuRadar.DokkuCli.Mock` entry
- [ ] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/docker_client.ex` / `lib/dokku_radar/docker_client/behaviour.ex`
- `lib/dokku_radar/filesystem_reader.ex` / `lib/dokku_radar/filesystem_reader/behaviour.ex`
- `lib/dokku_radar/service.ex` / `lib/dokku_radar/service/behaviour.ex`
- `lib/dokku_radar/service_plugin.ex` / `lib/dokku_radar/service_plugin/behaviour.ex`
- `lib/dokku_radar/service_plugins.ex` / `lib/dokku_radar/service_plugins/behaviour.ex`
- `lib/dokku_radar/collector.ex` / `lib/dokku_radar/collector/behaviour.ex`
- `lib/dokku_radar/dokku_cli/behaviour.ex`
- `test/support/mocks.ex`

## Acceptance Criteria

- All `*.Behaviour` submodules are deleted
- Each main module contains its own `@callback` declarations (except `DokkuCli`)
- `test/support/mocks.ex` references main modules directly; `DokkuCli.Mock` entry is removed
- The codebase compiles without errors
