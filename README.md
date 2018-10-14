# LoggerBackendSqlite
[![CircleCI](https://circleci.com/gh/ConnorRigby/logger_backend_sqlite.svg?style=svg)](https://circleci.com/gh/ConnorRigby/logger_backend_sqlite)
[![Hex version](https://img.shields.io/hexpm/v/logger_backend_sqlite.svg "Hex version")](https://hex.pm/packages/logger_backend_sqlite)

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

## Nerves is it?
Using this on Nerves is pretty straightforward, but there is a gotcha.
Nerves devices use a read only filesystem, so you need to ensure you store
the database on a writable filesystem. You have two options.

### /tmp
`/tmp` is read write, but will be cleared _every_ boot and has a pretty
small size constraint. This can be useful if you only want a few logs from
a specific time.

### /root
`/root` is the default location for your application data. There is another
gotcha on this one, that on first boot, this partition will not be ready yet.
A simple work can be found below:

in your config.exs
```elixir
  use Mix.Config
  config :logger, LoggerBackendSqlite, [
    database: "/tmp/logs.sqlite"
  ]
```

then in your application code somewhere:
```elixir
defmodule MyApp.FileSystemCheckup do
  @database "/root/logs.sqlite"
  @check_file "/root/check"
  require Logger

  def checkup do
    case File.write(@check_file, "any ole data") do
      :ok -> Logger.configure_backend(LoggerBackendSqlite, [database: @database])
      {:error, _} ->
        Logger.warn "Application data partition not ready yet"
        Proess.sleep(2000)
        checkup()
    end
  end
end
```

## Why 2.0 is it?
This is a hard fork of [logger_backend_ecto](https://github.com/ConnorRigby/logger_backend_ecto).
It is 1.0, and I didn't want any confusion that these are not the same thing, even
tho they share the same public API.
