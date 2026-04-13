defmodule DokkuRadar.Git.Cache do
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

  @callback last_deploy_timestamps() ::
              {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}

  def last_deploy_timestamps(server \\ __MODULE__) do
    GenServer.call(server, :last_deploy_timestamps)
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
      timestamps: nil,
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
  def handle_call(:last_deploy_timestamps, _from, %{timestamps: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call(:last_deploy_timestamps, _from, %{timestamps: timestamps} = state) do
    {:reply, {:ok, timestamps}, state}
  end

  def handle_call(:status, _from, state) do
    status =
      cond do
        not is_nil(state.update_task) -> :updating
        not is_nil(state.error) -> :error
        not is_nil(state.timestamps) -> :ready
        true -> :unexpected
      end

    {:reply, status, state}
  end

  #################
  # Task completion/failure

  @impl GenServer
  def handle_info({ref, {:update, timestamps}}, %{update_task: %Task{ref: ref}} = state) do
    state = demonitor(state)
    state = %{state | timestamps: timestamps, error: nil}
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
    case @dokku_cli.call("git:report") do
      {:ok, output} ->
        {:update, DokkuRadar.Git.Report.parse(output)}

      {:error, output, exit_code} ->
        Logger.warning("Failed to run git:report", exit_code: exit_code, output: output)
        {:error, {output, exit_code}}
    end
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
