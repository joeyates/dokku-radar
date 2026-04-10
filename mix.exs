defmodule DokkuRadar.MixProject do
  use Mix.Project

  def project() do
    [
      app: :dokku_radar,
      version: "0.1.3",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application() do
    [
      extra_applications: [:logger],
      mod: {DokkuRadar.Application, []}
    ]
  end

  defp aliases() do
    [
      "check-formatted": ["format --check-formatted"]
    ]
  end

  defp deps() do
    [
      {:bandit, "~> 1.0"},
      {:green, "~> 0.1.11", only: :dev},
      {:jason, "~> 1.4"},
      {:mox, "~> 1.0", only: :test},
      {:plug, "~> 1.16"},
      {:req, "~> 0.5.17"}
    ]
  end
end
