import Config

config :logger, :default_handler, level: :debug

config :logger, :default_formatter, format: "$time $message\n", metadata: [:mfa]

import_config "#{config_env()}.exs"
