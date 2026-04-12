defmodule DokkuRadar.ServicePlugin do
  @callback services(String.t()) :: {:ok, [String.t()]} | {:error, non_neg_integer(), term()}

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  require Logger

  def services(plugin) do
    case @dokku_cli.call("#{plugin}:list") do
      {:ok, output} ->
        services = parse_services(output)
        {:ok, services}

      {:error, output, exit_code} ->
        {:error, exit_code, output}
    end
  end

  defp parse_services(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "====="))
  end
end
