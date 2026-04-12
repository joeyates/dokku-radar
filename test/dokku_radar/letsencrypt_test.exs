defmodule DokkuRadar.LetsencryptTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Letsencrypt

  setup :verify_on_exit!

  @list_output """
  -----> App name           Certificate Expiry        Time before expiry        Time before renewal
  immich                    2026-06-30 11:12:59       78d, 18h, 43m, 23s        48d, 18h, 43m, 23s
  nextcloud                 2026-07-15 09:00:00       93d, 15h, 47m, 1s         63d, 15h, 47m, 1s
  """

  describe "cert_expiry/1" do
    test "returns the expiry datetime for a known app" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "letsencrypt:list" ->
        {:ok, @list_output}
      end)

      assert {:ok, %DateTime{} = expiry} = Letsencrypt.cert_expiry("immich")
      assert expiry.year == 2026
      assert expiry.month == 6
      assert expiry.day == 30
      assert expiry.hour == 11
      assert expiry.minute == 12
      assert expiry.second == 59
    end

    test "returns the correct expiry for a second app in the list" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "letsencrypt:list" ->
        {:ok, @list_output}
      end)

      assert {:ok, %DateTime{} = expiry} = Letsencrypt.cert_expiry("nextcloud")
      assert expiry.year == 2026
      assert expiry.month == 7
      assert expiry.day == 15
      assert expiry.hour == 9
      assert expiry.minute == 0
      assert expiry.second == 0
    end

    test "returns {:error, :no_cert} when app is not in the list" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "letsencrypt:list" ->
        {:ok, @list_output}
      end)

      assert {:error, :no_cert} = Letsencrypt.cert_expiry("unknown-app")
    end

    test "returns {:error, reason} on CLI failure" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "letsencrypt:list" ->
        {:error, "ssh: connect to host bad port 22: Connection refused", 255}
      end)

      assert {:error, _reason} = Letsencrypt.cert_expiry("immich")
    end

    test "header lines are skipped" do
      output = """
      -----> App name           Certificate Expiry        Time before expiry
      myapp                     2025-12-31 23:59:59       10d, 0h, 0m, 0s
      """

      expect(DokkuRadar.DokkuCli.Mock, :call, fn "letsencrypt:list" ->
        {:ok, output}
      end)

      assert {:ok, %DateTime{} = expiry} = Letsencrypt.cert_expiry("myapp")
      assert expiry.year == 2025
      assert expiry.month == 12
      assert expiry.day == 31
    end
  end
end
