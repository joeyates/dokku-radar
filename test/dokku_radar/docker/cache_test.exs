defmodule DokkuRadar.Docker.CacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.Docker.Cache

  setup :set_mox_global
  setup :verify_on_exit!

  @base_opts [name: nil, refresh_interval: nil]

  defp wait_for_ready(pid) do
    case Cache.status(pid) do
      :ready -> :ok
      _other -> wait_for_ready(pid)
    end
  end

  @container_id "abc111222333444555666777888999aaabbbcccdddeeefff00001234567890ab"
  @container_id_short "abc111222333"
  @stats %{"cpu_stats" => %{"cpu_usage" => %{"total_usage" => 100_000}}}
  @inspect_data %{"State" => %{"Running" => true, "RestartCount" => 0}}

  setup do
    expect(DokkuRadar.Docker.Client.Mock, :list_containers, fn ->
      {:ok, [%{"Id" => @container_id}]}
    end)

    expect(DokkuRadar.Docker.Client.Mock, :container_stats, fn @container_id ->
      {:ok, @stats}
    end)

    expect(DokkuRadar.Docker.Client.Mock, :container_inspect, fn @container_id ->
      {:ok, @inspect_data}
    end)

    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    pid = start_supervised!({Cache, @base_opts})
    wait_for_ready(pid)
    %{pid: pid}
  end

  describe "container_stats/2" do
    test "returns cached stats for a known container", %{pid: pid} do
      assert Cache.container_stats(@container_id, pid) == {:ok, @stats}
    end

    test "returns cached stats when looked up by abbreviated id", %{pid: pid} do
      assert Cache.container_stats(@container_id_short, pid) == {:ok, @stats}
    end

    test "returns error for an unknown container id", %{pid: pid} do
      assert {:error, :not_found} = Cache.container_stats("unknown", pid)
    end
  end

  describe "container_inspect/2" do
    test "returns cached inspect data for a known container", %{pid: pid} do
      assert Cache.container_inspect(@container_id, pid) == {:ok, @inspect_data}
    end

    test "returns cached inspect data when looked up by abbreviated id", %{pid: pid} do
      assert Cache.container_inspect(@container_id_short, pid) == {:ok, @inspect_data}
    end

    test "returns error for an unknown container id", %{pid: pid} do
      assert {:error, :not_found} = Cache.container_inspect("unknown", pid)
    end
  end

  describe "status/1" do
    test "returns :ready after data is loaded", %{pid: pid} do
      assert Cache.status(pid) == :ready
    end
  end

  describe "when Docker.Client fails" do
    setup do
      expect(DokkuRadar.Docker.Client.Mock, :list_containers, fn ->
        {:error, :econnrefused}
      end)

      pid =
        start_supervised!({Cache, [name: nil, refresh_interval: nil]}, id: :fail_cache)

      %{fail_pid: pid}
    end

    test "status is :error after failed load", %{fail_pid: pid} do
      Process.sleep(50)
      assert Cache.status(pid) == :error
    end

    test "returns {:error, :no_data} for container_stats when no data loaded", %{fail_pid: pid} do
      Process.sleep(50)
      assert {:error, :no_data} = Cache.container_stats(@container_id, pid)
    end

    test "returns {:error, :no_data} for container_inspect when no data loaded", %{
      fail_pid: pid
    } do
      Process.sleep(50)
      assert {:error, :no_data} = Cache.container_inspect(@container_id, pid)
    end
  end
end
