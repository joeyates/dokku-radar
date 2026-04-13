defmodule DokkuRadar.PsTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Ps

  setup :verify_on_exit!

  describe "list/0" do
    test "delegates to Ps.Cache" do
      entry = %{
        app: "my-app",
        process_type: "web",
        process_index: 1,
        state: "running",
        cid: "abc123"
      }

      expect(DokkuRadar.Ps.Cache.Mock, :list, fn ->
        {:ok, [entry]}
      end)

      assert {:ok, [^entry]} = Ps.list()
    end
  end

  describe "scale/1" do
    test "delegates to Ps.Cache" do
      expect(DokkuRadar.Ps.Cache.Mock, :scale, fn "my-app" ->
        {:ok, %{"web" => 2}}
      end)

      assert {:ok, %{"web" => 2}} = Ps.scale("my-app")
    end
  end
end
