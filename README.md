# Dokku Radar

A Prometheus exporter for [Dokku](https://dokku.com/) installations. It reads
from the Docker socket and the Dokku data directory (both mounted read-only)
to expose Dokku-semantic metrics — configured vs running processes, container
state and restarts, SSL certificate expiry, CPU and memory usage, and last
deploy timestamps.

The container image is published to GHCR and deployed to Dokku via
`dokku git:from-image`.

## Quick Start

```bash
export DOKKU_APP=dokku-radar
dokku apps:create $DOKKU_APP
dokku git:from-image $DOKKU_APP ghcr.io/joeyates/dokku-radar:latest
```

See [docs/setup.md](docs/setup.md) for the complete setup guide, including
Prometheus, Grafana, networking, and storage mounts.

## Prerequisites

- A working [Dokku](https://dokku.com/) installation (tested with Dokku 0.35+)
- The Dokku network plugin (ships with Dokku)
- Docker on the host
- SSH access to the Dokku host (both as `dokku` user and `root`)

### Recommended Aliases

The setup guide assumes two local shell aliases:

| Alias | Command |
|---|---|
| `dokku` | `ssh -t dokku@$DOKKU_HOST "$@"` |
| `dokku-root` | `ssh -o LogLevel=QUIET -t root@$DOKKU_HOST dokku` |

Set `DOKKU_HOST` to your server's hostname or IP.

## Metrics

| Metric | Type | Labels | Description |
|---|---|---|---|
| `dokku_app_processes_configured` | gauge | `app`, `process_type` | Number of processes defined in the scale file |
| `dokku_app_processes_running` | gauge | `app`, `process_type` | Number of currently running processes |
| `dokku_container_state` | gauge | `app`, `container_id`, `container_name`, `state` | Container state (1 = current state as labeled) |
| `dokku_container_restarts_total` | counter | `app`, `container_id`, `container_name` | Total container restart count |
| `dokku_app_last_deploy_timestamp` | gauge | `app` | Unix timestamp of the most recent container creation |
| `dokku_ssl_cert_expiry_timestamp` | gauge | `app` | Unix timestamp of SSL certificate expiry |
| `dokku_app_cpu_usage_seconds_total` | counter | `app`, `container_id` | Total CPU usage in seconds |
| `dokku_app_memory_usage_bytes` | gauge | `app`, `container_id` | Current memory usage in bytes |

## Endpoints

| Path | Response |
|---|---|
| `GET /metrics` | Prometheus text exposition format |
| `GET /health` | `200 ok` |

## Configuration

The exporter reads `PORT` from the environment (Dokku sets this automatically).
The fallback default is `9110`, used when running locally or via `docker run`.

## Development

```bash
mix deps.get
mix test
mix check-formatted
```

## License

MIT
