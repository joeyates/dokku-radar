defmodule DokkuRadar.Ps.Cache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)

  alias DokkuRemote.App

  require Logger

  @commands_ps Application.compile_env(
                 :dokku_radar,
                 :"DokkuRemote.Commands.Ps",
                 DokkuRemote.Commands.Ps
               )

  @commands_ps_app Application.compile_env(
                     :dokku_radar,
                     :"DokkuRemote.Commands.Ps.App",
                     DokkuRemote.Commands.Ps.App
                   )

  #################
  # Client API

  @callback list() ::
              {:ok, %{String.t() => DokkuRemote.Commands.Ps.Report.t()}} | {:error, term()}
  def list(server \\ __MODULE__) do
    GenServer.call(server, :list)
  end

  @callback scale(String.t()) :: {:ok, DokkuRemote.Commands.Ps.Scale.t()} | {:error, term()}
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
    dokku_host = DokkuRadar.DokkuCli.dokku_host!()

    with {:ok, reports} <- @commands_ps.report(dokku_host),
         {:ok, scales} <- fetch_app_scales(dokku_host, reports) do
      {:update, %{entries: reports, scales: scales}}
    else
      {:error, output, exit_code} ->
        Logger.warning("Failed to obtain PS information", exit_code: exit_code, output: output)
        {:error, {output, exit_code}}
    end
  end

  defp fetch_app_scales(dokku_host, reports) do
    reports
    |> Map.keys()
    |> Enum.map(fn app -> %App{dokku_app: app, dokku_host: dokku_host} end)
    |> Enum.reduce_while(%{}, fn app, acc ->
      case @commands_ps_app.scale(app) do
        {:ok, scale} ->
          {:cont, Map.put(acc, app.dokku_app, scale)}

        {:error, output, exit_code} ->
          Logger.warning("Failed to obtain PS scale for app #{app.dokku_app}",
            exit_code: exit_code,
            output: output
          )

          {:halt, {:error, {output, exit_code}}}
      end
    end)
    |> case do
      {:error, _} = error -> error
      scales -> {:ok, scales}
    end
  end
end
