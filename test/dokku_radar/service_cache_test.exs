defmodule DokkuRadar.ServiceCacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.ServiceCache

  setup :set_mox_global
  setup :verify_on_exit!

  @services_by_type %{
    "postgres" => [
      %{name: "my-db", status: "running", links: ["my-app"]},
      %{name: "other-db", status: "stopped", links: []}
    ],
    "redis" => [
      %{name: "my-cache", status: "running", links: ["my-app"]}
    ]
  }

  @base_opts [
    name: nil,
    plugin_refresh_interval: :infinity,
    service_refresh_interval: :infinity
  ]

  describe "get/1" do
    test "returns cached services after init" do
      DokkuRadar.DokkuCli.Mock
      |> expect(:list_service_types, fn _opts -> {:ok, ["postgres", "redis"]} end)
      |> expect(:list_services, fn "postgres", _opts ->
        {:ok, @services_by_type["postgres"]}
      end)
      |> expect(:list_services, fn "redis", _opts ->
        {:ok, @services_by_type["redis"]}
      end)

      pid =
        start_supervised!(
          {ServiceCache, [{:dokku_cli, DokkuRadar.DokkuCli.Mock} | @base_opts]}
        )

      assert {:ok, services} = ServiceCache.get(pid)
      assert length(services) == 3
    end

    test "includes service_type in each service" do
      DokkuRadar.DokkuCli.Mock
      |> expect(:list_service_types, fn _opts -> {:ok, ["postgres"]} end)
      |> expect(:list_services, fn "postgres", _opts ->
        {:ok, [%{name: "my-db", status: "running", links: ["my-app"]}]}
      end)

      pid =
        start_supervised!(
          {ServiceCache, [{:dokku_cli, DokkuRadar.DokkuCli.Mock} | @base_opts]}
        )

      assert {:ok, [service]} = ServiceCache.get(pid)

      assert service.service_type == "postgres"
      assert service.name == "my-db"
    end

    test "returns empty list when no service types are found" do
      DokkuRadar.DokkuCli.Mock
      |> expect(:list_service_types, fn _opts -> {:ok, []} end)

      pid =
        start_supervised!(
          {ServiceCache, [{:dokku_cli, DokkuRadar.DokkuCli.Mock} | @base_opts]}
        )

      assert {:ok, []} = ServiceCache.get(pid)
    end

    test "returns error when CLI fails to list service types" do
      DokkuRadar.DokkuCli.Mock
      |> expect(:list_service_types, fn _opts -> {:error, {255, "Connection refused"}} end)

      pid =
        start_supervised!(
          {ServiceCache, [{:dokku_cli, DokkuRadar.DokkuCli.Mock} | @base_opts]}
        )

      assert {:error, _reason} = ServiceCache.get(pid)
    end
  end

  describe "refresh/1" do
    test "updates cached services when called" do
      DokkuRadar.DokkuCli.Mock
      |> expect(:list_service_types, 2, fn _opts -> {:ok, ["redis"]} end)
      |> expect(:list_services, fn "redis", _opts ->
        {:ok, [%{name: "cache-v1", status: "running", links: []}]}
      end)
      |> expect(:list_services, fn "redis", _opts ->
        {:ok, [%{name: "cache-v2", status: "running", links: []}]}
      end)

      pid =
        start_supervised!(
          {ServiceCache, [{:dokku_cli, DokkuRadar.DokkuCli.Mock} | @base_opts]}
        )

      {:ok, initial} = ServiceCache.get(pid)
      assert Enum.any?(initial, &(&1.name == "cache-v1"))

      ServiceCache.refresh(pid)

      {:ok, updated} = ServiceCache.get(pid)
      assert Enum.any?(updated, &(&1.name == "cache-v2"))
    end
  end
end
