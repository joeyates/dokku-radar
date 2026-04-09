defmodule DokkuRadar.MixProject do
  use Mix.Project

  def project() do
    [
      app: :dokku_radar,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application() do
    [
      extra_applications: [:logger],
      mod: {DokkuRadar.Application, []}
    ]
  end

  defp deps() do
    [
      {:bandit, "~> 1.0"},
      {:green, "~> 0.1.11", only: :dev},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.16"},
      {:req, "~> 0.5.17"}
    ]
  end
end
