defmodule DokkuRadar.Ps.Cache do
  use GenServer

  require Logger

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  @default_refresh_interval :timer.minutes(10)

  #################
  # Client API

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    gen_server_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_server_opts)
  end

  @callback list() :: {:ok, [map()]} | {:error, term()}
  @callback scale(String.t()) :: {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}

  def list(server \\ __MODULE__) do
    GenServer.call(server, :list)
  end

  def scale(app_name, server \\ __MODULE__) do
    GenServer.call(server, {:scale, app_name})
  end

  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  #################
  # Setup

  @impl GenServer
  def init(opts) do
    refresh_interval = Keyword.get(opts, :refresh_interval, @default_refresh_interval)

    state = %{
      entries: nil,
      scales: nil,
      refresh_interval: refresh_interval,
      update_task: nil,
      error: nil
    }

    {:ok, state, {:continue, :load}}
  end

  @impl GenServer
  def handle_continue(:load, %{update_task: nil} = state) do
    {:noreply, initiate_load(state)}
  end

  #################
  # Handle Client Calls

  @impl GenServer
  def handle_call(:list, _from, %{entries: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call(:list, _from, %{entries: entries} = state) do
    {:reply, {:ok, entries}, state}
  end

  def handle_call({:scale, _app_name}, _from, %{scales: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call({:scale, app_name}, _from, %{scales: scales} = state) do
    case Map.fetch(scales, app_name) do
      {:ok, scale} -> {:reply, {:ok, scale}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:status, _from, state) do
    status =
      cond do
        not is_nil(state.update_task) -> :updating
        not is_nil(state.error) -> :error
        not is_nil(state.entries) -> :ready
        true -> :unexpected
      end

    {:reply, status, state}
  end

  #################
  # Task completion/failure

  @impl GenServer
  def handle_info({ref, {:update, entries, scales}}, %{update_task: %Task{ref: ref}} = state) do
    state = demonitor(state)
    state = %{state | entries: entries, scales: scales, error: nil}
    state = maybe_enqueue_refresh(state)
    {:noreply, state}
  end

  def handle_info({ref, {:error, reason}}, %{update_task: %Task{ref: ref}} = state) do
    Logger.error("#{__MODULE__} failed to load: #{inspect(reason)}")
    state = state |> demonitor() |> maybe_enqueue_refresh()
    {:noreply, %{state | error: reason}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{update_task: %Task{ref: ref}} = state) do
    Logger.error("#{__MODULE__} load task failed: #{inspect(reason)}")
    {:noreply, %{state | update_task: nil}}
  end

  def handle_info(:refresh, %{update_task: nil} = state) do
    {:noreply, initiate_load(state)}
  end

  def handle_info(:refresh, state) do
    {:noreply, state}
  end

  #################
  # Private helpers

  defp initiate_load(state) do
    task = Task.Supervisor.async_nolink(DokkuRadar.TaskSupervisor, fn -> load() end)
    %{state | update_task: task}
  end

  defp load() do
    case @dokku_cli.call("ps:report") do
      {:ok, output} ->
        entries = DokkuRadar.Ps.Report.parse(output)
        app_names = entries |> Enum.map(& &1.app) |> Enum.uniq()
        scales = load_scales(app_names)
        {:update, entries, scales}

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
            Logger.warning("Failed to run ps:scale", app: app, exit_code: exit_code,
              output: output)
            %{}
        end

      {app, scale}
    end)
  end

  defp demonitor(%{update_task: task} = state) do
    Process.demonitor(task.ref, [:flush])
    %{state | update_task: nil}
  end

  defp maybe_enqueue_refresh(%{refresh_interval: nil} = state), do: state

  defp maybe_enqueue_refresh(%{refresh_interval: interval} = state) do
    Process.send_after(self(), :refresh, interval)
    state
  end
end
