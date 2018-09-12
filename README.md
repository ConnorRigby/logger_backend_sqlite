# LoggerBackendSqlite

## What is it?
LoggerBackendSqlite will allow you to save all of your logs to an sqlite3 database.

## Why is it?
This is very helpful for [Nerves](https://nerves-project.org) devices which
don't always have network access, or console access.

## Usage is it?

Add logger backend ecto to your deps:

```elixir
def deps do
  [
    {:logger_backend_sqlite, "~> 2.0"},
  ]
end
```

Configure `:logger`:

```elixir
use Mix.Config

config :logger, [
  utc_log: true,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  backends: [:console, LoggerBackendSqlite]
]

config :logger, LoggerBackendSqlite,
  database: 'debug_logs.sqlite3',
  max_logs: 9000, # defaults to 1000
  trim_amnt: 3000 # defaults to 25% of `max_logs`
```

You can also add the backend at runtime.

```elixir
iex()> {:ok, _} = Logger.add_backend(LoggerBackendSqlite)
iex()> :ok = Logger.configure_backend(LoggerBackendSqlite, database: ":memory:", max_logs: 20)
```

Seeing logs:

```elixir
iex(1)> require Logger
Logger
iex(2)> Logger.debug "hey!!"
:ok
iex(3)> 
01:33:16.341 [debug] hey!!
iex(4)> LoggerBackendSqlite.all_logs                                                           
[
  %LoggerBackendSqlite.Log{
    application: nil,
    file: "iex",
    function: nil,
    group_leader_node: "nonode@nohost",
    id: 1,
    inserted_at: "2018-09-12 01:33:16.341631",
    level: "debug",
    line: 8,
    logged_at_dt: "2018-09-12 01:33:16Z",
    logged_at_ndt: "2018-09-12 01:33:16",
    message: "hey!!",
    module: nil,
    registered_name: nil,
    updated_at: "2018-09-12 01:33:16.341661"
  }
]
```

## Why 2.0 is it?
This is a hard fork of [logger_backend_ecto](https://github.com/ConnorRigby/logger_backend_ecto). 
It is 1.0, and I didn't want any confusion that these are not the same thing, even
tho they share the same public API. 