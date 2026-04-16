defmodule DokkuRadar.Services.ServicePluginTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Services.ServicePlugin

  setup :verify_on_exit!

  describe "services/1 for postgres" do
    test "returns service names" do
      expect(DokkuRemote.Commands.Postgres.Mock, :list, fn _host ->
        {:ok, ["my-database", "another-db", "orphan-db"]}
      end)

      assert {:ok, services} = ServicePlugin.services("postgres")

      assert length(services) == 3
      assert "my-database" in services
      assert "another-db" in services
      assert "orphan-db" in services
    end

    test "returns error on non-zero exit code" do
      expect(DokkuRemote.Commands.Postgres.Mock, :list, fn _host ->
        {:error, "Connection refused", 255}
      end)

      assert {:error, _exit_code, _reason} = ServicePlugin.services("postgres")
    end
  end

  describe "services/1 for redis" do
    test "returns service names" do
      expect(DokkuRemote.Commands.Redis.Mock, :list, fn _host ->
        {:ok, ["my-redis", "cache"]}
      end)

      assert {:ok, services} = ServicePlugin.services("redis")

      assert length(services) == 2
      assert "my-redis" in services
    end
  end

  describe "services/1 for unknown plugin" do
    test "raises at runtime" do
      assert_raise RuntimeError, ~r/Unknown service plugin/, fn ->
        ServicePlugin.services("badtype")
      end
    end
  end
end
