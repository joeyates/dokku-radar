defmodule DokkuRadar.CollectorTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Collector

  setup :verify_on_exit!

  @opts [
    docker_client: DokkuRadar.DockerClient.Mock,
    filesystem_reader: DokkuRadar.FilesystemReader.Mock,
    service_cache: DokkuRadar.ServiceCache.Mock
  ]

  describe "collect/1" do
    test "returns all ten metrics for a single Dokku container" do
      setup_single_app_expectations()

      assert {:ok, metrics} = Collector.collect(@opts)

      assert length(metrics) == 10
      assert find_metric(metrics, "dokku_app_processes_configured")
      assert find_metric(metrics, "dokku_app_processes_running")
      assert find_metric(metrics, "dokku_container_state")
      assert find_metric(metrics, "dokku_container_restarts_total")
      assert find_metric(metrics, "dokku_app_last_deploy_timestamp")
      assert find_metric(metrics, "dokku_ssl_cert_expiry_timestamp")
      assert find_metric(metrics, "dokku_app_cpu_usage_seconds_total")
      assert find_metric(metrics, "dokku_app_memory_usage_bytes")
      assert find_metric(metrics, "dokku_service_linked")
      assert find_metric(metrics, "dokku_service_status")
    end

    test "builds dokku_service_linked metric from cached services" do
      stub(DokkuRadar.ServiceCache.Mock, :service_links, fn ->
        {:ok,
         [
           %DokkuRadar.ServiceCache{
             type: "postgres",
             name: "my-db",
             status: "running",
             links: ["my-app"]
           },
           %DokkuRadar.ServiceCache{
             type: "postgres",
             name: "shared-db",
             status: "running",
             links: ["app1", "app2"]
           }
         ]}
      end)

      setup_single_app_expectations(service_cache: false)

      assert {:ok, metrics} = Collector.collect(@opts)

      sl = find_metric(metrics, "dokku_service_linked")
      assert sl.type == :gauge
      assert length(sl.samples) == 3

      sample = Enum.find(sl.samples, &(&1.labels["app"] == "my-app"))
      assert sample.labels["service_type"] == "postgres"
      assert sample.labels["service_name"] == "my-db"
      assert sample.value == 1
    end

    test "builds dokku_service_status metric from cached services" do
      stub(DokkuRadar.ServiceCache.Mock, :service_links, fn ->
        {:ok,
         [
           %DokkuRadar.ServiceCache{
             type: "postgres",
             name: "my-db",
             status: "running",
             links: ["my-app"]
           },
           %DokkuRadar.ServiceCache{
             type: "redis",
             name: "cache",
             status: "stopped",
             links: ["my-app"]
           }
         ]}
      end)

      setup_single_app_expectations(service_cache: false)

      assert {:ok, metrics} = Collector.collect(@opts)

      ss = find_metric(metrics, "dokku_service_status")
      assert ss.type == :gauge
      assert length(ss.samples) == 2

      running = Enum.find(ss.samples, &(&1.labels["service_name"] == "my-db"))
      assert running.value == 1

      stopped = Enum.find(ss.samples, &(&1.labels["service_name"] == "cache"))
      assert stopped.value == 0
    end

    test "returns empty service metrics when cache has no services" do
      setup_single_app_expectations()

      assert {:ok, metrics} = Collector.collect(@opts)

      sl = find_metric(metrics, "dokku_service_linked")
      assert sl.samples == []

      ss = find_metric(metrics, "dokku_service_status")
      assert ss.samples == []
    end

    test "returns empty service metrics when cache returns error" do
      stub(DokkuRadar.ServiceCache.Mock, :service_links, fn ->
        {:error, {255, "Connection refused"}}
      end)

      setup_single_app_expectations(service_cache: false)

      assert {:ok, metrics} = Collector.collect(@opts)

      sl = find_metric(metrics, "dokku_service_linked")
      assert sl.samples == []

      ss = find_metric(metrics, "dokku_service_status")
      assert ss.samples == []
    end

    test "populates processes_configured from scale file" do
      setup_single_app_expectations(scale: %{"web" => 2, "worker" => 1})

      assert {:ok, metrics} = Collector.collect(@opts)

      pc = find_metric(metrics, "dokku_app_processes_configured")
      assert pc.type == :gauge
      assert length(pc.samples) == 2

      web = Enum.find(pc.samples, &(&1.labels["process_type"] == "web"))
      assert web.value == 2

      worker = Enum.find(pc.samples, &(&1.labels["process_type"] == "worker"))
      assert worker.value == 1
    end

    test "counts running processes by app and process type" do
      containers = [
        dokku_container("aaa111", "my-app", "web", 1, "running", 1_700_000_000),
        dokku_container("bbb222", "my-app", "web", 2, "running", 1_700_000_000),
        dokku_container("ccc333", "my-app", "web", 3, "exited", 1_700_000_000)
      ]

      setup_expectations(
        containers: containers,
        scales: %{"my-app" => {:ok, %{"web" => 3}}},
        cert_expiries: %{"my-app" => {:error, :no_cert}}
      )

      assert {:ok, metrics} = Collector.collect(@opts)

      pr = find_metric(metrics, "dokku_app_processes_running")
      assert [%{labels: %{"app" => "my-app", "process_type" => "web"}, value: 2}] = pr.samples
    end

    test "reports container state with labels" do
      setup_single_app_expectations()

      assert {:ok, metrics} = Collector.collect(@opts)

      cs = find_metric(metrics, "dokku_container_state")
      assert [sample] = cs.samples
      assert sample.labels["app"] == "my-app"
      assert sample.labels["state"] == "running"
      assert sample.labels["container_name"] == "my-app.web.1"
      assert sample.labels["container_id"] == String.slice("abc123def456", 0, 12)
      assert sample.value == 1
    end

    test "reports container restart count from inspect" do
      setup_single_app_expectations(restart_count: 5)

      assert {:ok, metrics} = Collector.collect(@opts)

      cr = find_metric(metrics, "dokku_container_restarts_total")
      assert [sample] = cr.samples
      assert sample.labels["app"] == "my-app"
      assert sample.value == 5
    end

    test "uses most recent container creation time for last deploy" do
      containers = [
        dokku_container("aaa111", "my-app", "web", 1, "running", 1_700_000_100),
        dokku_container("bbb222", "my-app", "web", 2, "running", 1_700_000_200)
      ]

      setup_expectations(
        containers: containers,
        scales: %{"my-app" => {:ok, %{"web" => 2}}},
        cert_expiries: %{"my-app" => {:error, :no_cert}}
      )

      assert {:ok, metrics} = Collector.collect(@opts)

      ld = find_metric(metrics, "dokku_app_last_deploy_timestamp")
      assert [%{labels: %{"app" => "my-app"}, value: 1_700_000_200}] = ld.samples
    end

    test "reports SSL cert expiry as unix timestamp" do
      expiry = ~U[2026-07-08 12:00:00Z]
      setup_single_app_expectations(cert_expiry: {:ok, expiry})

      assert {:ok, metrics} = Collector.collect(@opts)

      se = find_metric(metrics, "dokku_ssl_cert_expiry_timestamp")
      assert [%{labels: %{"app" => "my-app"}, value: value}] = se.samples
      assert value == DateTime.to_unix(expiry)
    end

    test "converts CPU nanoseconds to seconds" do
      setup_single_app_expectations(cpu_ns: 2_500_000_000)

      assert {:ok, metrics} = Collector.collect(@opts)

      cu = find_metric(metrics, "dokku_app_cpu_usage_seconds_total")
      assert [%{value: 2.5}] = cu.samples
    end

    test "reports memory usage in bytes" do
      setup_single_app_expectations(memory_bytes: 104_857_600)

      assert {:ok, metrics} = Collector.collect(@opts)

      mu = find_metric(metrics, "dokku_app_memory_usage_bytes")
      assert [%{value: 104_857_600}] = mu.samples
    end

    test "filters out non-Dokku containers" do
      containers = [
        dokku_container("aaa111", "my-app", "web", 1, "running", 1_700_000_000),
        %{
          "Id" => "zzz999",
          "Names" => ["/random-container"],
          "State" => "running",
          "Created" => 1_700_000_000,
          "Labels" => %{}
        }
      ]

      setup_expectations(
        containers: containers,
        scales: %{"my-app" => {:ok, %{"web" => 1}}},
        cert_expiries: %{"my-app" => {:error, :no_cert}}
      )

      assert {:ok, metrics} = Collector.collect(@opts)

      cs = find_metric(metrics, "dokku_container_state")
      assert length(cs.samples) == 1
      assert hd(cs.samples).labels["app"] == "my-app"
    end

    test "handles stats failure gracefully" do
      stub(DokkuRadar.ServiceCache.Mock, :service_links, fn -> {:ok, []} end)

      expect(DokkuRadar.DockerClient.Mock, :list_containers, fn _opts ->
        {:ok, [dokku_container("aaa111", "my-app", "web", 1, "running", 1_700_000_000)]}
      end)

      expect(DokkuRadar.DockerClient.Mock, :container_stats, fn "aaa111", _opts ->
        {:error, :timeout}
      end)

      expect(DokkuRadar.DockerClient.Mock, :container_inspect, fn "aaa111", _opts ->
        {:ok, %{"State" => %{"RestartCount" => 0}}}
      end)

      expect(DokkuRadar.FilesystemReader.Mock, :app_scale, fn "my-app", _opts ->
        {:ok, %{"web" => 1}}
      end)

      expect(DokkuRadar.FilesystemReader.Mock, :cert_expiry, fn "my-app" ->
        {:error, :no_cert}
      end)

      assert {:ok, metrics} = Collector.collect(@opts)

      cu = find_metric(metrics, "dokku_app_cpu_usage_seconds_total")
      assert cu.samples == []

      mu = find_metric(metrics, "dokku_app_memory_usage_bytes")
      assert mu.samples == []

      # Container state is still reported
      cs = find_metric(metrics, "dokku_container_state")
      assert length(cs.samples) == 1
    end

    test "handles inspect failure gracefully" do
      stub(DokkuRadar.ServiceCache.Mock, :service_links, fn -> {:ok, []} end)

      expect(DokkuRadar.DockerClient.Mock, :list_containers, fn _opts ->
        {:ok, [dokku_container("aaa111", "my-app", "web", 1, "running", 1_700_000_000)]}
      end)

      expect(DokkuRadar.DockerClient.Mock, :container_stats, fn "aaa111", _opts ->
        {:ok, default_stats()}
      end)

      expect(DokkuRadar.DockerClient.Mock, :container_inspect, fn "aaa111", _opts ->
        {:error, {404, %{"message" => "No such container"}}}
      end)

      expect(DokkuRadar.FilesystemReader.Mock, :app_scale, fn "my-app", _opts ->
        {:ok, %{"web" => 1}}
      end)

      expect(DokkuRadar.FilesystemReader.Mock, :cert_expiry, fn "my-app" ->
        {:error, :no_cert}
      end)

      assert {:ok, metrics} = Collector.collect(@opts)

      cr = find_metric(metrics, "dokku_container_restarts_total")
      assert cr.samples == []
    end

    test "handles missing scale file" do
      setup_single_app_expectations(scale: {:error, :enoent})

      assert {:ok, metrics} = Collector.collect(@opts)

      pc = find_metric(metrics, "dokku_app_processes_configured")
      assert pc.samples == []
    end

    test "handles missing SSL cert" do
      setup_single_app_expectations(cert_expiry: {:error, :no_cert})

      assert {:ok, metrics} = Collector.collect(@opts)

      se = find_metric(metrics, "dokku_ssl_cert_expiry_timestamp")
      assert se.samples == []
    end

    test "handles containers with nil Names" do
      container = %{
        "Id" => "xyz789abc012",
        "Names" => nil,
        "State" => "running",
        "Created" => 1_700_000_000,
        "Labels" => %{"com.dokku.app-name" => "my-app"}
      }

      setup_expectations(
        containers: [container],
        scales: %{"my-app" => {:ok, %{"web" => 1}}},
        cert_expiries: %{"my-app" => {:error, :no_cert}}
      )

      assert {:ok, metrics} = Collector.collect(@opts)

      cs = find_metric(metrics, "dokku_container_state")
      assert [sample] = cs.samples
      assert sample.labels["container_name"] == "xyz789abc012"
    end

    test "returns error when list_containers fails" do
      expect(DokkuRadar.DockerClient.Mock, :list_containers, fn _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} = Collector.collect(@opts)
    end
  end

  defp find_metric(metrics, name) do
    Enum.find(metrics, &(&1.name == name))
  end

  defp dokku_container(id, app, process_type, instance, state, created) do
    %{
      "Id" => id,
      "Names" => ["/#{app}.#{process_type}.#{instance}"],
      "State" => state,
      "Created" => created,
      "Labels" => %{"com.dokku.app-name" => app}
    }
  end

  defp default_stats(opts \\ []) do
    cpu_ns = Keyword.get(opts, :cpu_ns, 5_000_000_000)
    memory_bytes = Keyword.get(opts, :memory_bytes, 52_428_800)

    %{
      "cpu_stats" => %{
        "cpu_usage" => %{"total_usage" => cpu_ns}
      },
      "memory_stats" => %{
        "usage" => memory_bytes
      }
    }
  end

  defp setup_single_app_expectations(overrides \\ []) do
    id = "abc123def456"
    scale = Keyword.get(overrides, :scale, %{"web" => 1})
    restart_count = Keyword.get(overrides, :restart_count, 0)
    cpu_ns = Keyword.get(overrides, :cpu_ns, 5_000_000_000)
    memory_bytes = Keyword.get(overrides, :memory_bytes, 52_428_800)
    setup_service_cache = Keyword.get(overrides, :service_cache, true)

    cert_expiry =
      Keyword.get(overrides, :cert_expiry, {:ok, ~U[2026-07-08 12:00:00Z]})

    scale_result = if is_map(scale), do: {:ok, scale}, else: scale

    containers = [dokku_container(id, "my-app", "web", 1, "running", 1_700_000_000)]

    expect(DokkuRadar.DockerClient.Mock, :list_containers, fn _opts ->
      {:ok, containers}
    end)

    expect(DokkuRadar.DockerClient.Mock, :container_stats, fn ^id, _opts ->
      {:ok, default_stats(cpu_ns: cpu_ns, memory_bytes: memory_bytes)}
    end)

    expect(DokkuRadar.DockerClient.Mock, :container_inspect, fn ^id, _opts ->
      {:ok, %{"State" => %{"RestartCount" => restart_count}}}
    end)

    expect(DokkuRadar.FilesystemReader.Mock, :app_scale, fn "my-app", _opts ->
      scale_result
    end)

    expect(DokkuRadar.FilesystemReader.Mock, :cert_expiry, fn "my-app" ->
      cert_expiry
    end)

    if setup_service_cache do
      stub(DokkuRadar.ServiceCache.Mock, :service_links, fn -> {:ok, []} end)
    end
  end

  defp setup_expectations(opts) do
    containers = Keyword.fetch!(opts, :containers)
    scales = Keyword.get(opts, :scales, %{})
    cert_expiries = Keyword.get(opts, :cert_expiries, %{})

    stub(DokkuRadar.ServiceCache.Mock, :service_links, fn -> {:ok, []} end)

    expect(DokkuRadar.DockerClient.Mock, :list_containers, fn _opts ->
      {:ok, containers}
    end)

    dokku_containers =
      Enum.filter(containers, &(&1["Labels"]["com.dokku.app-name"] != nil))

    for cont <- dokku_containers do
      id = cont["Id"]

      expect(DokkuRadar.DockerClient.Mock, :container_stats, fn ^id, _opts ->
        {:ok, default_stats()}
      end)

      expect(DokkuRadar.DockerClient.Mock, :container_inspect, fn ^id, _opts ->
        {:ok, %{"State" => %{"RestartCount" => 0}}}
      end)
    end

    app_names =
      dokku_containers
      |> Enum.map(& &1["Labels"]["com.dokku.app-name"])
      |> Enum.uniq()

    for app <- app_names do
      scale_result = Map.get(scales, app, {:ok, %{"web" => 1}})

      expect(DokkuRadar.FilesystemReader.Mock, :app_scale, fn ^app, _opts ->
        scale_result
      end)

      cert_result = Map.get(cert_expiries, app, {:error, :no_cert})

      expect(DokkuRadar.FilesystemReader.Mock, :cert_expiry, fn ^app ->
        cert_result
      end)
    end
  end
end
