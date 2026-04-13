defmodule DokkuRadar.Ps.Cache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)

  require Logger

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  #################
  # Client API

  @callback list() :: {:ok, [map()]} | {:error, term()}
  @callback scale(String.t()) :: {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}

  def list(server \\ __MODULE__) do
    GenServer.call(server, :list)
  end

  def scale(app_name, server \\ __MODULE__) do
    GenServer.call(server, {:scale, app_name})
  end

  #################
  # Handle Client Calls

  @impl GenServer
  def handle_call(:list, _from, %{data: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call(:list, _from, %{data: %{entries: entries}} = state) do
    {:reply, {:ok, entries}, state}
  end

  def handle_call({:scale, _app_name}, _from, %{data: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call({:scale, app_name}, _from, %{data: %{scales: scales}} = state) do
    case Map.fetch(scales, app_name) do
      {:ok, scale} -> {:reply, {:ok, scale}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(msg, from, state), do: super(msg, from, state)

  #################
  # Load

  @impl DokkuRadar.DokkuCli.Cache
  def load() do
    case @dokku_cli.call("ps:report") do
      {:ok, output} ->
        entries = DokkuRadar.Ps.Report.parse(output)
        app_names = entries |> Enum.map(& &1.app) |> Enum.uniq()
        scales = load_scales(app_names)
        {:update, %{entries: entries, scales: scales}}

      {:error, output, exit_code} ->
        Logger.warning("Failed to run ps:report", exit_code: exit_code, output: output)
        {:error, {output, exit_code}}
    end
  end

  defp load_scales(app_names) do
    Map.new(app_names, fn app ->
      scale =
        case @dokku_cli.call("ps:scale", [app]) do
          {:ok, output} ->
            DokkuRadar.Ps.Scale.parse(output)

          {:error, output, exit_code} ->
            Logger.warning("Failed to run ps:scale",
              app: app,
              exit_code: exit_code,
              output: output
            )

            %{}
        end

      {app, scale}
    end)
  end
end
