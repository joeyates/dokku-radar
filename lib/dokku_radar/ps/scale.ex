defmodule DokkuRadar.Ps.Scale do
  @doc """
  Parses `ps:scale` output for a single app and returns a map of
  process type to configured count.
  """
  def parse(output) do
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
