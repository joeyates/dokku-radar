import Config

config :logger, :default_handler, level: :debug

config :logger, :default_formatter, format: "$time $message $metadata"

import_config "#{config_env()}.exs"
