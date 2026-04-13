defmodule DokkuRadar.Certs.Report do
  @month_map %{
    "Jan" => 1,
    "Feb" => 2,
    "Mar" => 3,
    "Apr" => 4,
    "May" => 5,
    "Jun" => 6,
    "Jul" => 7,
    "Aug" => 8,
    "Sep" => 9,
    "Oct" => 10,
    "Nov" => 11,
    "Dec" => 12
  }

  @doc """
  Parses multi-app `certs:report` output and returns a map of app names to
  their SSL certificate expiry `DateTime`s.
  """
  def parse(output) do
    lines = String.split(output, "\n", trim: true)

    {result, _current_app} =
      Enum.reduce(lines, {%{}, nil}, fn line, {acc, current_app} ->
        cond do
          String.starts_with?(line, "=====>") ->
            app = line |> String.replace_prefix("=====>", "") |> String.split() |> List.first()
            {acc, app}

          current_app != nil and String.contains?(line, "Ssl expires at:") ->
            case parse_expiry_line(line) do
              {:ok, datetime} -> {Map.put(acc, current_app, datetime), current_app}
              :error -> {acc, current_app}
            end

          true ->
            {acc, current_app}
        end
      end)

    result
  end

  defp parse_expiry_line(line) do
    case Regex.run(
           ~r/Ssl expires at:\s+(\w{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/,
           line
         ) do
      [_, month_str, day_str, hour_str, min_str, sec_str, year_str] ->
        month = Map.fetch!(@month_map, month_str)
        day = String.to_integer(day_str)
        hour = String.to_integer(hour_str)
        minute = String.to_integer(min_str)
        second = String.to_integer(sec_str)
        year = String.to_integer(year_str)

        date = Date.new!(year, month, day)
        time = Time.new!(hour, minute, second)
        {:ok, DateTime.new!(date, time)}

      _ ->
        :error
    end
  end
end
