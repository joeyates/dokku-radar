defmodule DokkuRadar.ServicesTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Services

  setup :verify_on_exit!

  describe "service_links/0" do
    test "delegates to Services.Cache" do
      expect(DokkuRadar.Services.Cache.Mock, :service_links, fn ->
        {:ok, [%DokkuRadar.Services.Cache{type: "postgres", name: "my-db", links: ["my-app"]}]}
      end)

      assert {:ok, [%DokkuRadar.Services.Cache{name: "my-db"}]} = Services.service_links()
    end
  end
end
