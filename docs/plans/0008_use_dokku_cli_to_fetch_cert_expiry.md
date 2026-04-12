---
title: Use Dokku CLI to fetch cert expiry
description: Replace FilesystemReader.cert_expiry/2 filesystem-based implementation with a new DokkuRadar.Letsencrypt module that calls `dokku letsencrypt:list` via DokkuCli and parses the tabular output.
branch: feature/letsencrypt-cli
---

## Overview

Replace the `FilesystemReader.cert_expiry/2` filesystem-based implementation (PEM decoding, cert path resolution) with a new `DokkuRadar.Letsencrypt` module that calls `dokku letsencrypt:list` via `DokkuCli.call/1` and parses the tabular output.

## Tasks

- [ ] Create `lib/dokku_radar/letsencrypt.ex` with `DokkuRadar.Letsencrypt`:
  - `@callback cert_expiry(String.t()) :: {:ok, DateTime.t()} | {:error, term()}`
  - `cert_expiry/1` calls `DokkuCli.call("letsencrypt:list")`, skips header lines (starting with `----->` or `App name`), finds the row matching the app, and parses columns 2–3 as `"YYYY-MM-DD HH:MM:SS"` into a `DateTime`
  - Returns `{:error, :no_cert}` if the app is not in the list; `{:error, reason}` on CLI failure
- [ ] Replace `FilesystemReader.cert_expiry/2` body to delegate to `DokkuRadar.Letsencrypt.cert_expiry/1` (dropping the `opts` that were filesystem-specific), removing all PEM/filesystem logic and the private `extract_expiry/1`, `asn1_time_to_datetime/1` helpers
- [ ] Update the `@callback cert_expiry` in `FilesystemReader` to drop the `keyword()` opts argument: `cert_expiry(String.t()) :: {:ok, DateTime.t()} | {:error, term()}`
- [ ] Add `Mox.defmock(DokkuRadar.Letsencrypt.Mock, for: DokkuRadar.Letsencrypt)` to `test/support/mocks.ex`
- [ ] Create `test/dokku_radar/letsencrypt_test.exs` covering: known app present, app absent (`{:error, :no_cert}`), CLI failure, header lines correctly skipped
- [ ] Remove the `cert_expiry` describe block from `test/dokku_radar/filesystem_reader_test.exs` (those tests are superseded)
- [ ] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [ ] Mark the plan as "done".

## Principal Files

- `lib/dokku_radar/letsencrypt.ex` *(new)*
- `lib/dokku_radar/filesystem_reader.ex`
- `lib/dokku_radar/dokku_cli.ex`
- `lib/dokku_radar/collector.ex`
- `test/dokku_radar/letsencrypt_test.exs` *(new)*
- `test/dokku_radar/filesystem_reader_test.exs`
- `test/support/mocks.ex`

## Acceptance Criteria

- `DokkuRadar.Letsencrypt.cert_expiry/1` correctly parses `letsencrypt:list` output into a `DateTime`
- `FilesystemReader.cert_expiry/2` contains no filesystem or PEM logic
- No references to `extract_expiry` or `asn1_time_to_datetime` remain in `filesystem_reader.ex`
- All existing tests pass; new tests cover the happy path, missing-app, and CLI-error cases
