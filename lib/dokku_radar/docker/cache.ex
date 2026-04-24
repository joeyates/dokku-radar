defmodule DokkuRadar.Docker.Cache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(5)

  require Logger

  @docker_client Application.compile_env(
                   :dokku_radar,
                   :"DokkuRadar.Docker.Client",
                   DokkuRadar.Docker.Client
                 )

  #################
  # Client API

  @callback container_stats(String.t()) :: {:ok, map()} | {:error, term()}
  @callback container_inspect(String.t()) :: {:ok, map()} | {:error, term()}

  def container_stats(id, server \\ __MODULE__) do
    GenServer.call(server, {:container_stats, id})
  end

  def container_inspect(id, server \\ __MODULE__) do
    GenServer.call(server, {:container_inspect, id})
  end

  #################
  # Handle Client Calls

  @impl GenServer
  def handle_call({:container_stats, _id}, _from, %{data: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call({:container_stats, id}, _from, %{data: %{stats: stats}} = state) do
    {:reply, Map.get(stats, id, {:error, :not_found}), state}
  end

  def handle_call({:container_inspect, _id}, _from, %{data: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call({:container_inspect, id}, _from, %{data: %{inspects: inspects}} = state) do
    {:reply, Map.get(inspects, id, {:error, :not_found}), state}
  end

  def handle_call(msg, from, state), do: super(msg, from, state)

  #################
  # Load

  @impl DokkuRadar.DokkuCli.Cache
  def load() do
    with {:ok, containers} <- @docker_client.list_containers() do
      stats =
        Map.new(containers, fn container ->
          id = container["Id"]
          {id, @docker_client.container_stats(id)}
        end)

      inspects =
        Map.new(containers, fn container ->
          id = container["Id"]
          {id, @docker_client.container_inspect(id)}
        end)

      {:update, %{stats: stats, inspects: inspects}}
    else
      {:error, reason} ->
        Logger.warning("Docker.Cache failed to load containers", reason: inspect(reason))
        {:error, reason}
    end
  end
end
