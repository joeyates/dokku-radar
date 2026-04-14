defmodule DokkuRadar.CLI.Setup do
  alias DokkuRemote.AppCommand

  def run(%AppCommand{} = dokku_remote_app) do
    :ok = ensure_app_exists(dokku_remote_app)
  end

  defp ensure_app_exists(%AppCommand{} = app_command) do
    IO.puts("Checking the Dokku app #{inspect(app_command.dokku_app)} exists...")
    exists = DokkuRemote.Commands.Apps.App.exists?(app_command)

    if exists do
      IO.puts("\t✅ App exists")
    else
      IO.puts("The Dokku app #{inspect(app_command.dokku_app)} does not exist, creating...")

      case DokkuRemote.Commands.Apps.App.create(app_command) do
        :ok ->
          IO.puts("\t✅ App created")

        {:error, output, exit} ->
          raise "Failed to create app, exit code #{exit}: #{output}"
      end
    end

    :ok
  end
end
