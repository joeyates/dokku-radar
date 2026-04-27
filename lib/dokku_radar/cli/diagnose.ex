defmodule DokkuRadar.CLI.Diagnose do
  alias DokkuRemote.App

  @ssh_host_dir "/var/lib/dokku/data/storage/dokku-radar/.ssh"
  @host_private_key_path "#{@ssh_host_dir}/id_ed25519"
  @container_ssh_dir "/data/.ssh"
  @container_private_key_path "#{@container_ssh_dir}/id_ed25519"
  @health_url "http://127.0.0.1:9110/health"
  @metrics_url "http://127.0.0.1:9110/metrics"
  @dashboard_path "grafana/dashboard.json"
  @prometheus_targets_url "http://prometheus.web.1:9090/api/v1/targets"
  @monitoring_network "monitoring"

  @commands_enter_app Application.compile_env(
                        :dokku_radar,
                        :"DokkuRemote.Commands.Enter.App",
                        DokkuRemote.Commands.Enter.App
                      )

  @commands_network_app Application.compile_env(
                          :dokku_radar,
                          :"DokkuRemote.Commands.Network.App",
                          DokkuRemote.Commands.Network.App
                        )

  @commands_ps_app Application.compile_env(
                     :dokku_radar,
                     :"DokkuRemote.Commands.Ps.App",
                     DokkuRemote.Commands.Ps.App
                   )

  @commands_storage_app Application.compile_env(
                          :dokku_radar,
                          :"DokkuRemote.Commands.Storage.App",
                          DokkuRemote.Commands.Storage.App
                        )

  @root_command Application.compile_env(
                  :dokku_radar,
                  :"DokkuRemote.Root.Command",
                  DokkuRemote.Root.Command
                )

  def run(%App{} = app) do
    prometheus_app = %App{dokku_host: app.dokku_host, dokku_app: "prometheus"}
    grafana_app = %App{dokku_host: app.dokku_host, dokku_app: "grafana"}
    apps = [app, prometheus_app, grafana_app]

    running_checks =
      Enum.map(
        apps,
        fn app ->
          %{
            message: "#{app.dokku_app} is running",
            function: fn -> check_app_running(app) end
          }
        end
      )

    network_checks =
      Enum.map(
        apps,
        fn app ->
          %{
            message: "#{app.dokku_app} is on #{@monitoring_network} network",
            function: fn -> check_app_network(app, @monitoring_network) end
          }
        end
      )

    checks =
      running_checks ++
        network_checks ++
        [
          %{
            message: "private key directory is mounted in container",
            function: fn -> check_private_key_mount(app) end
          },
          %{
            message: "private key is installed on host",
            function: fn -> check_private_key_file(app) end
          },
          %{
            message: "dokku-radar health endpoint responds ok",
            function: fn -> check_health_endpoint(app) end
          },
          %{
            message: "dokku-radar has SSH connectivity to the host",
            function: fn -> check_app_ssh_connectivity(app) end
          },
          %{
            message: "Prometheus targets are healthy",
            function: fn -> check_prometheus_targets(app) end
          },
          %{
            message: "metrics cover all Grafana panels",
            function: fn -> check_metrics_coverage(app) end
          }
        ]

    all_passed =
      Enum.reduce(
        checks,
        true,
        fn check, result ->
          IO.write("Checking #{check.message}... ")

          case check.function.() do
            {:ok, nil} ->
              IO.puts("✅")
              result

            {:ok, message} ->
              IO.puts("✅ #{message}")
              result

            {:error, message} ->
              IO.puts("❌ #{message}")
              false
          end
        end
      )

    if all_passed do
      IO.puts("All checks passed! ✅")
      :ok
    else
      IO.puts("Some checks failed. Please review the output above. ❌")
      {:error, "One or more checks failed"}
    end
  end

  defp check_app_running(%App{} = app) do
    case @commands_ps_app.report(app) do
      {:ok, report} ->
        if report.running do
          {:ok, nil}
        else
          {:error, "App #{inspect(app.dokku_app)} not running"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Could not retrieve ps report for #{inspect(app.dokku_app)}"}
    end
  end

  defp check_private_key_mount(%App{} = app) do
    case @commands_storage_app.mount_exists?(
           app,
           @ssh_host_dir,
           @container_ssh_dir
         ) do
      {:ok, true} ->
        {:ok, nil}

      {:ok, false} ->
        {:error, "Private key: mount not found for #{@ssh_host_dir} -> #{@container_ssh_dir}"}

      {:error, _output, _exit_code} ->
        {:error, "Private key: mount: could not retrieve storage report"}
    end
  end

  defp check_private_key_file(%App{dokku_host: dokku_host}) do
    case @root_command.run(dokku_host, "test", ["-f", @host_private_key_path]) do
      {:ok, ""} ->
        {:ok, nil}

      {:error, "", 1} ->
        {:error, "Private key: file not found at #{@host_private_key_path}"}

      {:error, _output, _exit_code} ->
        {:error, "Failed to check private key file on host"}
    end
  end

  defp check_app_network(%App{} = app, network) do
    case @commands_network_app.get(app, "attach-post-deploy") do
      {:ok, output} ->
        if output == network do
          {:ok, nil}
        else
          {:error, "Network: #{inspect(app.dokku_app)} is not on #{network} network"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Network: could not retrieve network report for #{app.dokku_app}"}
    end
  end

  defp check_health_endpoint(%App{} = app) do
    case @commands_enter_app.run(
           app,
           "web",
           ["wget", "-qO-", @health_url]
         ) do
      {:ok, output} ->
        if String.trim(output) == "ok" do
          {:ok, nil}
        else
          {:error, "Health: unexpected response: #{String.trim(output)}"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Health: could not reach health endpoint"}
    end
  end

  defp check_app_ssh_connectivity(%App{} = app) do
    ssh_params = dokku_radar_ssh_params()

    case @commands_enter_app.run(app, "web", ssh_params ++ ["apps:help"]) do
      {:ok, _output} ->
        {:ok, nil}

      {:error, _output, _exit_code} ->
        {:error, "#{app.dokku_app} could not connect to host"}
    end
  end

  defp dokku_radar_ssh_params() do
    host_ip_for_dokku_radar =
      System.get_env("HOST_IP_FOR_DOKKU_RADAR") ||
        raise """
        environment variable HOST_IP_FOR_DOKKU_RADAR is missing.
        For example: 172.1.0.1
        """

    ~w(
      ssh
      -o BatchMode=yes
      -o UserKnownHostsFile=/dev/null
      -o LogLevel=ERROR
      -o StrictHostKeyChecking=no
      -i #{@container_private_key_path}
      dokku@#{host_ip_for_dokku_radar}
    )
  end

  defp check_metrics_coverage(%App{} = app) do
    case @commands_enter_app.run(app, "web", ["wget", "-qO-", @metrics_url]) do
      {:ok, metrics_output} ->
        required = required_metric_names()
        with_data = metric_names_with_data(metrics_output)
        missing = Enum.reject(required, &(&1 in with_data))

        if missing == [] do
          {:ok, nil}
        else
          {:error, "Missing metrics: #{missing |> Enum.sort() |> Enum.join(", ")}"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Metrics coverage: could not fetch metrics output"}
    end
  end

  defp required_metric_names() do
    @dashboard_path
    |> File.read!()
    |> Jason.decode!()
    |> get_in(["panels"])
    |> Kernel.||([])
    |> Enum.flat_map(&(get_in(&1, ["targets"]) || []))
    |> Enum.flat_map(fn target ->
      case target["expr"] do
        nil -> []
        expr -> ~r/\bdokku_\w+/ |> Regex.scan(expr) |> List.flatten()
      end
    end)
    |> Enum.uniq()
  end

  defp metric_names_with_data(output) do
    output
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.map(fn line ->
      line |> String.split(["{", " "], parts: 2) |> List.first()
    end)
    |> Enum.uniq()
  end

  defp check_prometheus_targets(%App{} = app) do
    case @commands_enter_app.run(app, "web", ["wget", "-qO-", @prometheus_targets_url]) do
      {:ok, output} ->
        case Jason.decode(output) do
          {:ok, %{"data" => %{"activeTargets" => targets}}} ->
            dokku_radar_target =
              Enum.find(targets, fn target ->
                get_in(target, ["labels", "job"]) == "dokku_radar"
              end)

            case dokku_radar_target do
              %{"health" => "up"} ->
                {:ok, nil}

              nil ->
                {:error, "Prometheus targets: dokku_radar job not found"}

              %{"health" => health} ->
                {:error, "Prometheus targets: dokku_radar health is #{health}"}
            end

          _ ->
            {:error, "Prometheus targets: unexpected response format"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Prometheus targets: could not reach Prometheus API"}
    end
  end
end
