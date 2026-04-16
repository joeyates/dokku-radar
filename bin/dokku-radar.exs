#!/usr/bin/env elixir

project_path = __DIR__ |> Path.join("..") |> Path.expand()

Mix.install(
  [
    {:dokku_radar, path: project_path}
  ],
  consolidate_protocols: false,
  start_applications: false
)

DokkuRadar.CLI.run(System.argv())
