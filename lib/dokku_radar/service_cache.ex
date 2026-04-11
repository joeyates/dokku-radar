defmodule DokkuRadar.ServiceCache do
  # @behaviour DokkuRadar.ServiceCache.Behaviour

  use GenServer

  alias DokkuRadar.Service
  alias DokkuRadar.ServicePlugin
  alias DokkuRadar.ServicePlugins

  require Logger

  # TODO: set to 10'
  @default_refresh_interval :timer.minutes(1)

  #################
  # Client API

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    gen_server_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_server_opts)
  end

  def service_links(server \\ __MODULE__) do
    GenServer.call(server, :service_links)
  end

  def refresh(server \\ __MODULE__) do
    GenServer.cast(server, :refresh)
  end

  #################
  # Setup

  @impl true
  def init(opts) do
    refresh_interval = Keyword.get(opts, :refresh_interval, @default_refresh_interval)

    state = %{
      refresh_interval: refresh_interval,
      update_task: nil,
      plugins: nil,
      services: nil,
      service_links: nil
    }

    {:ok, state, {:continue, :load}}
  end

  @impl true
  def handle_continue(:load, %{update_task: nil} = state) do
    state = initiate_load(state)

    {:noreply, state}
  end

  #################
  # Handle Client Calls

  @impl true
  def handle_call(:service_links, _from, %{service_links: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call(:service_links, _from, %{service_links: service_links} = state) do
    {:reply, {:ok, service_links}, state}
  end

  @impl true
  def handle_cast(:refresh, %{update_task: nil} = state) do
    Logger.debug("#{__MODULE__}.handle_cast(:refresh, state)")
    state = initiate_load(state)

    {:noreply, state}
  end

  def handle_cast(:refresh, %{update_task: _ref} = state) do
    Logger.warning(
      "#{__MODULE__}.handle_cast(:refresh, state) received when load is running - ignoring"
    )

    {:noreply, state}
  end

  # Initiate Timed Updates

  @impl true
  def handle_info(:refresh, %{update_task: nil} = state) do
    Logger.debug("#{__MODULE__}.handle_info(:refresh, state)")
    state = initiate_load(state)

    {:noreply, state}
  end

  def handle_info(:refresh, %{update_task: %Task{} = task} = state) do
    Logger.warning(
      "#{__MODULE__}.handle_info(:refresh, state) received when load is running - restarting"
    )

    Task.shutdown(task, :brutal_kill)

    state
    |> demonitor()
    |> maybe_enqueue_refresh()
  end

  #################
  # Task completion/failure

  def handle_info(
        {ref, {:update, plugins, services, service_links}},
        %{update_task: %Task{ref: ref}} = state
      ) do
    Logger.debug("#{__MODULE__}.handle_info({..., {:update, ...}})")
    Logger.info("plugins: #{inspect(plugins)}")
    Logger.info("services: #{inspect(services)}")
    Logger.info("service_links: #{inspect(service_links)}")

    state = demonitor(state)
    state = %{state | plugins: plugins, services: services, service_links: service_links}

    {:noreply, state}
  end

  def handle_info({ref, {:error, reason}}, %{update_task: %Task{ref: ref}} = state) do
    Logger.error("#{__MODULE__}.handle_info({..., {:error, #{inspect(reason)}}})")

    state =
      state
      |> demonitor()
      |> maybe_enqueue_refresh()

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{update_task: %Task{ref: ref}} = state) do
    Logger.error("#{__MODULE__} load plugins task failed: #{inspect(reason)}")
    maybe_enqueue_refresh(state)

    {:noreply, %{state | update_task: nil}}
  end

  #################
  # Update plugins, services and services list

  defp initiate_load(state) do
    Logger.info("Initiating load")

    task =
      Task.Supervisor.async_nolink(
        DokkuRadar.TaskSupervisor,
        fn -> load() end
      )

    Map.put(state, :update_task, task)
  end

  defp load() do
    with {:ok, plugins} <- load_plugins(),
         {:ok, services} <- load_services(plugins),
         {:ok, service_links} <- load_service_links(services) do
      {:update, plugins, services, service_links}
    else
      {:error, reason} ->
        {:failed, {:error, reason}}
    end
  end

  #################
  # Load Info from Dokku

  defp load_plugins(), do: ServicePlugins.list()

  defp load_services(plugins) do
    services =
      Enum.reduce(plugins, %{}, fn plugin, acc ->
        case ServicePlugin.services(plugin) do
          {:ok, services} ->
            Map.put(acc, plugin, services)
        end
      end)

    {:ok, services}
  end

  defp load_service_links(services) do
    service_links =
      Enum.flat_map(services, fn {plugin, plugin_services} ->
        Enum.map(plugin_services, fn plugin_service ->
          case Service.links(plugin, plugin_service) do
            {:ok, links} ->
              %{plugin: plugin, service: plugin_service, links: links}
          end
        end)
      end)

    {:ok, service_links}
  end

  defp maybe_enqueue_refresh(%{refresh_interval: nil}), do: :ok

  defp maybe_enqueue_refresh(%{refresh_interval: interval, update_task: nil}) do
    Logger.debug("Enqueuing refresh in #{interval}ms")
    Process.send_after(self(), :refresh, interval)
  end

  defp maybe_enqueue_refresh(_state), do: :ok

  defp demonitor(%{update_task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])

    %{state | update_task: nil}
  end
end
