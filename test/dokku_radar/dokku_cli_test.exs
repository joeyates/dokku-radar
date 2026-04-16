defmodule DokkuRadar.DokkuCliTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.DokkuCli

  setup :verify_on_exit!

  @dokku_host "myhost.example.com"
  @ssh_certificate_path "/tmp/test_key"

  setup do
    original = Application.get_env(:dokku_radar, DokkuRadar.DokkuCli)

    Application.put_env(:dokku_radar, DokkuRadar.DokkuCli,
      dokku_host: @dokku_host,
      ssh_certificate_path: @ssh_certificate_path
    )

    on_exit(fn ->
      case original do
        nil -> Application.delete_env(:dokku_radar, DokkuRadar.DokkuCli)
        config -> Application.put_env(:dokku_radar, DokkuRadar.DokkuCli, config)
      end
    end)

    :ok
  end

  describe "call/1" do
    test "returns {:ok, output} on exit code 0" do
      expect(System.Mock, :cmd, fn "ssh", _args, _opts -> {"plugin output", 0} end)

      assert {:ok, "plugin output"} = DokkuCli.call("plugin:list")
    end

    test "returns {:error, output, exit_code} on non-zero exit" do
      expect(System.Mock, :cmd, fn "ssh", _args, _opts ->
        {"ssh: connect to host bad port 22: Connection refused", 255}
      end)

      assert {:error, _output, 255} = DokkuCli.call("plugin:list")
    end

    test "includes the configured SSH host in arguments" do
      expect(System.Mock, :cmd, fn "ssh", args, _opts ->
        assert "dokku@#{@dokku_host}" in args
        {"", 0}
      end)

      DokkuCli.call("plugin:list")
    end

    test "includes the configured SSH certificate path in arguments" do
      expect(System.Mock, :cmd, fn "ssh", args, _opts ->
        assert @ssh_certificate_path in args
        {"", 0}
      end)

      DokkuCli.call("plugin:list")
    end
  end

  describe "call/2" do
    test "appends extra args to the SSH command" do
      expect(System.Mock, :cmd, fn "ssh", args, _opts ->
        assert "my-database" in args
        {"link output", 0}
      end)

      assert {:ok, "link output"} = DokkuCli.call("postgres:links", ["my-database"])
    end
  end
end
