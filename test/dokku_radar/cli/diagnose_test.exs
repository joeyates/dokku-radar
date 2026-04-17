defmodule DokkuRadar.CLI.DiagnoseTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mox

  alias DokkuRadar.CLI.Diagnose
  alias DokkuRemote.App

  @dokku_host "test.example.com"
  @dokku_app "dokku-radar"
  @app %App{dokku_host: @dokku_host, dokku_app: @dokku_app}

  setup :verify_on_exit!

  describe "run/1" do
    test "prints a passing line when all web processes are running" do
      expect(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:ok,
         [
           %{
             app: "dokku-radar",
             process_type: "web",
             process_index: 1,
             state: "running",
             cid: "abc"
           }
         ]}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "✅"
      assert output =~ "App running"
    end

    test "prints a failing line when a web process is not running" do
      expect(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:ok,
         [
           %{
             app: "dokku-radar",
             process_type: "web",
             process_index: 1,
             state: "exited",
             cid: "abc"
           }
         ]}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "App running"
    end

    test "prints a failing line when ps report fails" do
      expect(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:error, "ssh: Connection refused", 255}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "App running"
    end
  end
end
