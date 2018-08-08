# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config
config :logger_backend_ecto, ecto_repos: [LoggerBackendEcto.Repo]
config :logger, [
  utc_log: true,
  handle_otp_reports: true,
  handle_sasl_reports: true
]

config :logger_backend_ecto, LoggerBackendEcto.Repo, [
  adapter: Sqlite.Ecto2,
  database: "elixir_logs.sqlite3"
]
