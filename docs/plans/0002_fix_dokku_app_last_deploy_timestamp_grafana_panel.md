---
title: Fix `dokku_app_last_deploy_timestamp` Grafana panel
description: Fix the "Last Deploy Timestamps" table panel which shows NaN for almost all rows due to a misconfigured Grafana transformation and unit setting.
branch: bugfix/fix-last-deploy-timestamp-panel
---

## Overview

The "Last Deploy Timestamps" table panel in the Grafana dashboard currently shows NaN for almost all rows. The bug is entirely in the dashboard JSON configuration — the `reduce` transformation collapses the per-app rows into column summaries, and `dateTimeFromNow` is applied to all fields including the string `app` column. The backend metric is correct and needs no changes.

## Tasks

- [ ] Replace the `reduce` transformation with `filterFieldsByName` (keeping `app` and `Value`) followed by `organize` (renaming `Value` → `Last Deploy`)
- [ ] Move `unit: dateTimeFromNow` from `fieldConfig.defaults` to a field-level override on the `Last Deploy` column
- [ ] Update `options.sortBy` to reference `"Last Deploy"` instead of `"Value"`
- [ ] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] Mark the plan as "done".

## Principal Files

- `grafana/dashboard.json`

## Acceptance Criteria

- The "Last Deploy Timestamps" table shows one row per Dokku app
- The "Last Deploy" column displays human-readable relative times (e.g. "9 days ago") for all apps
- The table sorts by most-recently-deployed app first
