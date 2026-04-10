defmodule DokkuRadar.ServiceCache do
  @behaviour DokkuRadar.ServiceCache.Behaviour

  use GenServer

  @default_plugin_refresh_interval :timer.minutes(5)
  @default_service_refresh_interval :timer.seconds(30)

  # Client API

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    gen_server_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_server_opts)
  end

  @impl true
  def get(server \\ __MODULE__) do
    GenServer.call(server, :get, :infinity)
  end

  def refresh(server \\ __MODULE__) do
    GenServer.cast(server, :refresh)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    dokku_cli = Keyword.get(opts, :dokku_cli, DokkuRadar.DokkuCli)

    plugin_refresh_interval =
      Keyword.get(opts, :plugin_refresh_interval, @default_plugin_refresh_interval)

    service_refresh_interval =
      Keyword.get(opts, :service_refresh_interval, @default_service_refresh_interval)

    state = %{
      dokku_cli: dokku_cli,
      plugin_refresh_interval: plugin_refresh_interval,
      service_refresh_interval: service_refresh_interval,
      cache: nil
    }

    state = load(state)

    if plugin_refresh_interval != :infinity do
      Process.send_after(self(), :refresh_plugins, plugin_refresh_interval)
    end

    if service_refresh_interval != :infinity do
      Process.send_after(self(), :refresh_services, service_refresh_interval)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state.cache, state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    {:noreply, load(state)}
  end

  @impl true
  def handle_info(:refresh_plugins, state) do
    state = load(state)

    Process.send_after(self(), :refresh_plugins, state.plugin_refresh_interval)

    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh_services, state) do
    state = refresh_services(state)

    Process.send_after(self(), :refresh_services, state.service_refresh_interval)

    {:noreply, state}
  end

  defp load(state) do
    case state.dokku_cli.list_service_types([]) do
      {:ok, types} ->
        services = fetch_all_services(types, state.dokku_cli)
        %{state | cache: {:ok, services}}

      {:error, reason} ->
        %{state | cache: {:error, reason}}
    end
  end

  defp refresh_services(%{cache: {:ok, _}} = state) do
    case state.dokku_cli.list_service_types([]) do
      {:ok, types} ->
        services = fetch_all_services(types, state.dokku_cli)
        %{state | cache: {:ok, services}}

      {:error, reason} ->
        %{state | cache: {:error, reason}}
    end
  end

  defp refresh_services(state), do: load(state)

  defp fetch_all_services(service_types, dokku_cli) do
    Enum.flat_map(service_types, fn type ->
      case dokku_cli.list_services(type, []) do
        {:ok, services} ->
          Enum.map(services, &Map.put(&1, :service_type, type))

        {:error, _} ->
          []
      end
    end)
  end
end
