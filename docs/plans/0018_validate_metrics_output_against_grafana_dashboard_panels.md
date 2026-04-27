---
title: Validate metrics output against Grafana dashboard panels
description: Add a diagnose phase that fetches live /metrics output and checks every metric referenced by a Grafana panel has data.
branch: feature/validate-metrics-coverage
---

## Overview

Add a `check_metrics_coverage/1` check to `DokkuRadar.CLI.Diagnose` that:

1. Fetches the live `/metrics` output from inside the `dokku-radar` container via an `enter` call.
2. Extracts the required metric names from `grafana/dashboard.json` at runtime by reading all `"expr"` values and extracting `dokku_*` identifiers with a regex.
3. Determines which of those metric names have at least one data sample in the output.
4. Reports pass or fail with any missing metric names listed.

## Tasks

- [ ] 1. Add `check_metrics_coverage/1` to `DokkuRadar.CLI.Diagnose`: fetch `/metrics` via `@commands_enter_app.run(app, "web", ["wget", "-qO-", "http://127.0.0.1:9110/metrics"])`, extract required names from `grafana/dashboard.json`, compare against metrics that have data, and return `{:ok, nil}` or `{:error, "Missing metrics: <names>"}`. Register it in the `checks` list with the message `"metrics cover all Grafana panels"`. See `grafana/example-metrics.txt` for examples of metrics output with and without data samples.
- [ ] 2. Add tests in `test/dokku_radar/cli/diagnose_test.exs`: extend `stub_commands_enter_app_run` to handle the `/metrics` URL; add a passing test (all metrics present with data) and a failing test (one or more metrics absent or empty).
- [ ] 3. Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] 4. Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/cli/diagnose.ex`
- `test/dokku_radar/cli/diagnose_test.exs`
- `grafana/dashboard.json`
- `grafana/example-metrics.txt`

## Acceptance Criteria

- `bin/dokku-radar.exs diagnose` includes a `Checking metrics cover all Grafana panels...` line.
- A deployment where all metrics have data prints `✅`.
- A deployment missing one or more metrics prints `❌ Missing metrics: <names>`.
- Required metric names are derived from `grafana/dashboard.json` at runtime — not hard-coded.
- All tests pass (`mix test`).
