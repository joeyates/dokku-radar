defmodule DokkuRadar.Services.ServicePluginsTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Services.ServicePlugins

  setup :verify_on_exit!

  defp entry(name) do
    %DokkuRemote.Commands.Plugin.Entry{
      name: name,
      version: "#{name}:latest",
      enabled: true,
      description: "#{name} plugin"
    }
  end

  defp plugin_entries() do
    [
      entry("access"),
      entry("letsencrypt"),
      entry("postgres"),
      entry("redis"),
      entry("scheduler-simple")
    ]
  end

  describe "list/0" do
    test "returns known service types found in plugin list" do
      expect(DokkuRemote.Commands.Plugin.Mock, :list, fn _host -> {:ok, plugin_entries()} end)

      assert {:ok, types} = ServicePlugins.list()

      assert "postgres" in types
      assert "redis" in types
    end

    test "ignores non-service plugins" do
      expect(DokkuRemote.Commands.Plugin.Mock, :list, fn _host -> {:ok, plugin_entries()} end)

      assert {:ok, types} = ServicePlugins.list()

      refute "access" in types
      refute "letsencrypt" in types
      refute "scheduler-simple" in types
    end

    test "returns error on non-zero exit code" do
      expect(DokkuRemote.Commands.Plugin.Mock, :list, fn _host ->
        {:error, "ssh: connect to host bad port 22: Connection refused", 255}
      end)

      assert {:error, _exit_code, _reason} = ServicePlugins.list()
    end
  end
end
