defmodule DokkuRadar.Certs.ReportTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.Certs.Report

  @certs_report_output """
  =====> blog-cms ssl information
         Ssl expires at:                Jul  1 08:39:08 2026 GMT
         Ssl enabled:                   true
  =====> nextcloud ssl information
         Ssl expires at:                Dec 31 23:59:59 2025 GMT
         Ssl enabled:                   true
  =====> no-cert-app ps information
         Ssl enabled:                   false
  """

  describe "parse/1" do
    test "returns a map of app names to expiry datetimes" do
      result = Report.parse(@certs_report_output)

      assert map_size(result) == 2

      assert %DateTime{} = result["blog-cms"]
      assert result["blog-cms"].year == 2026
      assert result["blog-cms"].month == 7
      assert result["blog-cms"].day == 1
      assert result["blog-cms"].hour == 8
      assert result["blog-cms"].minute == 39
      assert result["blog-cms"].second == 8

      assert %DateTime{} = result["nextcloud"]
      assert result["nextcloud"].year == 2025
      assert result["nextcloud"].month == 12
      assert result["nextcloud"].day == 31
    end

    test "omits apps without an SSL expiry line" do
      result = Report.parse(@certs_report_output)
      refute Map.has_key?(result, "no-cert-app")
    end

    test "returns an empty map for empty output" do
      assert Report.parse("") == %{}
    end

    test "handles single-digit day with leading space" do
      output = """
      =====> my-app ssl information
             Ssl expires at:                Jan  5 10:00:00 2027 GMT
      """

      result = Report.parse(output)
      assert result["my-app"].day == 5
      assert result["my-app"].month == 1
      assert result["my-app"].year == 2027
    end
  end
end
