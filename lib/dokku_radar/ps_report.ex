defmodule DokkuRadar.PsReport do
  @callback list() :: {:ok, [map()]} | {:error, term()}

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  require Logger

  def list() do
    Logger.debug("Fetching ps report via ps:report")

    case @dokku_cli.call("ps:report") do
      {:ok, output} ->
        {:ok, parse(output)}

      {:error, output, exit_code} ->
        Logger.warning("Failed to run ps:report", exit_code: exit_code, output: output)
        {:error, {output, exit_code}}
    end
  end

  defp parse(output) do
    {entries, _current_app} =
      output
      |> String.split("\n", trim: true)
      |> Enum.reduce({[], nil}, fn line, {acc, current_app} ->
        cond do
          String.starts_with?(line, "=====>") ->
            app = line |> String.replace_prefix("=====>", "") |> String.split() |> List.first()
            {acc, app}

          current_app != nil ->
            case parse_status_line(line) do
              {:ok, entry} -> {[Map.put(entry, :app, current_app) | acc], current_app}
              :error -> {acc, current_app}
            end

          true ->
            {acc, current_app}
        end
      end)

    Enum.reverse(entries)
  end

  defp parse_status_line(line) do
    case Regex.run(~r/Status (\w+) (\d+):\s+(\w+) \(CID: ([a-f0-9]+)\)/, line) do
      [_, process_type, index_str, state, cid] ->
        {:ok,
         %{
           process_type: process_type,
           process_index: String.to_integer(index_str),
           state: state,
           cid: cid
         }}

      _ ->
        :error
    end
  end
end
