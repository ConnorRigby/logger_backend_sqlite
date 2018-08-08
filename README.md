# LoggerBackendEcto

## What is it?
LoggerBackendEcto will allow you to save all of your logs to an ecto repo.

## Why is it
This is very helpful for [Nerves](https://nerves-project.org) devices which
don't always have network access, or console access.

## Usage

Add logger backend ecto to your deps:

```elixir
def deps do
  [
    {:logger_backend_sqlite, "~> 1.0"},
    {:sqlite_ecto2, "~> 2.2.4"} # or any other Ecto adapter.
  ]
end
```

Configure `:ecto` and `:logger`:

```elixir
use Mix.Config

config :logger, [
  utc_log: true,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  backends: [:console, LoggerBackendEcto]
]

# This can be any adapter and config.
config :logger_backend_ecto, LoggerBackendEcto.Repo, [
  adapter: Sqlite.Ecto2,
  database: "elixir_logs.sqlite3"
]
```

You can also add the backend at runtime, however make sure the ecto repo
is configured properly.

```elixir
iex()> {:ok, _} = Logger.add_backend(LoggerBackendEcto)
require Logger
Logger.debug "hey!"
```
