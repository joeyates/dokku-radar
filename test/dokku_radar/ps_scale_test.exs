defmodule DokkuRadar.PsScaleTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.PsScale

  setup :verify_on_exit!

  @ps_scale_output """
  -----> Scaling for blog-cms
  proctype: qty
  --------: ---
  release: 0
  web:  1
  """

  @multi_process_output """
  -----> Scaling for my-app
  proctype: qty
  --------: ---
  release: 0
  web:  2
  worker:  1
  """

  describe "scale/1" do
    test "returns a map of process type to count" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "ps:scale", ["blog-cms"] ->
        {:ok, @ps_scale_output}
      end)

      assert {:ok, scale} = PsScale.scale("blog-cms")
      assert scale["web"] == 1
      assert scale["release"] == 0
    end

    test "parses multiple process types" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "ps:scale", ["my-app"] ->
        {:ok, @multi_process_output}
      end)

      assert {:ok, scale} = PsScale.scale("my-app")
      assert map_size(scale) == 3
      assert scale["web"] == 2
      assert scale["worker"] == 1
      assert scale["release"] == 0
    end

    test "skips header lines starting with ----" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "ps:scale", ["blog-cms"] ->
        {:ok, @ps_scale_output}
      end)

      assert {:ok, scale} = PsScale.scale("blog-cms")
      refute Map.has_key?(scale, "------")
    end

    test "skips proctype header line" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "ps:scale", ["blog-cms"] ->
        {:ok, @ps_scale_output}
      end)

      assert {:ok, scale} = PsScale.scale("blog-cms")
      refute Map.has_key?(scale, "proctype")
    end

    test "returns {:error, reason} on CLI failure" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "ps:scale", ["blog-cms"] ->
        {:error, "ssh: connect to host bad port 22: Connection refused", 255}
      end)

      assert {:error, _reason} = PsScale.scale("blog-cms")
    end
  end
end
