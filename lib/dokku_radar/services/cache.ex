defmodule DokkuRadar.Services.Cache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)

  alias DokkuRadar.Services.Service

  require Logger

  @service_plugins Application.compile_env(
                     :dokku_radar,
                     :"DokkuRadar.Services.ServicePlugins",
                     DokkuRadar.Services.ServicePlugins
                   )
  @service_plugin Application.compile_env(
                    :dokku_radar,
                    :"DokkuRadar.Services.ServicePlugin",
                    DokkuRadar.Services.ServicePlugin
                  )
  @service Application.compile_env(
             :dokku_radar,
             :"DokkuRadar.Services.Service",
             DokkuRadar.Services.Service
           )

  #################
  # Client API

  @callback service_links() :: {:ok, [map()]} | {:error, term()}

  def service_links(server \\ __MODULE__) do
    GenServer.call(server, :service_links)
  end

  #################
  # Handle Client Calls

  @impl GenServer
  def handle_call(:service_links, _from, %{data: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call(:service_links, _from, %{data: %{service_links: service_links}} = state) do
    {:reply, {:ok, service_links}, state}
  end

  def handle_call(msg, from, state), do: super(msg, from, state)

  #################
  # Load

  @impl DokkuRadar.DokkuCli.Cache
  def load() do
    with {:ok, plugins} <- load_plugins(),
         {:ok, services} <- load_services(plugins),
         {:ok, service_links} <- load_service_links(services) do
      {:update, %{plugins: plugins, services: services, service_links: service_links}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  #################
  # Load Info from Dokku

  defp load_plugins(), do: @service_plugins.list()

  defp load_services(plugins) do
    services =
      Enum.reduce(plugins, %{}, fn plugin, acc ->
        case @service_plugin.services(plugin) do
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
          case @service.links(plugin, plugin_service) do
            {:ok, links} ->
              %Service{type: plugin, name: plugin_service, links: links}
          end
        end)
      end)

    {:ok, service_links}
  end
end
