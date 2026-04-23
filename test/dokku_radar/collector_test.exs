defmodule DokkuRadar.CollectorTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Collector

  setup :verify_on_exit!

  describe "collect/0" do
    test "returns all ten metrics for a single Dokku container" do
      setup_single_app_expectations()

      assert {:ok, metrics} = Collector.collect()

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
      stub(DokkuRadar.Services.Mock, :service_links, fn ->
        {:ok,
         [
           %DokkuRadar.Services.Service{
             type: "postgres",
             name: "my-db",
             status: "running",
             links: ["my-app"]
           },
           %DokkuRadar.Services.Service{
             type: "postgres",
             name: "shared-db",
             status: "running",
             links: ["app1", "app2"]
           }
         ]}
      end)

      setup_single_app_expectations(service_cache: false)

      assert {:ok, metrics} = Collector.collect()

      sl = find_metric(metrics, "dokku_service_linked")
      assert sl.type == :gauge
      assert length(sl.samples) == 3

      sample = Enum.find(sl.samples, &(&1.labels["app"] == "my-app"))
      assert sample.labels["service_type"] == "postgres"
      assert sample.labels["service_name"] == "my-db"
      assert sample.value == 1
    end

    test "builds dokku_service_status metric from cached services" do
      stub(DokkuRadar.Services.Mock, :service_links, fn ->
        {:ok,
         [
           %DokkuRadar.Services.Service{
             type: "postgres",
             name: "my-db",
             status: "running",
             links: ["my-app"]
           },
           %DokkuRadar.Services.Service{
             type: "redis",
             name: "cache",
             status: "stopped",
             links: ["my-app"]
           }
         ]}
      end)

      setup_single_app_expectations(service_cache: false)

      assert {:ok, metrics} = Collector.collect()

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

      assert {:ok, metrics} = Collector.collect()

      sl = find_metric(metrics, "dokku_service_linked")
      assert sl.samples == []

      ss = find_metric(metrics, "dokku_service_status")
      assert ss.samples == []
    end

    test "returns empty service metrics when cache returns error" do
      stub(DokkuRadar.Services.Mock, :service_links, fn ->
        {:error, {255, "Connection refused"}}
      end)

      setup_single_app_expectations(service_cache: false)

      assert {:ok, metrics} = Collector.collect()

      sl = find_metric(metrics, "dokku_service_linked")
      assert sl.samples == []

      ss = find_metric(metrics, "dokku_service_status")
      assert ss.samples == []
    end

    test "populates processes_configured from scale file" do
      setup_single_app_expectations(scale: %{"web" => 2, "worker" => 1})

      assert {:ok, metrics} = Collector.collect()

      pc = find_metric(metrics, "dokku_app_processes_configured")
      assert pc.type == :gauge
      assert length(pc.samples) == 2

      web = Enum.find(pc.samples, &(&1.labels["process_type"] == "web"))
      assert web.value == 2

      worker = Enum.find(pc.samples, &(&1.labels["process_type"] == "worker"))
      assert worker.value == 1
    end

    test "counts running processes by app and process type" do
      ps_entries = [
        status_entry("web", 1, true, "aaa11111111"),
        status_entry("web", 2, true, "bbb22222222"),
        status_entry("web", 3, false, "ccc33333333")
      ]

      containers = [
        dokku_container("aaa11111111", "my-app", "web", 1, "running", 1_700_000_000),
        dokku_container("bbb22222222", "my-app", "web", 2, "running", 1_700_000_000),
        dokku_container("ccc33333333", "my-app", "web", 3, "exited", 1_700_000_000)
      ]

      setup_expectations(
        containers: containers,
        ps_report: %{"my-app" => ps_report("my-app", ps_entries)},
        scales: %{"my-app" => {:ok, ps_scale("my-app", %{"web" => 3})}},
        cert_expiries: %{"my-app" => {:error, :no_cert}}
      )

      assert {:ok, metrics} = Collector.collect()

      pr = find_metric(metrics, "dokku_app_processes_running")
      assert [%{labels: %{"app" => "my-app", "process_type" => "web"}, value: 2}] = pr.samples
    end

    test "reports container state with labels" do
      setup_single_app_expectations()

      assert {:ok, metrics} = Collector.collect()

      cs = find_metric(metrics, "dokku_container_state")
      assert [sample] = cs.samples
      assert sample.labels["app"] == "my-app"
      assert sample.labels["state"] == "running"
      assert sample.labels["process_type"] == "web"
      assert sample.labels["process_index"] == "1"
      assert sample.labels["container_id"] == "abc12345678"
      assert sample.value == 1
    end

    test "reports container restart count from inspect" do
      setup_single_app_expectations(restart_count: 5)

      assert {:ok, metrics} = Collector.collect()

      cr = find_metric(metrics, "dokku_container_restarts_total")
      assert [sample] = cr.samples
      assert sample.labels["app"] == "my-app"
      assert sample.value == 5
    end

    test "uses git:report timestamp for last deploy" do
      containers = [
        dokku_container("aaa11111111", "my-app", "web", 1, "running", 1_700_000_100),
        dokku_container("bbb22222222", "my-app", "web", 2, "running", 1_700_000_200)
      ]

      setup_expectations(
        containers: containers,
        scales: %{"my-app" => {:ok, ps_scale("my-app", %{"web" => 2})}},
        cert_expiries: %{"my-app" => {:error, :no_cert}},
        git_reports: %{"my-app" => {:ok, 1_775_125_215}}
      )

      assert {:ok, metrics} = Collector.collect()

      ld = find_metric(metrics, "dokku_app_last_deploy_timestamp")
      assert [%{labels: %{"app" => "my-app"}, value: 1_775_125_215}] = ld.samples
    end

    test "reports SSL cert expiry as unix timestamp" do
      expiry = ~U[2026-07-08 12:00:00Z]
      setup_single_app_expectations(cert_expiry: {:ok, expiry})

      assert {:ok, metrics} = Collector.collect()

      se = find_metric(metrics, "dokku_ssl_cert_expiry_timestamp")
      assert [%{labels: %{"app" => "my-app"}, value: value}] = se.samples
      assert value == DateTime.to_unix(expiry)
    end

    test "converts CPU nanoseconds to seconds" do
      setup_single_app_expectations(cpu_ns: 2_500_000_000)

      assert {:ok, metrics} = Collector.collect()

      cu = find_metric(metrics, "dokku_app_cpu_usage_seconds_total")
      assert [%{value: 2.5}] = cu.samples
    end

    test "reports memory usage in bytes" do
      setup_single_app_expectations(memory_bytes: 104_857_600)

      assert {:ok, metrics} = Collector.collect()

      mu = find_metric(metrics, "dokku_app_memory_usage_bytes")
      assert [%{value: 104_857_600}] = mu.samples
    end

    test "filters out non-Dokku containers" do
      # PsReport only returns Dokku processes, so non-Dokku containers are naturally excluded
      ps_entries = [status_entry("web", 1, true, "aaa11111111")]

      containers = [
        dokku_container("aaa11111111", "my-app", "web", 1, "running", 1_700_000_000),
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
        ps_report: %{"my-app" => ps_report("my-app", ps_entries)},
        scales: %{"my-app" => {:ok, ps_scale("my-app", %{"web" => 1})}},
        cert_expiries: %{"my-app" => {:error, :no_cert}}
      )

      assert {:ok, metrics} = Collector.collect()

      cs = find_metric(metrics, "dokku_container_state")
      assert length(cs.samples) == 1
      assert hd(cs.samples).labels["app"] == "my-app"
    end

    test "handles stats failure gracefully" do
      stub(DokkuRadar.Services.Mock, :service_links, fn -> {:ok, []} end)

      expect(DokkuRadar.DockerClient.Mock, :container_stats, fn "aaa11111111" ->
        {:error, :timeout}
      end)

      expect(DokkuRadar.DockerClient.Mock, :container_inspect, fn "aaa11111111" ->
        {:ok, %{"State" => %{"RestartCount" => 0}}}
      end)

      expect(DokkuRadar.Ps.Mock, :scale, fn "my-app" ->
        {:ok, ps_scale("my-app", %{"web" => 1})}
      end)

      expect(DokkuRadar.Certs.Mock, :list, fn -> {:ok, %{}} end)

      entry = status_entry("web", 1, true, "aaa11111111")
      report = ps_report("my-app", [entry])

      expect(DokkuRadar.Ps.Mock, :list, fn ->
        {:ok, %{"my-app" => report}}
      end)

      expect(DokkuRadar.Git.Mock, :last_deploy_timestamps, fn ->
        {:ok, %{"my-app" => 1_700_000_000}}
      end)

      assert {:ok, metrics} = Collector.collect()

      cu = find_metric(metrics, "dokku_app_cpu_usage_seconds_total")
      assert cu.samples == []

      mu = find_metric(metrics, "dokku_app_memory_usage_bytes")
      assert mu.samples == []

      # Container state is still reported (from PsReport)
      cs = find_metric(metrics, "dokku_container_state")
      assert length(cs.samples) == 1
    end

    test "handles inspect failure gracefully" do
      stub(DokkuRadar.Services.Mock, :service_links, fn -> {:ok, []} end)

      expect(DokkuRadar.DockerClient.Mock, :container_stats, fn "aaa11111111" ->
        {:ok, default_stats()}
      end)

      expect(DokkuRadar.DockerClient.Mock, :container_inspect, fn "aaa11111111" ->
        {:error, {404, %{"message" => "No such container"}}}
      end)

      expect(DokkuRadar.Ps.Mock, :scale, fn "my-app" ->
        {:ok, ps_scale("my-app", %{"web" => 1})}
      end)

      expect(DokkuRadar.Certs.Mock, :list, fn -> {:ok, %{}} end)

      entry = status_entry("web", 1, true, "aaa11111111")
      report = ps_report("my-app", [entry])

      expect(DokkuRadar.Ps.Mock, :list, fn ->
        {:ok, %{"my-app" => report}}
      end)

      expect(DokkuRadar.Git.Mock, :last_deploy_timestamps, fn ->
        {:ok, %{"my-app" => 1_700_000_000}}
      end)

      assert {:ok, metrics} = Collector.collect()

      cr = find_metric(metrics, "dokku_container_restarts_total")
      assert cr.samples == []
    end

    test "handles ps:scale failure gracefully" do
      setup_single_app_expectations(scale: {:error, :enoent})

      assert {:ok, metrics} = Collector.collect()

      pc = find_metric(metrics, "dokku_app_processes_configured")
      assert pc.samples == []
    end

    test "handles missing SSL cert" do
      setup_single_app_expectations(cert_expiry: {:error, :no_cert})

      assert {:ok, metrics} = Collector.collect()

      se = find_metric(metrics, "dokku_ssl_cert_expiry_timestamp")
      assert se.samples == []
    end

    test "returns error when ps_report fails" do
      expect(DokkuRadar.Ps.Mock, :list, fn ->
        {:error, {1, "connection refused"}}
      end)

      assert {:error, {1, "connection refused"}} = Collector.collect()
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

  defp status_entry(process_name, index, running, cid) do
    %DokkuRemote.Commands.Ps.Report.StatusEntry{
      process_name: process_name,
      index: index,
      running: running,
      cid: cid
    }
  end

  defp ps_report(app_name, status_entries) do
    %DokkuRemote.Commands.Ps.Report{
      app_name: app_name,
      computed_stop_timeout_seconds: 60,
      deployed: true,
      global_stop_timeout_seconds: 60,
      processes: length(status_entries),
      ps_can_scale: true,
      ps_computed_procfile_path: nil,
      ps_global_procfile_path: nil,
      ps_procfile_path: nil,
      ps_restart_policy: nil,
      restore: true,
      running: Enum.any?(status_entries, & &1.running),
      stop_timeout_seconds: 60,
      status_entries: status_entries
    }
  end

  defp ps_scale(app_name, proctypes) do
    %DokkuRemote.Commands.Ps.Scale{app_name: app_name, proctypes: proctypes}
  end

  defp setup_single_app_expectations(overrides \\ []) do
    cid = "abc12345678"
    scale = Keyword.get(overrides, :scale, %{"web" => 1})
    restart_count = Keyword.get(overrides, :restart_count, 0)
    cpu_ns = Keyword.get(overrides, :cpu_ns, 5_000_000_000)
    memory_bytes = Keyword.get(overrides, :memory_bytes, 52_428_800)
    setup_service_cache = Keyword.get(overrides, :service_cache, true)

    cert_expiry =
      Keyword.get(overrides, :cert_expiry, {:ok, ~U[2026-07-08 12:00:00Z]})

    scale_result = if is_map(scale), do: {:ok, ps_scale("my-app", scale)}, else: scale

    expect(DokkuRadar.DockerClient.Mock, :container_stats, fn ^cid ->
      {:ok, default_stats(cpu_ns: cpu_ns, memory_bytes: memory_bytes)}
    end)

    expect(DokkuRadar.DockerClient.Mock, :container_inspect, fn ^cid ->
      {:ok, %{"State" => %{"RestartCount" => restart_count}}}
    end)

    expect(DokkuRadar.Ps.Mock, :scale, fn "my-app" ->
      scale_result
    end)

    certs_list_result =
      case cert_expiry do
        {:ok, dt} -> {:ok, %{"my-app" => dt}}
        {:error, _} -> {:ok, %{}}
      end

    expect(DokkuRadar.Certs.Mock, :list, fn -> certs_list_result end)

    entry = status_entry("web", 1, true, cid)
    report = ps_report("my-app", [entry])

    expect(DokkuRadar.Ps.Mock, :list, fn ->
      {:ok, %{"my-app" => report}}
    end)

    expect(DokkuRadar.Git.Mock, :last_deploy_timestamps, fn ->
      {:ok, %{"my-app" => 1_700_000_000}}
    end)

    if setup_service_cache do
      stub(DokkuRadar.Services.Mock, :service_links, fn -> {:ok, []} end)
    end
  end

  defp setup_expectations(opts) do
    containers = Keyword.get(opts, :containers, [])
    scales = Keyword.get(opts, :scales, %{})
    cert_expiries = Keyword.get(opts, :cert_expiries, %{})
    git_reports = Keyword.get(opts, :git_reports, %{})

    stub(DokkuRadar.Services.Mock, :service_links, fn -> {:ok, []} end)

    dokku_containers =
      Enum.filter(containers, &(&1["Labels"]["com.dokku.app-name"] != nil))

    ps_reports =
      Keyword.get_lazy(opts, :ps_report, fn ->
        dokku_containers
        |> Enum.map(fn cont ->
          app = cont["Labels"]["com.dokku.app-name"]
          name = hd(cont["Names"] || [""])
          name = String.trim_leading(name, "/")
          parts = String.split(name, ".")
          type = Enum.at(parts, 1, "web")
          index = parts |> List.last("1") |> String.to_integer()
          running = cont["State"] == "running"
          entry = status_entry(type, index, running, cont["Id"])
          {app, entry}
        end)
        |> Enum.group_by(fn {app, _entry} -> app end, fn {_app, entry} -> entry end)
        |> Map.new(fn {app_name, entries} -> {app_name, ps_report(app_name, entries)} end)
      end)

    for {_app_name, report} <- ps_reports, entry <- report.status_entries do
      cid = entry.cid

      expect(DokkuRadar.DockerClient.Mock, :container_stats, fn ^cid ->
        {:ok, default_stats()}
      end)

      expect(DokkuRadar.DockerClient.Mock, :container_inspect, fn ^cid ->
        {:ok, %{"State" => %{"RestartCount" => 0}}}
      end)
    end

    app_names = Map.keys(ps_reports)

    for app <- app_names do
      scale_result = Map.get(scales, app, {:ok, ps_scale(app, %{"web" => 1})})

      expect(DokkuRadar.Ps.Mock, :scale, fn ^app ->
        scale_result
      end)
    end

    timestamps_map =
      for {app, {:ok, ts}} <- git_reports, into: %{}, do: {app, ts}

    expect(DokkuRadar.Git.Mock, :last_deploy_timestamps, fn ->
      {:ok, timestamps_map}
    end)

    certs_map = for {app, {:ok, dt}} <- cert_expiries, into: %{}, do: {app, dt}
    expect(DokkuRadar.Certs.Mock, :list, fn -> {:ok, certs_map} end)

    expect(DokkuRadar.Ps.Mock, :list, fn -> {:ok, ps_reports} end)
  end
end
