defmodule DokkuRadar.CLI do
  alias __MODULE__.Diagnose
  alias __MODULE__.Setup
  alias DokkuRemote.App

  @commands [
    %{
      commands: ["diagnose"],
      description: "Run diagnostic checks against a live deployment",
      switches: [
        private_key: %{
          type: :string,
          required: true,
          description: "The path to the private key file to use for SSH authentication with Dokku"
        }
      ]
    },
    %{
      commands: ["setup"],
      description: "Set up the Dokku app, plus Prometheus and Grafana",
      switches: [
        admin_email: %{
          type: :string,
          required: true,
          description: "The email address to use for Let's Encrypt registration"
        },
        grafana_domain: %{
          type: :string,
          required: true,
          description: "The Grafana domain to set up, e.g. 'grafana.example.com'"
        },
        private_key: %{
          type: :string,
          required: true,
          description: "The path to the private key file to use for SSH authentication with Dokku"
        }
      ]
    }
  ]

  def run(args) do
    case HelpfulOptions.parse_commands(args, @commands) do
      {:ok, %{commands: ["diagnose"], switches: switches}} ->
        private_key = Map.fetch!(switches, :private_key)
        %App{} = dokku_radar_app = dokku_radar_app_fom_env!(switches)
        :ok = Diagnose.run(dokku_radar_app, private_key)

      {:ok, %{commands: ["setup"], switches: switches}} ->
        admin_email = Map.fetch!(switches, :admin_email)
        grafana_domain = Map.fetch!(switches, :grafana_domain)
        private_key = Map.fetch!(switches, :private_key)
        %App{} = dokku_radar_app = dokku_radar_app_fom_env!(switches)
        :ok = Setup.run(dokku_radar_app, admin_email, grafana_domain, private_key)
    end
  end

  defp dokku_radar_app_fom_env!(opts) do
    verbose = Map.get(opts, :verbose, false)
    dokku_host = System.fetch_env!("DOKKU_HOST")
    dokku_app = System.fetch_env!("DOKKU_APP")
    %App{dokku_host: dokku_host, dokku_app: dokku_app, verbose: verbose}
  end
end
