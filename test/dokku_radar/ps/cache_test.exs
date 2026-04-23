defmodule DokkuRadar.Ps.CacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.Ps.Cache
  alias DokkuRemote.Commands.Ps.Report
  alias DokkuRemote.Commands.Ps.Scale

  setup :set_mox_global
  setup :verify_on_exit!

  @reports %{
    "blog-cms" => %Report{
      app_name: "blog-cms",
      computed_stop_timeout_seconds: nil,
      deployed: nil,
      global_stop_timeout_seconds: nil,
      processes: nil,
      ps_can_scale: nil,
      ps_computed_procfile_path: nil,
      ps_global_procfile_path: nil,
      ps_procfile_path: nil,
      ps_restart_policy: nil,
      restore: nil,
      running: nil,
      stop_timeout_seconds: nil
    },
    "my-api" => %Report{
      app_name: "my-api",
      computed_stop_timeout_seconds: nil,
      deployed: nil,
      global_stop_timeout_seconds: nil,
      processes: nil,
      ps_can_scale: nil,
      ps_computed_procfile_path: nil,
      ps_global_procfile_path: nil,
      ps_procfile_path: nil,
      ps_restart_policy: nil,
      restore: nil,
      running: nil,
      stop_timeout_seconds: nil
    }
  }
  @scales %{
    "blog-cms" => %{proctypes: %{"web" => 1}},
    "my-api" => %{proctypes: %{"web" => 2}}
  }

  @base_opts [name: nil, refresh_interval: nil]

  defp wait_for_ready(pid) do
    case Cache.status(pid) do
      :ready -> :ok
      _other -> wait_for_ready(pid)
    end
  end

  setup do
    stub(DokkuRemote.Commands.Ps.Mock, :report, fn _host ->
      {:ok, @reports}
    end)

    stub(DokkuRemote.Commands.Ps.App.Mock, :scale, fn app ->
      {
        :ok,
        struct(Scale, Map.merge(%{app_name: app.dokku_app}, @scales[app.dokku_app]))
      }
    end)

    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    pid = start_supervised!({Cache, @base_opts})
    wait_for_ready(pid)
    %{pid: pid}
  end

  describe "list/0" do
    test "returns cached ps reports after init", %{pid: pid} do
      assert {:ok, reports} = Cache.list(pid)
      assert map_size(reports) == 2
      apps = reports |> Map.keys() |> Enum.sort()
      assert apps == ["blog-cms", "my-api"]
    end
  end

  describe "scale/1" do
    test "returns scale for requested app", %{pid: pid} do
      assert {:ok, scale} = Cache.scale("blog-cms", pid)
      assert scale.proctypes["web"] == 1
    end

    test "returns scale for another app", %{pid: pid} do
      assert {:ok, scale} = Cache.scale("my-api", pid)
      assert scale.proctypes["web"] == 2
    end

    test "returns {:error, :not_found} for unknown app", %{pid: pid} do
      assert {:error, :not_found} = Cache.scale("unknown-app", pid)
    end
  end

  describe "status/1" do
    test "returns :ready after data is loaded", %{pid: pid} do
      assert Cache.status(pid) == :ready
    end
  end

  describe "when ps:report fails" do
    setup do
      expect(DokkuRemote.Commands.Ps.Mock, :report, fn _host ->
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
