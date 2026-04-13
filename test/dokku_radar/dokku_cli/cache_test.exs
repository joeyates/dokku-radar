defmodule DokkuRadar.DokkuCli.CacheTest.SuccessCache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.hours(1)

  @impl true
  def load do
    Agent.update(:dokku_cli_cache_test_counter, &(&1 + 1))
    {:update, :data}
  end
end

defmodule DokkuRadar.DokkuCli.CacheTest.SlowCache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.hours(1)

  @impl true
  def load do
    Agent.update(:dokku_cli_cache_test_counter, &(&1 + 1))
    Process.sleep(100)
    {:update, :data}
  end
end

defmodule DokkuRadar.DokkuCli.CacheTest.ErrorCache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.hours(1)

  @impl true
  def load, do: {:error, :oops}
end

defmodule DokkuRadar.DokkuCli.CacheTest.IntervalCache do
  use DokkuRadar.DokkuCli.Cache, interval: 30

  @impl true
  def load do
    Agent.update(:dokku_cli_cache_test_counter, &(&1 + 1))
    {:update, :data}
  end
end

defmodule DokkuRadar.DokkuCli.CacheTest do
  use ExUnit.Case, async: false

  alias DokkuRadar.DokkuCli.CacheTest.{ErrorCache, IntervalCache, SlowCache, SuccessCache}

  @base_opts [name: nil, refresh_interval: nil]

  defp wait_for_status(pid, mod, target) do
    case mod.status(pid) do
      ^target -> :ok
      _other -> wait_for_status(pid, mod, target)
    end
  end

  defp load_count do
    Agent.get(:dokku_cli_cache_test_counter, & &1)
  end

  setup do
    counter_pid = start_supervised!({Agent, fn -> 0 end})
    Process.register(counter_pid, :dokku_cli_cache_test_counter)
    start_supervised!({Task.Supervisor, name: DokkuRadar.TaskSupervisor})
    :ok
  end

  describe "start_link/1" do
    test "starts the server and loads initial data" do
      pid = start_supervised!({SuccessCache, @base_opts})
      :ok = wait_for_status(pid, SuccessCache, :ready)
      assert SuccessCache.status(pid) == :ready
    end
  end

  describe "status/1" do
    test "returns :ready when data has been loaded" do
      pid = start_supervised!({SuccessCache, @base_opts})
      :ok = wait_for_status(pid, SuccessCache, :ready)
      assert SuccessCache.status(pid) == :ready
    end

    test "returns :error when load fails" do
      pid = start_supervised!({ErrorCache, @base_opts})
      :ok = wait_for_status(pid, ErrorCache, :error)
      assert ErrorCache.status(pid) == :error
    end
  end

  describe "refresh/1" do
    test "triggers a reload" do
      pid = start_supervised!({SuccessCache, @base_opts})
      :ok = wait_for_status(pid, SuccessCache, :ready)
      assert load_count() == 1

      SuccessCache.refresh(pid)
      :ok = wait_for_status(pid, SuccessCache, :ready)

      assert load_count() == 2
    end

    test "is ignored when a load is already running" do
      pid = start_supervised!({SlowCache, @base_opts})
      # The initial load takes 100ms; send a refresh while it is still running
      SlowCache.refresh(pid)
      :ok = wait_for_status(pid, SlowCache, :ready)

      assert load_count() == 1
    end
  end

  describe "interval-based reload" do
    test "triggers repeated loads at the configured interval" do
      # IntervalCache uses interval: 30ms; do not override with refresh_interval: nil
      pid = start_supervised!({IntervalCache, [name: nil]})
      :ok = wait_for_status(pid, IntervalCache, :ready)

      Process.sleep(120)

      assert load_count() >= 3
    end
  end
end
