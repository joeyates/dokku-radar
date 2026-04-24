# Overview

A `Bandit` endpoint respondes on `/metrics`.
The DokkuRadar.Collector calls various metrics producers.
Most of the producers, when called, read the relevant values and return them.
On the other hand, DokkuRadar.ServiceCache caches its metrics as they are slow to read.

# Fetching Data

Data is principally fetched via CLI calls from the app to the host, via SSH.

Data about container status is obtained by Docker calls from within the app's
container via the Docker socket which is mounted in container.

# Environment

This project uses direnv for configuration. `.envrc` lists and documents the environment variables. The git-ignored `.envrc.private` contains the actual values.
