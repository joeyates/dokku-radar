defmodule DokkuRadar.Git.Report do
  @doc """
  Parses multi-app `git:report` output and returns a map of app names to
  their last-deploy Unix timestamps.
  """
  def parse(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reduce({nil, %{}}, &parse_line/2)
    |> elem(1)
  end

  defp parse_line("=====> " <> rest, {_current_app, acc}) do
    app_name = rest |> String.split(" ") |> List.first()
    {app_name, acc}
  end

  defp parse_line(line, {current_app, acc}) when is_binary(current_app) do
    case Regex.run(~r/Git last updated at:\s+(\d+)/, line) do
      [_, ts_str] -> {current_app, Map.put(acc, current_app, String.to_integer(ts_str))}
      nil -> {current_app, acc}
    end
  end

  defp parse_line(_line, {nil, acc}), do: {nil, acc}
end
