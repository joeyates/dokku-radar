defmodule DokkuRadar.Letsencrypt do
  @callback cert_expiry(String.t()) :: {:ok, DateTime.t()} | {:error, term()}

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  require Logger

  def cert_expiry(app_name) do
    Logger.debug("Fetching letsencrypt cert expiry via CLI", app: app_name)

    case @dokku_cli.call("letsencrypt:list") do
      {:ok, output} ->
        parse_expiry(output, app_name)

      {:error, output, exit_code} ->
        Logger.warning("Failed to list letsencrypt certs",
          app: app_name,
          exit_code: exit_code,
          output: output
        )

        {:error, {output, exit_code}}
    end
  end

  defp parse_expiry(output, app_name) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reject(&header_line?/1)
    |> Enum.find_value({:error, :no_cert}, fn line ->
      case String.split(line) do
        [^app_name, date, time | _rest] ->
          {:ok, parse_datetime("#{date} #{time}")}

        _ ->
          nil
      end
    end)
  end

  defp header_line?(line) do
    String.starts_with?(line, "----->") or String.starts_with?(line, "App name")
  end

  defp parse_datetime(datetime_str) do
    [date_part, time_part] = String.split(datetime_str, " ")
    [year, month, day] = date_part |> String.split("-") |> Enum.map(&String.to_integer/1)
    [hour, minute, second] = time_part |> String.split(":") |> Enum.map(&String.to_integer/1)

    year
    |> Date.new!(month, day)
    |> DateTime.new!(Time.new!(hour, minute, second))
  end
end
