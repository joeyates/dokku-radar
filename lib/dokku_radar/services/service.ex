defmodule DokkuRadar.Services.Service do
  @callback links(String.t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}

  @postgres Application.compile_env(
              :dokku_radar,
              :"DokkuRemote.Commands.Postgres",
              DokkuRemote.Commands.Postgres
            )
  @redis Application.compile_env(
           :dokku_radar,
           :"DokkuRemote.Commands.Redis",
           DokkuRemote.Commands.Redis
         )

  require Logger

  def links("postgres", service) do
    dokku_host = DokkuRadar.DokkuCli.dokku_host!()

    case @postgres.links(dokku_host, service) do
      {:ok, links} -> {:ok, links}
      {:error, output, exit_code} -> {:error, {exit_code, output}}
    end
  end

  def links("redis", service) do
    dokku_host = DokkuRadar.DokkuCli.dokku_host!()

    case @redis.links(dokku_host, service) do
      {:ok, links} -> {:ok, links}
      {:error, output, exit_code} -> {:error, {exit_code, output}}
    end
  end

  def links(other, _service), do: raise("Unknown service plugin: #{other}")
end
