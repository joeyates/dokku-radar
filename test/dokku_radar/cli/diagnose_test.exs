defmodule DokkuRadar.CLI.DiagnoseTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mox

  alias DokkuRadar.CLI.Diagnose
  alias DokkuRemote.App

  @dokku_host "test.example.com"
  @dokku_app "dokku-radar"
  @monitoring_network "monitoring"
  @dokku_radar_app %App{dokku_host: @dokku_host, dokku_app: @dokku_app}
  @ssh_host_dir "/var/lib/dokku/data/storage/dokku-radar/.ssh"
  @private_key_path "#{@ssh_host_dir}/id_ed25519"
  @container_ssh_dir "/data/.ssh"
  @prometheus_targets_response ~s(
    {
      "status": "success",
      "data": {
        "activeTargets": [
          {
            "labels": {
              "job": "dokku_radar"
            },
            "health": "up"
          }
        ]
      }
    }
  )

  setup context do
    dokku_radar_running = Map.get(context, :dokku_radar_running, true)
    prometheus_running = Map.get(context, :prometheus_running, true)
    grafana_running = Map.get(context, :grafana_running, true)

    stub_commands_ps_app_reports(%{
      "dokku-radar" => dokku_radar_running,
      "prometheus" => prometheus_running,
      "grafana" => grafana_running
    })

    dokku_radar_network = Map.get(context, :dokku_radar_network, {:ok, @monitoring_network})
    prometheus_network = Map.get(context, :prometheus_network, {:ok, @monitoring_network})
    grafana_network = Map.get(context, :grafana_network, {:ok, @monitoring_network})

    stub_commands_network_app_gets(%{
      "dokku-radar" => dokku_radar_network,
      "prometheus" => prometheus_network,
      "grafana" => grafana_network
    })

    mount_exists = Map.get(context, :mount_exists, {:ok, true})
    stub_commands_storage_app_mount_exists(mount_exists)

    test_result = Map.get(context, :key_exists_test_result, {:ok, ""})
    stub_root_command(test_result)

    enter_health_response = Map.get(context, :enter_health_response, {:ok, "ok"})

    enter_apps_help_response =
      Map.get(context, :enter_apps_help_response, {:ok, "Usage: dokku apps[:COMMAND]"})

    enter_prometheus_response =
      Map.get(context, :enter_prometheus_response, {:ok, @prometheus_targets_response})

    stub_commands_enter_app_run(%{
      enter_health_response: enter_health_response,
      enter_apps_help_response: enter_apps_help_response,
      enter_prometheus_response: enter_prometheus_response
    })

    :ok
  end

  describe "run/1" do
    test "prints a passing line when all checks pass" do
      {:ok, _output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)
    end

    @tag dokku_radar_running: false
    test "returns error when dokku-radar is not running" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ App "dokku-radar" not running)
    end

    @tag prometheus_running: false
    test "returns error when prometheus is not running" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ App "prometheus" not running)
    end

    @tag grafana_running: false
    test "returns error when grafana is not running" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ App "grafana" not running)
    end

    @tag dokku_radar_network: {:ok, "other-network"}
    test "returns error when dokku-radar is not on the monitoring network" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ Network: "dokku-radar" is not on monitoring network)
    end

    @tag dokku_radar_network: {:error, "Failed to get network", 33}
    test "returns error when network check fails for dokku-radar" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ Network: could not retrieve network report for dokku-radar)
    end

    @tag prometheus_network: {:ok, "other-network"}
    test "returns error when prometheus is not on the monitoring network" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ Network: "prometheus" is not on monitoring network)
    end

    @tag prometheus_network: {:error, "Failed to get network", 33}
    test "returns error when network check fails for prometheus" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ Network: could not retrieve network report for prometheus)
    end

    @tag grafana_network: {:ok, "other-network"}
    test "returns error when grafana is not on the monitoring network" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ Network: "grafana" is not on monitoring network)
    end

    @tag grafana_network: {:error, "Failed to get network", 33}
    test "returns error when network check fails for grafana" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ ~s(❌ Network: could not retrieve network report for grafana)
    end

    @tag mount_exists: {:ok, false}
    test "returns error when private key mount does not exist" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~
               ~s(❌ Private key: mount not found for #{@ssh_host_dir} -> #{@container_ssh_dir})
    end

    @tag mount_exists: {:error, "Failed to get storage report", 33}
    test "returns error when private key mount check fails" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~
               ~s(❌ Private key: mount: could not retrieve storage report)
    end

    @tag key_exists_test_result: {:error, "", 1}
    test "returns error when private key file does not exist" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ "❌ Private key: file not found"
    end

    @tag key_exists_test_result: {:error, "Foobar", 99}
    test "returns error when private key file check fails" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ "❌ Failed to check private key file on host"
    end

    @tag enter_health_response: {:ok, "Service Unavailable"}
    test "returns error when health endpoint is not healthy" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ "❌ Health: unexpected response: Service Unavailable"
    end

    @tag enter_health_response: {:error, "Command failed", 1}
    test "returns error when health endpoint check fails" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ "❌ Health: could not reach health endpoint"
    end

    @tag enter_apps_help_response: {:error, "Command failed", 1}
    test "returns error when SSH connectivity check fails" do
      {{:error, _}, output} = with_io(fn -> Diagnose.run(@dokku_radar_app) end)

      assert output =~ "❌ dokku-radar could not connect to host"
    end
  end

  defp stub_commands_ps_app_reports(apps_running) do
    stub(
      DokkuRemote.Commands.Ps.App.Mock,
      :report,
      fn app ->
        {
          :ok,
          %DokkuRemote.Commands.Ps.Report{
            app_name: app.dokku_app,
            computed_stop_timeout_seconds: 20,
            deployed: true,
            global_stop_timeout_seconds: 10,
            processes: 1,
            ps_can_scale: true,
            ps_computed_procfile_path: nil,
            ps_global_procfile_path: nil,
            ps_procfile_path: nil,
            ps_restart_policy: "foo",
            restore: true,
            running: apps_running[app.dokku_app] || false,
            stop_timeout_seconds: 3
          }
        }
      end
    )
  end

  defp stub_commands_network_app_gets(network_response) do
    stub(
      DokkuRemote.Commands.Network.App.Mock,
      :get,
      fn app, "attach-post-deploy" ->
        network_response[app.dokku_app]
      end
    )
  end

  defp stub_commands_storage_app_mount_exists(mount_exists_response) do
    stub(
      DokkuRemote.Commands.Storage.App.Mock,
      :mount_exists?,
      fn _app, _host_path, _container_path ->
        mount_exists_response
      end
    )
  end

  defp stub_root_command(test_result) do
    stub(
      DokkuRemote.Root.Command.Mock,
      :run,
      fn
        @dokku_host, "test", ["-f", @private_key_path] ->
          test_result
      end
    )
  end

  defp stub_commands_enter_app_run(responses) do
    stub(
      DokkuRemote.Commands.Enter.App.Mock,
      :run,
      fn
        _app, "web", ["wget", "-qO-", "http://127.0.0.1:9110/health"] ->
          responses.enter_health_response

        _app,
        "web",
        [
          "ssh",
          "-o",
          "BatchMode=yes",
          "-o",
          "UserKnownHostsFile=/dev/null",
          "-o",
          "LogLevel=ERROR",
          "-o",
          "StrictHostKeyChecking=no",
          "-i",
          "/data/.ssh/id_ed25519",
          "dokku@172.17.0.1",
          "apps:help"
        ] ->
          responses.enter_apps_help_response

        _app, "web", ["wget", "-qO-", "http://prometheus.web.1:9090/api/v1/targets"] ->
          responses.enter_prometheus_response
      end
    )
  end
end
