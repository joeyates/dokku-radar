defmodule DokkuRadar.Ps.Report do
  @doc """
  Parses multi-app `ps:report` output and returns a list of process entry maps.
  """
  def parse(output) do
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
