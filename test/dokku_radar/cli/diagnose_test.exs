defmodule DokkuRadar.CLI.DiagnoseTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.CLI.Diagnose
  alias DokkuRemote.App

  @dokku_host "test.example.com"
  @dokku_app "dokku-radar"
  @private_key "/tmp/id_rsa"

  @app %App{dokku_host: @dokku_host, dokku_app: @dokku_app}

  describe "run/2" do
    test "returns :ok" do
      assert :ok = Diagnose.run(@app, @private_key)
    end
  end
end
