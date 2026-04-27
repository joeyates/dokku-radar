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

# Merge behaviour modules into main modules

Status: [x]

## Description

Move `@callback` declarations from separate `*.Behaviour` submodules into their parent modules, following the existing pattern in `DokkuRadar.ServiceCache`. Delete the now-redundant `behaviour.ex` files. Update `test/support/mocks.ex` to reference the main modules instead of the `Behaviour` submodules. Tests may be left broken after this change; they will be fixed in the next plan.

## Technical Specifics

- For each of the following pairs, move `@callback` declarations into the main module and delete the `behaviour.ex` file:
  - `DokkuRadar.DockerClient` / `DokkuRadar.DockerClient.Behaviour`
  - `DokkuRadar.FilesystemReader` / `DokkuRadar.FilesystemReader.Behaviour`
  - `DokkuRadar.Service` / `DokkuRadar.Service.Behaviour`
  - `DokkuRadar.ServicePlugin` / `DokkuRadar.ServicePlugin.Behaviour`
  - `DokkuRadar.ServicePlugins` / `DokkuRadar.ServicePlugins.Behaviour`
  - `DokkuRadar.Collector` / `DokkuRadar.Collector.Behaviour`
- For `DokkuRadar.DokkuCli`: delete `DokkuRadar.DokkuCli.Behaviour` but do not add `@callback` declarations to the main module yet (its behaviour methods are not yet implemented).
- Remove `@behaviour ModuleName.Behaviour` and `@impl true` from each main module (callbacks are declared in the same module, not a separate behaviour).
- In `test/support/mocks.ex`, change each `for: DokkuRadar.X.Behaviour` to `for: DokkuRadar.X` (matching the existing `DokkuRadar.ServiceCache.Mock` entry). Remove the `DokkuRadar.DokkuCli.Mock` entry entirely (since `DokkuCli` has no `@callback` declarations yet).
- Tests may be left broken after this change.

# Move `Dockerfile` to a `container/` subdirectory

Status: [x]

## Description

The `Dockerfile` currently lives in the repository root. Moving it to a dedicated `container/` subdirectory keeps container-related files grouped together and separates them from Elixir project files.

## Technical Specifics

- Move `Dockerfile` to `container/Dockerfile`.
- Update `.github/workflows/publish.yml`: in the "Build and push" step, add `file: container/Dockerfile` to the `docker/build-push-action` inputs (the `context: .` remains unchanged so build context paths inside the Dockerfile are unaffected).

# Use Dokku CLI to fetch cert expiry

Status: [x]

## Description

Replace the `FilesystemReader.cert_expiry/2` implementation that reads TLS certificate files directly from the filesystem with a new `DokkuRadar.Letsencrypt` module that calls `dokku letsencrypt:list` via the Dokku CLI (SSH), parsing its tabular output.

## Technical Specifics

- Create `lib/dokku_radar/letsencrypt.ex` as `DokkuRadar.Letsencrypt`.
- Add a `cert_expiry/2` function that calls `DokkuRadar.DokkuCli.run/1` with `["letsencrypt:list"]` and parses the output table.
- The table has the form:
  ```
  -----> App name           Certificate Expiry        Time before expiry ...
  myapp                     2026-06-30 11:12:59       ...
  ```
  Skip the header line(s) (those starting with `----->` or `App name`), split each data row on whitespace, and parse columns 2–3 (`"YYYY-MM-DD HH:MM:SS"`) into a `DateTime`.
- Return `{:ok, %DateTime{}}` on success, `{:error, :no_cert}` if the app is not present in the list, and `{:error, reason}` on CLI failure.
- Remove the filesystem cert-reading logic from `DokkuRadar.FilesystemReader.cert_expiry/2` and update its `@callback` to delegate to `DokkuRadar.Letsencrypt`.
- Add tests for `DokkuRadar.Letsencrypt`; add a fixture string for `letsencrypt:list` output in `test/support/`.

# Replace runtime dependency injection with `Application.compile_env`

Status: [x]

## Description

Two modules still inject their dependencies at runtime via keyword opts or Plug conn private fields, rather than via `Application.compile_env` module attributes as in `DokkuRadar.ServiceCache`. Replace these ad-hoc patterns with consistent compile-time configuration.

## Technical Specifics

