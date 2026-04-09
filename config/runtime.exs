import Config

config :dokku_radar, port: "PORT" |> System.get_env("9110") |> String.to_integer()
