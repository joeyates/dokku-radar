defmodule DokkuRadar.CLI.Diagnose do
  alias DokkuRemote.App

  @ssh_host_dir "/var/lib/dokku/data/storage/dokku-radar/.ssh"
  @container_dir "/data/.ssh"
  @private_key_path "#{@ssh_host_dir}/id_ed25519"

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
    checks = [
      fn -> check_app_running(app) end,
      fn -> check_private_key_mount(app) end,
      fn -> check_private_key_file(app) end
    ]

    Enum.each(checks, fn check ->
      case check.() do
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
          {:ok, "App running"}
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
          {:ok, "Private key: mount"}
        else
          {:error, "Private key: mount not configured"}
        end

      {:error, _output, _exit_code} ->
        {:error, "Private key: mount: could not retrieve storage report"}
    end
  end

  defp check_private_key_file(%App{dokku_host: dokku_host}) do
    case @root_command.run(dokku_host, "test", ["-f", @private_key_path], []) do
      {:ok, _output} ->
        {:ok, "Private key: file"}

      {:error, _output, _exit_code} ->
        {:error, "Private key: file not found at #{@private_key_path}"}
    end
  end
end
