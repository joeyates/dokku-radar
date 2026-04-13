defmodule DokkuRadar.PsScale do
  @callback scale(String.t()) ::
              {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  require Logger

  def scale(app_name) do
    Logger.debug("Fetching ps scale via ps:scale", app: app_name)

    case @dokku_cli.call("ps:scale", [app_name]) do
      {:ok, output} ->
        {:ok, parse(output)}

      {:error, output, exit_code} ->
        Logger.warning("Failed to run ps:scale", app: app_name, exit_code: exit_code, output: output)
        {:error, {output, exit_code}}
    end
  end

  defp parse(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reject(fn line ->
      String.starts_with?(line, "----") or String.starts_with?(line, "proctype")
    end)
    |> Map.new(fn line ->
      [type, qty] = String.split(line, ":", parts: 2)
      {String.trim(type), qty |> String.trim() |> String.to_integer()}
    end)
  end
end
