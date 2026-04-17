---
title: Create a Diagnostic CLI
description: Add a `diagnose` subcommand to `bin/dokku-radar.exs` that runs remote checks against a live deployment, reporting each check as pass/fail.
branch: feature/diagnostic-cli
---

## Overview

Implement `bin/dokku-radar.exs diagnose` to check the correct functioning and installation of the project. It uses `DokkuRemote.Commands` to run remote checks covering the app process state, network membership, health endpoint, SSH connectivity, and Prometheus target health.

## Tasks

- [x] 1. Create `lib/dokku_radar/cli/diagnose.ex` with a stub `run/1`, add `diagnose` to `@commands` in `DokkuRadar.CLI` and route it; add a skeleton test in `test/dokku_radar/cli/diagnose_test.exs`.
- [x] 2. Implement **App running** check: use `DokkuRemote.Commands.Ps.report/1` filtered for `dokku-radar` — all `web` processes must be in state `running`.
- [ ] 3. Implement **Network membership** checks: verify `dokku-radar`, `prometheus`, and `grafana` are all on the `monitoring` network.
- [ ] 4. Implement **Prometheus running** check: `ps:report` for the `prometheus` Dokku app — all `web` processes in state `running`.
- [ ] 5. Implement **Grafana running** check: `ps:report` for the `grafana` Dokku app — all `web` processes in state `running`.
- [ ] 6. Implement **Health endpoint** check: `DokkuRemote.Commands.Enter` into `dokku-radar web` running `wget -qO- http://127.0.0.1:9110/health`; expect output `ok`.
- [ ] 7. Implement **SSH connectivity** check: `Enter` into `dokku-radar web` and run the SSH `plugin:list` command; success if exit code 0.
- [ ] 8. Implement **Prometheus targets** check: `Enter` into `prometheus web` and call the Prometheus API; expect `dokku_radar` job in active targets with health `up`.
- [ ] 9. Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] 10. Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/cli.ex`
- `lib/dokku_radar/cli/diagnose.ex` (new)
- `test/dokku_radar/cli/diagnose_test.exs` (new)
- `docs/system-checks.md`
- `docs/troubleshooting.md`

## Acceptance Criteria

- `bin/dokku-radar.exs diagnose --private-key <path>` (with `DOKKU_HOST` and `DOKKU_APP` set) runs all checks and prints a pass/fail line for each.
- A complete deployment with all components healthy produces all `✅` lines.
- Any failed check prints a meaningful `❌ <reason>` message.
- All tests pass.
