defmodule DokkuRadar.CertsTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Certs

  setup :verify_on_exit!

  describe "list/0" do
    test "delegates to Certs.Cache" do
      expect(DokkuRadar.Certs.Cache.Mock, :list, fn ->
        {:ok, %{"my-app" => ~U[2026-07-01 08:39:08Z]}}
      end)

      assert {:ok, %{"my-app" => %DateTime{}}} = Certs.list()
    end
  end
end
