defmodule DokkuRadar.GitReport do
  @callback report(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  require Logger

  def report(app_name) do
    Logger.debug("Fetching git report via git:report", app: app_name)

    case @dokku_cli.call("git:report", [app_name]) do
      {:ok, output} ->
        parse(output, app_name)

      {:error, output, exit_code} ->
        Logger.warning("Failed to run git:report",
          app: app_name,
          exit_code: exit_code,
          output: output
        )

        {:error, {output, exit_code}}
    end
  end

  defp parse(output, app_name) do
    case Regex.run(~r/Git last updated at:\s+(\d+)/, output) do
      [_, ts_str] ->
        {:ok, String.to_integer(ts_str)}

      nil ->
        Logger.warning("Could not parse git:report output", app: app_name)
        {:error, :no_timestamp}
    end
  end
end
