defmodule DokkuRadar.Services.ServiceTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Services.Service

  setup :verify_on_exit!

  describe "links/2" do
    test "parses a service linked to a single app" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "postgres:links", ["my-database"] ->
        {:ok, "my-app\n"}
      end)

      assert {:ok, ["my-app"]} = Service.links("postgres", "my-database")
    end

    test "parses a service linked to multiple apps" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "postgres:links", ["another-db"] ->
        {:ok, "app1\napp2\n"}
      end)

      assert {:ok, ["app1", "app2"]} = Service.links("postgres", "another-db")
    end

    test "returns empty list for a service with no links" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "postgres:links", ["orphan-db"] ->
        {:ok, ""}
      end)

      assert {:ok, []} = Service.links("postgres", "orphan-db")
    end

    test "returns error on non-zero exit code" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "postgres:links", ["bad-db"] ->
        {:error, "Service bad-db not found", 1}
      end)

      assert {:error, _reason} = Service.links("postgres", "bad-db")
    end
  end
end
