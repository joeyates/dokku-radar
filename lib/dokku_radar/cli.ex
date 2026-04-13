defmodule DokkuRadar.CLI do
  alias __MODULE__.Setup

  @commands [
    %{
      commands: ["setup"],
      description: "Set up the Dokku app, plus Prometheus and Grafana"
    }
  ]

  def run(args) do
    case HelpfulOptions.parse_commands(args, @commands) do
      {:ok, %{commands: ["setup"]}} ->
        :ok = Setup.run()
    end

    System.halt(0)
  end
end
