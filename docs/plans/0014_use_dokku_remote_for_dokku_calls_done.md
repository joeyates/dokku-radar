# Use DokkuRemote for dokku calls

Replace `DokkuRadar.DokkuCli.call/2` (bespoke SSH wrapper) with injected
`DokkuRemote.Commands.*` modules. `DokkuRemote` is already a dependency and
already configured in `runtime.exs`. `DokkuRadar.Git.Report` already calls
`DokkuRemote.Commands.Git.report/1` directly — but without injection, so it
cannot be tested. The pattern to follow for every task: write failing tests
first, implement, `mix test`, `mix check-formatted`, commit.

---

## Task 1 — `DokkuRadar.Git.Report` (inject `DokkuRemote.Commands.Git`)

- [x] In `DokkuRemote.Commands.Git`, add
  `@callback report(String.t()) :: {:ok, reports()} | {:error, any(), any()}`.
- In `Git.Report`, add
  `@commands_git Application.compile_env(:dokku_radar, :"DokkuRemote.Commands.Git", DokkuRemote.Commands.Git)`
  and replace the direct `DokkuRemote.Commands.Git.report(dokku_host)` call
  with `@commands_git.report(dokku_host)`.
- Add `Mox.defmock(DokkuRemote.Commands.Git.Mock, for: DokkuRemote.Commands.Git)`
  to `test/support/mocks.ex`.
- Add `"DokkuRemote.Commands.Git": DokkuRemote.Commands.Git.Mock` to
  `config/test.exs`.
- Write tests in `test/dokku_radar/git/report_test.exs` — happy path (map of
  app → timestamp) and error path.

---

## Task 2 — `DokkuRadar.Certs.Cache` (inject `DokkuRemote.Commands.Certs`)

- [x] In `DokkuRemote.Commands.Certs`, add
  `@callback report(String.t()) :: {:ok, reports()} | {:error, any(), any()}`.
- In `Certs.Cache`, replace `@dokku_cli` with `@commands_certs` injecting
  `DokkuRemote.Commands.Certs`. Replace `@dokku_cli.call("certs:report")` with
  `@commands_certs.report(dokku_host)`.
- `DokkuRemote.Commands.Certs.report/1` returns
  `{:ok, %{app_name => DokkuRemote.Commands.Certs.Report.t()}}`. Update
  `Certs.Cache.load/0` to extract `expires_at` from each `Report.t()` struct
  rather than from raw CLI output.
- Add `DokkuRemote.Commands.Certs.Mock`, update `test.exs`; update
  `Certs.CacheTest` to stub `report/1` returning struct maps instead of
  `DokkuCli.Mock.call("certs:report")` returning raw strings.

---

## Task 3 — `DokkuRadar.Ps.Cache` (inject `DokkuRemote.Commands.Ps`)

- [x] In `DokkuRemote.Commands.Ps`, add a `report/1` function (runs `ps:report`)
  and `@callback` declarations for `report/1`, `scale/1`, `scale/2`.
- In `Ps.Cache`, replace `@dokku_cli` with `@commands_ps` injecting
  `DokkuRemote.Commands.Ps`. Replace `@dokku_cli.call("ps:report")` with
  `@commands_ps.report(dokku_host)` and each `@dokku_cli.call("ps:scale", [app])`
  with `@commands_ps.scale(dokku_host, app)`. Adapt `load_scales` to consume
  the `DokkuRemote.Commands.Ps.Scale.t()` structs directly instead of parsing
  raw output via `DokkuRadar.Ps.Scale.parse/1`.
- Add `DokkuRemote.Commands.Ps.Mock`, update `test.exs`; update `Ps.CacheTest`.

---

## Task 4 — `DokkuRadar.Services.ServicePlugins` (inject `DokkuRemote.Commands.Plugin`)

- [x] In `DokkuRemote.Commands.Plugin`, add
  `@callback list(String.t()) :: {:ok, [Entry.t()]} | {:error, any(), any()}`.
- In `ServicePlugins`, replace `@dokku_cli` with `@commands_plugin` injecting
  `DokkuRemote.Commands.Plugin`. Replace `@dokku_cli.call("plugin:list")` with
  `@commands_plugin.list(dokku_host)`. Update filtering to check
  `entry.name in @known_services` on the returned `[Entry.t()]` list rather
  than splitting raw output.
- Add `DokkuRemote.Commands.Plugin.Mock`, update `test.exs`; update
  `ServicePluginsTest` to stub `list/1` with a list of `Entry.t()` structs.

---

## Task 5 — `DokkuRadar.Services.ServicePlugin` and `DokkuRadar.Services.Service`

Use pattern-matching on the plugin name to call the appropriate
`DokkuRemote.Commands.*` module directly, with one injected module attribute
per supported service type. Unknown plugin names raise at runtime.

### `ServicePlugin` [x]

Replace the single `@dokku_cli`-based `services/1` with per-plugin clauses:

```elixir
@postgres Application.compile_env(:dokku_radar, :"DokkuRemote.Commands.Postgres", DokkuRemote.Commands.Postgres)
@redis    Application.compile_env(:dokku_radar, :"DokkuRemote.Commands.Redis",    DokkuRemote.Commands.Redis)

def services("postgres") do
  dokku_host = DokkuRadar.DokkuCli.dokku_host!()
  case @postgres.list(dokku_host) do
    {:ok, services} -> {:ok, services}
    {:error, output, exit_code} -> {:error, exit_code, output}
  end
end

def services("redis") do
  dokku_host = DokkuRadar.DokkuCli.dokku_host!()
  case @redis.list(dokku_host) do
    {:ok, services} -> {:ok, services}
    {:error, output, exit_code} -> {:error, exit_code, output}
  end
end

def services(other), do: raise("Unknown service plugin: #{other}")
```

- In `DokkuRemote.Commands.Postgres` and `DokkuRemote.Commands.Redis`, add
  `@callback list(String.t()) :: {:ok, [String.t()]} | {:error, any(), any()}`.
- Add `DokkuRemote.Commands.Postgres.Mock` and `DokkuRemote.Commands.Redis.Mock`,
  update `test.exs`; rewrite `ServicePluginTest` to stub `list/1` on the
  appropriate mock.

### `Service`

Same pattern for `links/2`:

```elixir
def links("postgres", service) do
  dokku_host = DokkuRadar.DokkuCli.dokku_host!()
  case @postgres.links(dokku_host, service) do
    {:ok, links} -> {:ok, links}
    {:error, output, exit_code} -> {:error, {exit_code, output}}
  end
end

def links("redis", service) do ...

def links(other, _service), do: raise("Unknown service plugin: #{other}")
```

- In `DokkuRemote.Commands.Postgres` and `DokkuRemote.Commands.Redis`, add
  `@callback links(String.t(), String.t()) :: {:ok, [String.t()]} | {:error, any(), any()}`.
- Rewrite `ServiceTest` to stub `links/2` on the appropriate mock.

---

## Task 6 — Cleanup: remove `DokkuCli.call/2`

- [x] Remove `call/2`, `ssh_args/1`, `@system`, and the `@callback call(...)` declarations
  from `DokkuRadar.DokkuCli`. Keep `dokku_host!/0` — it is still called by the
  modules above to obtain the host before passing to DokkuRemote.
- Remove `DokkuRadar.DokkuCli.Mock` from `test/support/mocks.ex` and
  `"DokkuRadar.DokkuCli"` from `config/test.exs`.
- Add `config :dokku_radar, DokkuRadar.DokkuCli, dokku_host: "test.example.com"` to
  `config/test.exs` so `dokku_host!()` resolves during tests without a real env var.
- Run full `mix test`; commit.
