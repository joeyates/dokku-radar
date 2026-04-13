# Overview

A `Bandit` endpoint respondes on `/metrics`.
The DokkuRadar.Collector calls various metrics producers.
Most of the producers, when called, read the relevant values and return them.
On the other hand, DokkuRadar.ServiceCache caches its metrics as they are slow to read.

# Environment

This project uses direnv for configuration. `.envrc` lists and docuemtns the environment variables. The git-ignored `.envrc.private` contains the actual values.
