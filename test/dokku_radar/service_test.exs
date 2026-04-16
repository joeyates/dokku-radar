defmodule DokkuRadar.Services.ServiceTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Services.Service

  setup :verify_on_exit!

  describe "links/2 for postgres" do
    test "parses a service linked to a single app" do
      expect(DokkuRemote.Commands.Postgres.Mock, :links, fn _host, "my-database" ->
        {:ok, ["my-app"]}
      end)

      assert {:ok, ["my-app"]} = Service.links("postgres", "my-database")
    end

    test "parses a service linked to multiple apps" do
      expect(DokkuRemote.Commands.Postgres.Mock, :links, fn _host, "another-db" ->
        {:ok, ["app1", "app2"]}
      end)

      assert {:ok, ["app1", "app2"]} = Service.links("postgres", "another-db")
    end

    test "returns empty list for a service with no links" do
      expect(DokkuRemote.Commands.Postgres.Mock, :links, fn _host, "orphan-db" ->
        {:ok, []}
      end)

      assert {:ok, []} = Service.links("postgres", "orphan-db")
    end

    test "returns error on non-zero exit code" do
      expect(DokkuRemote.Commands.Postgres.Mock, :links, fn _host, "bad-db" ->
        {:error, "Service bad-db not found", 1}
      end)

      assert {:error, _reason} = Service.links("postgres", "bad-db")
    end
  end

  describe "links/2 for redis" do
    test "returns linked apps" do
      expect(DokkuRemote.Commands.Redis.Mock, :links, fn _host, "my-redis" ->
        {:ok, ["my-app"]}
      end)

      assert {:ok, ["my-app"]} = Service.links("redis", "my-redis")
    end
  end

  describe "links/2 for unknown plugin" do
    test "raises at runtime" do
      assert_raise RuntimeError, ~r/Unknown service plugin/, fn ->
        Service.links("badplugin", "some-db")
      end
    end
  end
end
