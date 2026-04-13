defmodule DokkuRadar.Git.CacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.Git.Cache

  setup :set_mox_global
  setup :verify_on_exit!

  @git_report_output """
  =====> blog-cms git information
         Git last updated at:          1775125215
  =====> my-api git information
         Git last updated at:          1775200000
  """

  @base_opts [name: nil, refresh_interval: nil]

  defp wait_for_ready(pid) do
    case Cache.status(pid) do
      :ready -> :ok
      _other -> wait_for_ready(pid)
    end
  end

  setup do
    expect(DokkuRadar.DokkuCli.Mock, :call, fn "git:report" ->
      {:ok, @git_report_output}
    end)

    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    pid = start_supervised!({Cache, @base_opts})
    %{pid: pid}
  end

  describe "last_deploy_timestamps/0" do
    test "returns cached timestamps after init", %{pid: pid} do
      :ok = wait_for_ready(pid)

      assert {:ok, timestamps} = Cache.last_deploy_timestamps(pid)
      assert timestamps == %{"blog-cms" => 1_775_125_215, "my-api" => 1_775_200_000}
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
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "git:report" ->
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
      assert {:error, :no_data} = Cache.last_deploy_timestamps(pid)
    end
  end
end
