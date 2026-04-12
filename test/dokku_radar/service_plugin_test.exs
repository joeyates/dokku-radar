defmodule DokkuRadar.ServicePluginTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.ServicePlugin

  setup :verify_on_exit!

  @postgres_list_output """
  =====> Postgres services
  my-database
  another-db
  orphan-db
  """

  describe "services/1" do
    test "returns service names" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "postgres:list" ->
        {:ok, @postgres_list_output}
      end)

      assert {:ok, services} = ServicePlugin.services("postgres")

      assert length(services) == 3
      assert "my-database" in services
      assert "another-db" in services
      assert "orphan-db" in services
    end

    test "ignores the header line" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "postgres:list" ->
        {:ok, @postgres_list_output}
      end)

      assert {:ok, services} = ServicePlugin.services("postgres")

      refute Enum.any?(services, &String.starts_with?(&1, "====="))
    end

    test "returns error on non-zero exit code" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "badtype:list" ->
        {:error, "Unknown service type: badtype", 1}
      end)

      assert {:error, _exit_code, _reason} = ServicePlugin.services("badtype")
    end
  end
end
