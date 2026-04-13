defmodule DokkuRadar.GitTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Git

  setup :verify_on_exit!

  describe "last_deploy_timestamps/0" do
    test "delegates to Git.Cache" do
      expect(DokkuRadar.Git.Cache.Mock, :last_deploy_timestamps, fn ->
        {:ok, %{"my-app" => 1_775_125_215}}
      end)

      assert {:ok, %{"my-app" => 1_775_125_215}} = Git.last_deploy_timestamps()
    end
  end
end
