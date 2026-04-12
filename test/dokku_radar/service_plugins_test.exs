defmodule DokkuRadar.ServicePluginsTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.ServicePlugins

  setup :verify_on_exit!

  @plugin_list_output """
  =====> Installed plugins
    access          deployed access:
    letsencrypt     deployed letsencrypt:latest
    postgres        deployed postgres:latest
    redis           deployed redis:latest
    scheduler-simple deployed scheduler-simple:latest
  """

  describe "list/0" do
    test "returns known service types found in plugin list" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "plugin:list" -> {:ok, @plugin_list_output} end)

      assert {:ok, types} = ServicePlugins.list()

      assert "postgres" in types
      assert "redis" in types
    end

    test "ignores non-service plugins" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "plugin:list" -> {:ok, @plugin_list_output} end)

      assert {:ok, types} = ServicePlugins.list()

      refute "access" in types
      refute "letsencrypt" in types
      refute "scheduler-simple" in types
    end

    test "returns error on non-zero exit code" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "plugin:list" ->
        {:error, "ssh: connect to host bad port 22: Connection refused", 255}
      end)

      assert {:error, _exit_code, _reason} = ServicePlugins.list()
    end
  end
end
