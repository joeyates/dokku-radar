defmodule DokkuRadar.Ps.ScaleTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.Ps.Scale

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

  describe "parse/1" do
    test "returns a map of process type to count" do
      result = Scale.parse(@ps_scale_output)
      assert result["web"] == 1
      assert result["release"] == 0
    end

    test "parses multiple process types" do
      result = Scale.parse(@multi_process_output)
      assert map_size(result) == 3
      assert result["web"] == 2
      assert result["worker"] == 1
      assert result["release"] == 0
    end

    test "skips header lines starting with ----" do
      result = Scale.parse(@ps_scale_output)
      refute Map.has_key?(result, "------")
    end

    test "skips proctype header line" do
      result = Scale.parse(@ps_scale_output)
      refute Map.has_key?(result, "proctype")
    end
  end
end
