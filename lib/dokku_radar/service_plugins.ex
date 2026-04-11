defmodule DokkuRadar.ServicePlugins do
  alias DokkuRadar.DokkuCli

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

  def list() do
    case DokkuCli.call("plugin:list") do
      {:ok, output} ->
        types = parse_plugin_list(output)
        Logger.info("Fetched Dokku service plugins", count: length(types))
        {:ok, types}

      {:error, output, exit_code} ->
        Logger.warning("SSH call to list plugins failed",
          exit_code: exit_code,
          output: String.slice(output, 0, 200)
        )

        {:error, {exit_code, output}}
    end
  end

  defp parse_plugin_list(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      line |> String.trim() |> String.split(~r/\s+/) |> List.first()
    end)
    |> Enum.filter(&(&1 in @known_services))
  end
end
