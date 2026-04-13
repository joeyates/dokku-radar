defmodule DokkuRadar.Certs.CacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.Certs.Cache

  setup :set_mox_global
  setup :verify_on_exit!

  @certs_report_output """
  =====> blog-cms ssl information
         Ssl expires at:                Jul  1 08:39:08 2026 GMT
         Ssl enabled:                   true
  =====> nextcloud ssl information
         Ssl expires at:                Dec 31 23:59:59 2025 GMT
         Ssl enabled:                   true
  """

  @base_opts [name: nil, refresh_interval: nil]

  defp wait_for_ready(pid) do
    case Cache.status(pid) do
      :ready -> :ok
      _other -> wait_for_ready(pid)
    end
  end

  setup do
    expect(DokkuRadar.DokkuCli.Mock, :call, fn "certs:report" ->
      {:ok, @certs_report_output}
    end)

    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    pid = start_supervised!({Cache, @base_opts})
    %{pid: pid}
  end

  describe "list/0" do
    test "returns cached expiries after init", %{pid: pid} do
      :ok = wait_for_ready(pid)

      assert {:ok, expiries} = Cache.list(pid)
      assert map_size(expiries) == 2
      assert %DateTime{} = expiries["blog-cms"]
      assert expiries["blog-cms"].year == 2026
    end
  end

  describe "status/1" do
    test "returns :ready after data is loaded", %{pid: pid} do
      :ok = wait_for_ready(pid)
      assert Cache.status(pid) == :ready
    end
  end

  describe "when DokkuCli fails" do
    setup do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "certs:report" ->
        {:error, "ssh: Connection refused", 255}
      end)

      pid = start_supervised!({Cache, [name: nil, refresh_interval: nil]}, id: :fail_cache)
      %{fail_pid: pid}
    end

    test "status is :error after failed load", %{fail_pid: pid} do
      Process.sleep(50)
      assert Cache.status(pid) == :error
    end

    test "returns {:error, :no_data} when no data loaded", %{fail_pid: pid} do
      Process.sleep(50)
      assert {:error, :no_data} = Cache.list(pid)
    end
  end
end
