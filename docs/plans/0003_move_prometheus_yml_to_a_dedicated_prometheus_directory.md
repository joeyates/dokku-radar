---
title: Move `prometheus.yml` to a dedicated `prometheus/` directory
description: Move the reference prometheus.yml from config/ to a top-level prometheus/ directory, and update the scp command in docs/setup.md.
branch: chore/move-prometheus-config
---

## Overview

Move the reference `prometheus.yml` from `config/` (Elixir app config) to a top-level `prometheus/` directory, and update the `scp` command in `docs/setup.md` to reflect the new path.

## Tasks

- [ ] Move `config/prometheus.yml` to `prometheus/prometheus.yml`
- [ ] Update `docs/setup.md`: change `scp config/prometheus.yml` → `scp prometheus/prometheus.yml`
- [ ] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] Mark the plan as "done".

## Principal Files

- `config/prometheus.yml` → `prometheus/prometheus.yml`
- `docs/setup.md`

## Acceptance Criteria

- `prometheus/prometheus.yml` exists with the same content as the original
- `config/prometheus.yml` is removed
- `docs/setup.md` references `prometheus/prometheus.yml` in the `scp` command
