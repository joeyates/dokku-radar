defmodule DokkuRadar.Ps.CacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.Ps.Cache

  setup :set_mox_global
  setup :verify_on_exit!

  @ps_report_output """
  =====> blog-cms ps information
         Status web 1:                  running (CID: 37d851b84ba)
  =====> my-api ps information
         Status web 1:                  running (CID: 4a2b9c0d1e2)
  """

  @blog_cms_scale_output """
  -----> Scaling for blog-cms
  proctype: qty
  --------: ---
  web:  1
  """

  @my_api_scale_output """
  -----> Scaling for my-api
  proctype: qty
  --------: ---
  web:  2
  """

  @base_opts [name: nil, refresh_interval: nil]

  defp wait_for_ready(pid) do
    case Cache.status(pid) do
      :ready -> :ok
      _other -> wait_for_ready(pid)
    end
  end

  setup do
    expect(DokkuRadar.DokkuCli.Mock, :call, fn "ps:report" ->
      {:ok, @ps_report_output}
    end)

    expect(DokkuRadar.DokkuCli.Mock, :call, 2, fn "ps:scale", [app] ->
      case app do
        "blog-cms" -> {:ok, @blog_cms_scale_output}
        "my-api" -> {:ok, @my_api_scale_output}
      end
    end)

    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    pid = start_supervised!({Cache, @base_opts})
    %{pid: pid}
  end

  describe "list/0" do
    test "returns cached ps entries after init", %{pid: pid} do
      :ok = wait_for_ready(pid)

      assert {:ok, entries} = Cache.list(pid)
      assert length(entries) == 2
      apps = entries |> Enum.map(& &1.app) |> Enum.sort()
      assert apps == ["blog-cms", "my-api"]
    end
  end

  describe "scale/1" do
    test "returns scale for requested app", %{pid: pid} do
      :ok = wait_for_ready(pid)

      assert {:ok, scale} = Cache.scale("blog-cms", pid)
      assert scale["web"] == 1
    end

    test "returns scale for another app", %{pid: pid} do
      :ok = wait_for_ready(pid)

      assert {:ok, scale} = Cache.scale("my-api", pid)
      assert scale["web"] == 2
    end

    test "returns {:error, :not_found} for unknown app", %{pid: pid} do
      :ok = wait_for_ready(pid)

      assert {:error, :not_found} = Cache.scale("unknown-app", pid)
    end
  end

  describe "status/1" do
    test "returns :ready after data is loaded", %{pid: pid} do
      :ok = wait_for_ready(pid)
      assert Cache.status(pid) == :ready
    end
  end

  describe "when ps:report fails" do
    setup do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "ps:report" ->
        {:error, "ssh: Connection refused", 255}
      end)

      pid = start_supervised!({Cache, [name: nil, refresh_interval: nil]}, id: :fail_cache)
      %{fail_pid: pid}
    end

    test "status is :error after failed load", %{fail_pid: pid} do
      Process.sleep(50)
      assert Cache.status(pid) == :error
    end

    test "list returns {:error, :no_data}", %{fail_pid: pid} do
      Process.sleep(50)
      assert {:error, :no_data} = Cache.list(pid)
    end
  end
end
