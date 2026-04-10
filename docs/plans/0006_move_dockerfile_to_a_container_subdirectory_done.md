---
title: Move `Dockerfile` to a `container/` subdirectory
description: Move the Dockerfile from the repository root into a new container/ subdirectory, and update the GitHub Actions publish workflow to point to the new location.
branch: chore/move-dockerfile-to-container
---

## Overview

Move the `Dockerfile` from the repository root into a new `container/` subdirectory, and update the GitHub Actions publish workflow to point to the new location. The build context remains `.` so all relative paths inside the Dockerfile continue to work.

## Tasks

- [x] Move `Dockerfile` to `container/Dockerfile`
- [x] In `.github/workflows/publish.yml`, add `file: container/Dockerfile` to the "Build and push" step inputs
- [x] Ask the user for feedback on the state of the implementation and carry out any requested corrections.
- [x] Mark the plan as "done".

## Principal Files

- `Dockerfile` → `container/Dockerfile`
- `.github/workflows/publish.yml`

## Acceptance Criteria

- `container/Dockerfile` exists with identical content to the original `Dockerfile`
- `Dockerfile` no longer exists in the repository root
- `.github/workflows/publish.yml` "Build and push" step includes `file: container/Dockerfile` and retains `context: .`
