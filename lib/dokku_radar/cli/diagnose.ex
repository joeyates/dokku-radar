defmodule DokkuRadar.CLI.Diagnose do
  alias DokkuRemote.App

  @commands_ps Application.compile_env(
                 :dokku_radar,
                 :"DokkuRemote.Commands.Ps",
                 DokkuRemote.Commands.Ps
               )

  def run(%App{} = app) do
    checks = [
      fn -> check_app_running(app) end
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
end
