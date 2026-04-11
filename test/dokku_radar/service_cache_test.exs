defmodule DokkuRadar.ServiceCacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.ServiceCache

  setup :set_mox_global
  setup :verify_on_exit!

  @services %{
    "postgres" => %{
      "my-db" => %{name: "my-db", status: "running", links: ["my-app"]},
      "other-db" => %{name: "other-db", status: "stopped", links: []}
    },
    "redis" => %{
      "my-cache" => %{name: "my-cache", status: "running", links: ["my-app"]}
    }
  }

  @base_opts [
    name: nil,
    refresh_interval: nil
  ]

  defp wait_for_status(pid, status) do
    case ServiceCache.status(pid) do
      ^status ->
        :ok

      _other ->
        wait_for_status(pid, status)
    end
  end

  setup context do
    service_plugins_list_response =
      context[:service_plugins_list_response] || {:ok, Map.keys(@services)}

    expect(DokkuRadar.ServicePlugins.Mock, :list, fn ->
      service_plugins_list_response
    end)

    service_plugin_services_calls =
      context[:service_plugin_services_calls] || @services |> Map.keys() |> length()

    expect(DokkuRadar.ServicePlugin.Mock, :services, service_plugin_services_calls, fn plugin ->
      {:ok, Map.keys(@services[plugin])}
    end)

    service_links_calls = context[:service_links_calls] || 3

    expect(
      DokkuRadar.Service.Mock,
      :links,
      service_links_calls,
      fn plugin, service ->
        {:ok, @services[plugin][service].links}
      end
    )

    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    pid = start_supervised!({ServiceCache, @base_opts})

    %{pid: pid}
  end

  describe "service_links/0" do
    test "returns cached services after init", %{pid: pid} do
      :ok = wait_for_status(pid, :ready)

      assert {:ok, services} = ServiceCache.service_links(pid)
      assert length(services) == 3
    end

    test "includes service_type in each service", %{pid: pid} do
      :ok = wait_for_status(pid, :ready)

      assert {:ok, services} = ServiceCache.service_links(pid)

      service = hd(services)

      assert service.type == "postgres"
      assert service.name == "my-db"
    end

    @tag service_plugins_list_response: {:ok, []}
    @tag service_plugin_services_calls: 0
    @tag service_links_calls: 0
    test "returns empty list when no plugins are found", %{pid: pid} do
      :ok = wait_for_status(pid, :ready)

      assert {:ok, []} = ServiceCache.service_links(pid)
    end

    @tag service_plugins_list_response: {:error, :foo}
    @tag service_plugin_services_calls: 0
    @tag service_links_calls: 0
    test "returns error when pluging listing fails", %{pid: pid} do
      :ok = wait_for_status(pid, :error)

      assert {:error, :no_data} = ServiceCache.service_links(pid)
    end
  end

  describe "refresh/1" do
    test "updates cached services when called", %{pid: pid} do
      :ok = wait_for_status(pid, :ready)

      {:ok, initial} = ServiceCache.service_links(pid)
      assert Enum.any?(initial, &(&1.name == "my-db"))

      expect(DokkuRadar.ServicePlugins.Mock, :list, fn ->
        {:ok, Map.keys(@services)}
      end)

      expect(DokkuRadar.ServicePlugin.Mock, :services, 2, fn plugin ->
        {:ok, Map.keys(@services[plugin])}
      end)

      updated_services = put_in(@services, ["postgres", "my-db", :links], ["other-app"])

      expect(
        DokkuRadar.Service.Mock,
        :links,
        3,
        fn plugin, service ->
          {:ok, updated_services[plugin][service].links}
        end
      )

      ServiceCache.refresh(pid)
      :ok = wait_for_status(pid, :ready)

      {:ok, updated} = ServiceCache.service_links(pid)
      my_db = Enum.find(updated, &(&1.name == "my-db"))
      assert my_db.links == ["other-app"]
    end
  end
end
