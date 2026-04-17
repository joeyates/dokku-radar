defmodule DokkuRadar.CLI.Diagnose do
  alias DokkuRemote.App

  @ssh_host_dir "/var/lib/dokku/data/storage/dokku-radar/.ssh"
  @container_dir "/data/.ssh"
  @private_key_path "#{@ssh_host_dir}/id_ed25519"
  @health_url "http://127.0.0.1:9110/health"
  @monitoring_network "monitoring"
  @network_apps ["dokku-radar", "prometheus", "grafana"]

  @commands_ps Application.compile_env(
                 :dokku_radar,
                 :"DokkuRemote.Commands.Ps",
                 DokkuRemote.Commands.Ps
               )

  @root_command Application.compile_env(
                  :dokku_radar,
                  :"DokkuRemote.Root.Command",
                  DokkuRemote.Root.Command
                )

  def run(%App{} = app) do
    network_checks =
      Enum.map(@network_apps, fn target_app ->
        %{
          message: "#{target_app} is on #{@monitoring_network} network",
          function: fn -> check_app_network(app, target_app) end
        }
      end)

    checks =
      [
        %{message: "dokku-app is running", function: fn -> check_app_running(app) end},
        %{
          message: "private key directory is mounted in container",
          function: fn -> check_private_key_mount(app) end
        },
        %{
          message: "private key is installed on host",
          function: fn -> check_private_key_file(app) end
        }
      ] ++
        network_checks ++
        [
          %{message: "prometheus is running", function: fn -> check_prometheus_running(app) end},
          %{message: "grafana is running", function: fn -> check_grafana_running(app) end},
          %{
            message: "health endpoint responds ok",
            function: fn -> check_health_endpoint(app) end
          }
        ]

    Enum.each(checks, fn check ->
      IO.write("Checking #{check.message}... ")

      case check.function.() do
        {:ok, nil} -> IO.puts("✅")
        {:ok, message} -> IO.puts("✅ #{message}")
        {:error, message} -> IO.puts("❌ #{message}")
      end
    end)

    :ok
  end

  defp check_app_running(%App{dokku_host: dokku_host, dokku_app: dokku_app}) do
    case @commands_ps.report(dokku_host) do
      {:ok, entries} ->
        web_processes =
          Enum.filter(entries, &(&1.app == dokku_app && &1.process_type == "web"))

        all_running? = Enum.all?(web_processes, &(&1.state == "running"))

        if all_running? do
          {:ok, nil}
        else
          not_running =
            web_processes
            |> Enum.reject(&(&1.state == "running"))
            |> Enum.map(&"web.#{&1.process_index} is #{&1.state}")
            |> Enum.join(", ")

          {:error, "App running: #{not_running}"}
        end

      {:error, _output, _exit_code} ->
        {:error, "App running: could not retrieve ps report"}
    end
  end

  defp check_private_key_file(%App{dokku_host: dokku_host}) do
    case @root_command.run(dokku_host, "test", ["-f", @private_key_path], []) do
      {:ok, _output} ->
        {:ok, nil}

      {:error, _output, _exit_code} ->
        {:error, "Private key: file not found at #{@private_key_path}"}
    end
  end

  defp check_private_key_mount(%App{dokku_host: dokku_host, dokku_app: dokku_app}) do
    case @root_command.run(
           dokku_host,
           "dokku",
           ["storage:report", dokku_app, "--storage-run-mounts"],
           []
         ) do
      {:ok, output} ->
        mount = "#{@ssh_host_dir}:#{@container_dir}"

        if String.contains?(output, mount) do
          {:ok, nil}
        else
          {:error, "Private key: mount not configured"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Private key: mount: could not retrieve storage report"}
    end
  end

  defp check_app_network(%App{dokku_host: dokku_host}, target_app) do
    case @root_command.run(
           dokku_host,
           "dokku",
           ["network:report", target_app, "--network-attach-post-deploy"],
           []
         ) do
      {:ok, output} ->
        networks = output |> String.trim() |> String.split(",") |> Enum.map(&String.trim/1)

        if @monitoring_network in networks do
          {:ok, nil}
        else
          {:error, "Network: #{target_app} is not on #{@monitoring_network} network"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Network: could not retrieve network report for #{target_app}"}
    end
  end

  defp check_prometheus_running(%App{dokku_host: dokku_host}) do
    case @commands_ps.report(dokku_host) do
      {:ok, entries} ->
        web_processes =
          Enum.filter(entries, &(&1.app == "prometheus" and &1.process_type == "web"))

        all_running? = Enum.all?(web_processes, &(&1.state == "running"))

        if all_running? do
          {:ok, nil}
        else
          not_running =
            web_processes
            |> Enum.reject(&(&1.state == "running"))
            |> Enum.map(&"web.#{&1.process_index} is #{&1.state}")
            |> Enum.join(", ")

          {:error, "Prometheus running: #{not_running}"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Prometheus running: could not retrieve ps report"}
    end
  end

  defp check_grafana_running(%App{dokku_host: dokku_host}) do
    case @commands_ps.report(dokku_host) do
      {:ok, entries} ->
        web_processes =
          Enum.filter(entries, &(&1.app == "grafana" and &1.process_type == "web"))

        all_running? = Enum.all?(web_processes, &(&1.state == "running"))

        if all_running? do
          {:ok, nil}
        else
          not_running =
            web_processes
            |> Enum.reject(&(&1.state == "running"))
            |> Enum.map(&"web.#{&1.process_index} is #{&1.state}")
            |> Enum.join(", ")

          {:error, "Grafana running: #{not_running}"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Grafana running: could not retrieve ps report"}
    end
  end

  defp check_health_endpoint(%App{dokku_host: dokku_host, dokku_app: dokku_app}) do
    case @root_command.run(
           dokku_host,
           "dokku",
           ["enter", dokku_app, "web", "--", "wget", "-qO-", @health_url],
           []
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
end
