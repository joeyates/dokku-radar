defmodule DokkuRadar.Certs.CacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.Certs.Cache

  setup :set_mox_global
  setup :verify_on_exit!

  defp cert_report(app_name, expires_at) do
    %DokkuRemote.Commands.Certs.Report{
      app_name: app_name,
      dir: "/home/dokku/#{app_name}/tls",
      enabled: true,
      hostnames: "#{app_name}.example.com",
      expires_at: expires_at,
      issuer: "Let's Encrypt",
      starts_at: "Jan  1 00:00:00 2025 GMT",
      subject: "/CN=#{app_name}.example.com",
      verified: "true"
    }
  end

  @base_opts [name: nil, refresh_interval: nil]

  defp wait_for_ready(pid) do
    case Cache.status(pid) do
      :ready -> :ok
      _other -> wait_for_ready(pid)
    end
  end

  setup do
    reports = %{
      "blog-cms" => cert_report("blog-cms", "Jul  1 08:39:08 2026 GMT"),
      "nextcloud" => cert_report("nextcloud", "Dec 31 23:59:59 2025 GMT")
    }

    expect(DokkuRemote.Commands.Certs.Mock, :report, fn _host ->
      {:ok, reports}
    end)

    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    pid = start_supervised!({Cache, @base_opts})
    wait_for_ready(pid)
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

  describe "when DokkuRemote.Commands.Certs fails" do
    setup do
      expect(DokkuRemote.Commands.Certs.Mock, :report, fn _host ->
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
