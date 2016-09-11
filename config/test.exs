use Mix.Config

config :logger, backends: [LoggerMulticastBackend]

config :logger_multicast_backend,
  format: "$metadata[$level] $message\n"