defmodule DokkuRadar.Services.ServicePlugin do
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

  @callback services(String.t()) :: {:ok, [String.t()]} | {:error, non_neg_integer(), term()}
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
end
