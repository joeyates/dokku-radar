defmodule DokkuRadar.PrometheusFormatter do
  def format([]), do: ""

  def format(metrics) do
    metrics
    |> Enum.map(&format_metric/1)
    |> Enum.join("\n")
  end

  defp format_metric(metric) do
    lines = [
      "# HELP #{metric.name} #{metric.help}",
      "# TYPE #{metric.name} #{metric.type}"
      | Enum.map(metric.samples, &format_sample(metric.name, &1))
    ]

    Enum.join(lines, "\n") <> "\n"
  end

  defp format_sample(name, sample) do
    labels = format_labels(sample.labels)
    value = format_value(sample.value)
    "#{name}{#{labels}} #{value}"
  end

  defp format_labels(labels) do
    labels
    |> Enum.sort_by(fn {key, _val} -> key end)
    |> Enum.map(fn {key, val} -> ~s(#{key}="#{escape_label_value(val)}") end)
    |> Enum.join(",")
  end

  defp escape_label_value(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  defp format_value(value) when is_integer(value), do: Integer.to_string(value)

  defp format_value(value) when is_float(value) do
    if value == Float.round(value, 0) and value == trunc(value) do
      # Whole float like 2.0 -> "2"
      value |> trunc() |> Integer.to_string()
    else
      Float.to_string(value)
    end
  end
end
