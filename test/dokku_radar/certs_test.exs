defmodule DokkuRadar.CertsTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Certs

  setup :verify_on_exit!

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

  describe "list/0" do
    test "returns a map of app names to expiry datetimes" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "certs:report" ->
        {:ok, @certs_report_output}
      end)

      assert {:ok, expiries} = Certs.list()
      assert map_size(expiries) == 2

      assert %DateTime{} = expiries["blog-cms"]
      assert expiries["blog-cms"].year == 2026
      assert expiries["blog-cms"].month == 7
      assert expiries["blog-cms"].day == 1
      assert expiries["blog-cms"].hour == 8
      assert expiries["blog-cms"].minute == 39
      assert expiries["blog-cms"].second == 8

      assert %DateTime{} = expiries["nextcloud"]
      assert expiries["nextcloud"].year == 2025
      assert expiries["nextcloud"].month == 12
      assert expiries["nextcloud"].day == 31
      assert expiries["nextcloud"].hour == 23
      assert expiries["nextcloud"].minute == 59
      assert expiries["nextcloud"].second == 59
    end

    test "omits apps without an SSL cert" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "certs:report" ->
        {:ok, @certs_report_output}
      end)

      assert {:ok, expiries} = Certs.list()
      refute Map.has_key?(expiries, "no-cert-app")
    end

    test "returns {:error, reason} on CLI failure" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "certs:report" ->
        {:error, "ssh: connect to host bad port 22: Connection refused", 255}
      end)

      assert {:error, _reason} = Certs.list()
    end

    test "handles single-digit day with leading space" do
      output = """
      =====> my-app ssl information
             Ssl expires at:                Jan  5 10:00:00 2027 GMT
      """

      expect(DokkuRadar.DokkuCli.Mock, :call, fn "certs:report" ->
        {:ok, output}
      end)

      assert {:ok, %{"my-app" => expiry}} = Certs.list()
      assert expiry.day == 5
      assert expiry.month == 1
      assert expiry.year == 2027
    end
  end
end
