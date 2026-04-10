# Build Dokku Radar — a Prometheus exporter for Dokku installations

Status: [x]

## Description

Create a self-hosted monitoring tool that exposes Dokku-semantic metrics (app
process state, container health, deploy info, SSL expiry) as a Prometheus
endpoint. The tool runs as a Dokku app alongside standard Prometheus and
Grafana, using only the Docker socket and Dokku data directory as read-only
data sources — no CLI invocations or SSH.

## Technical Specifics

- Implementation language: Elixir
- Exporter app reads from `/var/run/docker.sock` (Docker labels, container
  state, restart counts, CPU/memory stats) and `/var/lib/dokku` (scale config,
  SSL certs)
- Single `GET /metrics` endpoint returning Prometheus text format; `GET
  /health` for health checks
- Ships a `Dockerfile` for containerised deployment
- Deliverables: exporter app, reference `prometheus.yml`, reference Grafana
  dashboard JSON, and setup documentation
- Open questions: scale config file path, Let's Encrypt cert paths, exporter
  port selection, optional `/metrics` auth

# Fix `dokku_app_last_deploy_timestamp` Grafana panel

Status: [x]

## Description

The "Last Deploy Timestamps" table panel shows NaN for all rows except one, because the Grafana panel is misconfigured: a `reduce` transformation collapses per-app rows into summary columns, and the `dateTimeFromNow` unit is applied to all fields (including the string `app` column).

## Technical Specifics

- In `grafana/dashboard.json`, panel "Last Deploy Timestamps":
  - Replace the `reduce` transformation with `filterFieldsByName` (keeping `app` and `Value`) followed by `organize` (renaming `Value` → `Last Deploy`)
  - Move `unit: dateTimeFromNow` from `fieldConfig.defaults` to a field-level override on the `Last Deploy` column only
  - Update `options.sortBy` to reference `"Last Deploy"` instead of `"Value"`
- The backend metric and Prometheus query are correct — no Elixir changes needed

# Move `prometheus.yml` to a dedicated `prometheus/` directory

Status: [x]

## Description

The reference `prometheus.yml` config currently lives in `config/`, alongside Elixir application config. It belongs in a top-level `prometheus/` directory to make its purpose clear and separate infrastructure config from application config.

## Technical Specifics

- Move `config/prometheus.yml` to `prometheus/prometheus.yml`.
- Update `docs/setup.md`: change the `scp` source path from `config/prometheus.yml` to `prometheus/prometheus.yml`.

# Expose linked service presence and health metrics

Status: [x]

## Description

Add metrics that show which Dokku data services (Postgres, Redis, MySQL, etc.) are linked to each app, and whether each service is currently running/healthy. This gives operators visibility into service topology and lets them alert when a linked service goes down.

## Technical Specifics

- Add `openssh-client` to the Alpine runner image (`apk add openssh-client`) so the container can SSH to the host Dokku user.
- Add a `DokkuRadar.DokkuCli` module that runs Dokku commands by SSHing to `dokku@<host>` (the standard Dokku remote API). The host, port, and path to the private key are taken from application config / environment variables.
- Discover installed service plugins by running `dokku plugin:list` and filtering against a known set of service plugin names (e.g. `postgres`, `redis`, `mysql`, `mongo`, `mariadb`). An optional `config :dokku_radar, extra_service_types: [...]` allows operators to add unlisted plugins.
- For each detected service plugin, call `dokku <type>:list` and parse the `STATUS` and `LINKS` columns.
- Expose two new Prometheus metrics:
  - `dokku_service_linked` — gauge, value `1` for each `{app, service_type, service_name}` triple where the service is linked to the app.
  - `dokku_service_status` — gauge, value `1` if the service reports status `running`, `0` otherwise; labels `{service_type, service_name}`.
- To avoid blocking Prometheus scrapes (default 10 s timeout), introduce a `DokkuRadar.ServiceCache` GenServer that:
  - Refreshes the plugin list on startup and every 5 minutes (plugins rarely change).
  - Refreshes per-service status on a shorter interval (configurable, default 30 s).
  - Exposes a `get/0` call so the existing `Collector` can read cached results with no SSH latency.
- Deployment setup: generate a dedicated SSH keypair, authorize the public key as a Dokku deploy key with read-only command scope, and mount the private key into the container as a secret. Document these steps in `docs/setup.md`.
- Add a `DokkuRadar.DokkuCli.Behaviour` and a `MockDokkuCli` for tests, following the same pattern used by `DockerClient`.

# Add Elixir logging to the application

Status: [x]

## Description

Add `require Logger` and structured `Logger.info` / `Logger.debug` calls
throughout the app so operators can understand what the exporter is doing at
runtime. Priority areas are the SSH calls in `DokkuRadar.DokkuCli` (before
each `ssh` invocation, on success, and on error) and the `ServiceCache`
GenServer lifecycle events (cache refresh start/finish, intervals).

## Technical Specifics

- In `DokkuRadar.DokkuCli.list_service_types/1`:
  - `Logger.debug` before the SSH call (include `host`).
  - `Logger.info` on success (number of service types found).
  - `Logger.warning` on error (include `exit_code` and truncated output).
- In `DokkuRadar.DokkuCli.list_services/2`:
  - `Logger.debug` before the SSH call (include `host` and `service_type`).
  - `Logger.info` on success (number of services found).
  - `Logger.warning` on error (include `exit_code` and truncated output).
- In `DokkuRadar.ServiceCache` (GenServer):
  - `Logger.info` when a refresh cycle starts and completes.
  - `Logger.debug` for per-service-type refresh steps.
- Use keyword-list structured logging where available (`Logger.info("msg", key: val)`) rather than string interpolation.
- No changes to config files are needed — Elixir's Logger defaults are sufficient; operators can tune the log level via the `LOG_LEVEL` / `logger` application env.

# Move `Dockerfile` to a `container/` subdirectory

Status: [x]

## Description

The `Dockerfile` currently lives in the repository root. Moving it to a dedicated `container/` subdirectory keeps container-related files grouped together and separates them from Elixir project files.

## Technical Specifics

- Move `Dockerfile` to `container/Dockerfile`.
- Update `.github/workflows/publish.yml`: in the "Build and push" step, add `file: container/Dockerfile` to the `docker/build-push-action` inputs (the `context: .` remains unchanged so build context paths inside the Dockerfile are unaffected).
