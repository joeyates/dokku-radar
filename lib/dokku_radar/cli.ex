defmodule DokkuRadar.CLI do
  alias __MODULE__.Setup
  alias DokkuRemote.AppCommand

  @commands [
    %{
      commands: ["setup"],
      description: "Set up the Dokku app, plus Prometheus and Grafana"
    }
  ]

  def run(args) do
    case HelpfulOptions.parse_commands(args, @commands) do
      {:ok, %{commands: ["setup"], switches: switches}} ->
        %AppCommand{} = dokku_remote_app = dokku_remote_app_fom_env!(switches)
        :ok = Setup.run(dokku_remote_app)
    end

    System.halt(0)
  end

  defp dokku_remote_app_fom_env!(opts) do
    verbose = Map.get(opts, :verbose, false)
    dokku_host = System.fetch_env!("DOKKU_HOST")
    dokku_app = System.fetch_env!("DOKKU_APP")
    %AppCommand{dokku_host: dokku_host, dokku_app: dokku_app, verbose: verbose}
  end
end