- In `lib/dokku_radar/collector.ex`, replace the three `Keyword.get(opts, :docker_client/filesystem_reader/service_cache, ...)` calls with `@docker_client`, `@filesystem_reader`, and `@service_cache` module attributes backed by `Application.compile_env/3`.
- In `lib/dokku_radar/router.ex`, replace `conn.private[:collector] || DokkuRadar.Collector` and the `init/1`/`call/2` override with a `@collector Application.compile_env(...)` module attribute.
- In `config/test.exs`, add the four missing mock entries: `"DokkuRadar.DockerClient": DokkuRadar.DockerClient.Mock`, `"DokkuRadar.FilesystemReader": DokkuRadar.FilesystemReader.Mock`, `"DokkuRadar.ServiceCache": DokkuRadar.ServiceCache.Mock`, and `"DokkuRadar.Collector": DokkuRadar.Collector.Mock`.
- In `test/dokku_radar/collector_test.exs`, remove the `@opts` keyword list and update all `Collector.collect(@opts)` calls to `Collector.collect()`.
- In `test/dokku_radar/router_test.exs`, remove the `collector:` argument from `Router.init/1` and simplify accordingly.

# Use Dokku CLI Instead of Filesystem/Docker

Status: [x]

## Description

Refactor metric collection to use Dokku CLI commands (via SSH) instead of reading the filesystem or Docker API directly, where equivalent data is available. This covers process scale and running counts, last deploy timestamps, SSL cert expiry (for non-Let's Encrypt certs), and service status.

# Introduce `DokkuRadar.Services` namespace

Status: [x]

## Description

Move the existing `ServiceCache` and its companion modules into a `DokkuRadar.Services` namespace. Create a new `DokkuRadar.Services` front-end module that exposes the API consumed by `Collector`, establishing the namespace pattern to be repeated for all metrics domains.

## Technical Specifics

- Rename `DokkuRadar.ServiceCache` → `DokkuRadar.Services.Cache`; move file to `lib/dokku_radar/services/cache.ex`.
- Rename `DokkuRadar.Service` → `DokkuRadar.Services.Service`; move file to `lib/dokku_radar/services/service.ex`.
- Rename `DokkuRadar.ServicePlugin` → `DokkuRadar.Services.ServicePlugin`; move file to `lib/dokku_radar/services/service_plugin.ex`.
- Rename `DokkuRadar.ServicePlugins` → `DokkuRadar.Services.ServicePlugins`; move file to `lib/dokku_radar/services/service_plugins.ex`.
- Create `lib/dokku_radar/services.ex` as `DokkuRadar.Services` — a thin front-end that delegates to `DokkuRadar.Services.Cache` and is the only `Services`-related entry point for `DokkuRadar.Collector`.
- Update all call sites (`Collector`, `Application`, `config/test.exs`, mocks) to use the new names.

# Apply namespace + cache pattern to `Git`, `Certs`, and `Ps` domains

Status: [x]

## Description

Following the pattern established by "Introduce `DokkuRadar.Services` namespace", reorganise the remaining metrics domains into namespaces. Each domain gets a `Cache` GenServer that owns Dokku CLI calls, pure parser sub-modules, and a front-end module for `Collector`. After this work, no module outside a `*.Cache` GenServer should call `DokkuRadar.DokkuCli` directly.

## Technical Specifics

- `Git` domain: `DokkuRadar.GitReport` → `DokkuRadar.Git.Report` (pure parser); new `DokkuRadar.Git.Cache` GenServer; new `DokkuRadar.Git` front-end.
- `Certs` domain: `DokkuRadar.Certs` → `DokkuRadar.Certs.Report` (pure parser); new `DokkuRadar.Certs.Cache` GenServer; new `DokkuRadar.Certs` front-end.
- `Ps` domain: `DokkuRadar.PsScale` → `DokkuRadar.Ps.Scale` and `DokkuRadar.PsReport` → `DokkuRadar.Ps.Report` (pure parsers); new `DokkuRadar.Ps.Cache` GenServer; new `DokkuRadar.Ps` front-end.
- Update `Collector`, `Application`, `config/test.exs`, and mocks for all renamed modules.

# Extract `DokkuRadar.DokkuCli.Cache` shared GenServer macro

Status: [x]

## Description

Extract the shared GenServer boilerplate from `Certs.Cache`, `Git.Cache`, `Ps.Cache`, and `Services.Cache` into a `DokkuRadar.DokkuCli.Cache` macro (`use DokkuRadar.DokkuCli.Cache`), leaving only domain-specific logic in each module. Also fixes three bugs in `Services.Cache` uncovered during the refactor.

## Technical Specifics

- Create `lib/dokku_radar/dokku_cli/cache.ex` implementing `__using__/1` with shared `start_link/1`, `status/1`, `refresh/1`, GenServer callbacks, and helpers (`initiate_load/1`, `demonitor/1`, `maybe_enqueue_refresh/1`). Mark `handle_info/2` and `handle_call/3` as `defoverridable`.
- Unified state shape: `%{data: nil, refresh_interval: integer() | nil, update_task: Task.t() | nil, error: term() | nil}`. `:status` returns `:ready` when `data` is non-nil.
- Each module implements `@callback load() :: {:update, term()} | {:error, term()}` and retains only domain-specific `handle_call` clauses, falling through to `super` for `:status`.
- Unify `data` field names: `Certs.Cache` (expiries map), `Git.Cache` (timestamps map), `Ps.Cache` (`%{entries:, scales:}`), `Services.Cache` (`%{plugins:, services:, service_links:}`).
- Bug fixes in `Services.Cache`: (1) call `maybe_enqueue_refresh` after `:update`; (2) fix kill-and-restart so `update_task` is cleared and `initiate_load` is called immediately; (3) change `load/0` to return `{:update, %{plugins:, services:, service_links:}}`.
- See `refactor.md` for full per-module skeletons.

# Use DokkuRemote for dokku calls

Status: [x]

## Description

Replace `DokkuRadar.DokkuCli` (the bespoke SSH wrapper) with the already-available `DokkuRemote` library.

## Technical Specifics

- `DokkuRemote` is already a dependency.
- All `@dokku_cli.call(...)` usages in `Certs.Cache`, `Git.Cache`, `Ps.Cache`, `Services.Cache`, `Services.ServicePlugin`, `Services.ServicePlugins`, and `Services.Service` should be replaced with appropriate `DokkuRemote.Commands.*` calls.

# Create a Diagnostic CLI

Status: [x]

## Description

Implement `bin/dokku-radar.exs diagnose` to be used remotely to
check the correct functioning and installation of the project.

## Technical Specifics

- Use `DokkuRemote.Commands` calls to fetch data from the deployed project.
- Use docs/system-checks.md` and `docs/troubleshooting.md` for a basis of what to check.

# Fix `DokkuRadar.Collector` — align with actual types

Status: [x]

## Description

`DokkuRadar.Collector` contains several type mismatches against the structs returned by `DokkuRemote` and the project's own cache modules. Fix all mismatches so the collector produces output compatible with `grafana/dashboard.json`.

## Technical Specifics

- Audit every access to `ps_reports` entries against `DokkuRemote.Commands.Ps.Report.t()` and `DokkuRemote.Commands.Ps.Report.StatusEntry.t()`.
- Audit `scale` values against `DokkuRemote.Commands.Ps.Scale.t()` (which has a `proctypes` map, not bare `{process_type, count}` pairs).
- Verify metric label keys (`"app"`, `"process_type"`, `"process_name"`, etc.) match the Prometheus queries in `grafana/dashboard.json`.

# Cache Docker calls following the pattern used by other modules

Status: [x]

## Description

Cache results from `DokkuRadar.DockerClient` in a GenServer (following the cache pattern used by `Certs.Cache`, `Git.Cache`, `Ps.Cache`, and `Services.Cache`) so that Docker API calls do not block Prometheus scrapes.

# Validate metrics output against Grafana dashboard panels

Status: [x]

## Description

Add a phase to `bin/dokku-radar.exs diagnose` that fetches the live `/metrics` output from inside the `dokku-radar` container (via an `enter` call) and checks that every metric name referenced by a Grafana panel in `grafana/dashboard.json` has data in the output. This gives operators confidence that the exporter is producing data that will populate the dashboard.

## Technical Specifics

- Add a `check_metrics_coverage/1` function to `DokkuRadar.CLI.Diagnose`.
- Fetch metrics via `@commands_enter_app.run(app, "web", ["wget", "-qO-", "http://127.0.0.1:9110/metrics"])`.
- Extract required metric names from `grafana/dashboard.json` at runtime: read and decode the file, collect all `"expr"` string values from panel targets, and extract bare metric names using a regex (e.g. `~r/\bdokku_\w+/`).
- Parse the metrics output to determine which metric names have data; see `grafana/example-metrics.txt` for examples of metrics with and without data samples.
- Report `✅ Metrics cover all Grafana panels` if all names are found; otherwise `❌ Missing metrics: <names>`.
- Add a test in `test/dokku_radar/cli/diagnose_test.exs` covering pass and fail cases, using `stub_commands_enter_app_run` with a fixture metrics string.
