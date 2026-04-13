defmodule DokkuRadar.Services.Service do
  @callback links(String.t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  require Logger

  def links(plugin, service) do
    case @dokku_cli.call("#{plugin}:links", [service]) do
      {:ok, output} ->
        links = parse_plain_list(output)
        {:ok, links}

      {:error, output, exit_code} ->
        {:error, {exit_code, output}}
    end
  end

  defp parse_plain_list(output) do
    String.split(output, "\n", trim: true)
  end
end
