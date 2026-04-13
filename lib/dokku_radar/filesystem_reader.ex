defmodule DokkuRadar.FilesystemReader do
  @callback app_scale(String.t(), keyword()) ::
              {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}

  require Logger

  @dokku_data "/var/lib/dokku/data"

  def app_scale(app_name, opts \\ []) do
    data_dir = Keyword.get(opts, :data_dir, @dokku_data)
    scale_path = Path.join([data_dir, "ps", app_name, "scale"])

    Logger.debug("Reading app scale file", app: app_name, path: scale_path)

    case File.read(scale_path) do
      {:ok, content} ->
        {:ok, parse_scale(content)}

      {:error, reason} ->
        Logger.warning("Failed to read app scale file",
          app: app_name,
          path: scale_path,
          reason: reason
        )

        {:error, reason}
    end
  end

  defp parse_scale(content) do
    content
    |> String.split("\n", trim: true)
    |> Map.new(fn line ->
      [process_type, count] = String.split(line, "=", parts: 2)
      {String.trim(process_type), count |> String.trim() |> String.to_integer()}
    end)
  end
end
