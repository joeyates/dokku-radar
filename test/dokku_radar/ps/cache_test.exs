defmodule DokkuRadar.Ps.CacheTest do
  use ExUnit.Case, async: false

  import Mox

  alias DokkuRadar.Ps.Cache

  setup :set_mox_global
  setup :verify_on_exit!

  @entries [
    %{
      app: "blog-cms",
      process_type: "web",
      process_index: 1,
      state: "running",
      cid: "37d851b84ba"
    },
    %{app: "my-api", process_type: "web", process_index: 1, state: "running", cid: "4a2b9c0d1e2"}
  ]

  @base_opts [name: nil, refresh_interval: nil]

  defp wait_for_ready(pid) do
    case Cache.status(pid) do
      :ready -> :ok
      _other -> wait_for_ready(pid)
    end
  end

  setup do
    stub(DokkuRemote.Commands.Ps.Mock, :report, fn _host ->
      {:ok, @entries}
    end)

    stub(DokkuRemote.Commands.Ps.Mock, :scale, fn _host ->
      {
        :ok,
        %{
          "blog-cms" => %DokkuRemote.Commands.Ps.Scale{
            app_name: "blog-cms",
            proctypes: %{"web" => 1}
          },
          "my-api" => %DokkuRemote.Commands.Ps.Scale{
            app_name: "my-api",
            proctypes: %{"web" => 2}
          }
        }
      }
    end)

    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    pid = start_supervised!({Cache, @base_opts})
    wait_for_ready(pid)
    %{pid: pid}
  end

  describe "list/0" do
    test "returns cached ps entries after init", %{pid: pid} do
      assert {:ok, entries} = Cache.list(pid)
      assert length(entries) == 2
      apps = entries |> Enum.map(& &1.app) |> Enum.sort()
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
