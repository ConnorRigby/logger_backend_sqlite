# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  backends: [:console, LoggerBackendSqlite],
  utc_log: true,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :logger, LoggerBackendSqlite,
  database: 'debug_logs.sqlite3',
  max_logs: 1000,
  trim_amnt: round(1000 / 4)
