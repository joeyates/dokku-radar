defmodule DokkuRadar.Services.ServicePlugins do
  @commands_plugin Application.compile_env(
                     :dokku_radar,
                     :"DokkuRemote.Commands.Plugin",
                     DokkuRemote.Commands.Plugin
                   )

  require Logger

  @known_services ~w(
    elasticsearch
    mariadb
    memcached
    mongo
    mongodb
    mysql
    postgres
    rabbitmq
    redis
  )

  @callback list() :: {:ok, [String.t()]} | {:error, non_neg_integer(), term()}
  def list() do
    dokku_host = DokkuRadar.DokkuCli.dokku_host!()

    case @commands_plugin.list(dokku_host) do
      {:ok, entries} ->
        types = entries |> Enum.map(& &1.name) |> Enum.filter(&(&1 in @known_services))
        Logger.info("Fetched Dokku service plugins", count: length(types))
        {:ok, types}

      {:error, output, exit_code} ->
        Logger.warning("Dokku call to list plugins failed",
          exit_code: exit_code,
          output: String.slice(output, 0, 200)
        )

        {:error, output}
    end
  end
end
