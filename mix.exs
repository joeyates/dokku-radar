defmodule DokkuRadar.MixProject do
  use Mix.Project

  def project() do
    [
      app: :dokku_radar,
      version: "0.1.4",
      elixir: "~> 1.18",
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      start_permanent: Mix.env() == :prod
    ]
  end

  def application() do
    application(Mix.env())
  end

  def application(:test), do: []

  def application(_env) do
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
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dokku_remote, ">= 0.0.0", path: "../dokku_remote"},
      {:green, "~> 0.1.11", only: :dev},
      {:helpful_options, "~> 0.4.4", path: "../helpful_options"},
      {:jason, "~> 1.4"},
      {:mox, "~> 1.0", only: :test},
      {:plug, "~> 1.16"},
      {:req, "~> 0.5.17"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
