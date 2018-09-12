defmodule LoggerBackendSqlite do
  @moduledoc """
  Logger backend for saving log data into a Ecto Repo.

  ## Usage
  {:ok, _} = Logger.add_backend(LoggerBackendSqlite)
  require Logger
  Logger.info "hello, world"
  Logger.remove_backend(LoggerBackendSqlite)
  """

  require Logger
  alias LoggerBackendSqlite.Log
  defstruct [:dbname, :db, :stmt, :max_logs, :trim_amount, :timer]
  alias __MODULE__, as: State

  @behaviour :gen_event

  @doc "Counts every log in the database."
  def count_logs(),
    do: :gen_event.call(Logger, LoggerBackendSqlite, :count_all_logs, :infinity)

  @doc "Returns all logs."
  def all_logs(),
    do: :gen_event.call(Logger, LoggerBackendSqlite, :get_all_logs, :infinity)

  @doc "Returns a File.Stat of the database, or :memory if not backed by file."
  def stat(),
    do: :gen_event.call(Logger, LoggerBackendSqlite, :stat, :infinity)

  @doc false
  def get_state(),
    do: :gen_event.call(Logger, LoggerBackendSqlite, :get_state, :infinity)

  @default_meta [
    {:application, :string},
    {:module, :string},
    {:function, :string},
    {:file, :string},
    {:line, :integer},
    {:registered_name, :string}
  ]

  @impl :gen_event
  def init(__MODULE__) do
    init({__MODULE__, []})
  end

  @impl :gen_event
  def init({__MODULE__, opts}) when is_list(opts) do
    env = Application.get_env(:logger, __MODULE__, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, __MODULE__, opts)
    state = init_db(opts)
    {:ok, state}
  end

  @impl :gen_event
  def handle_call({:configure, opts}, %State{db: db}) do
    :esqlite3.close(db)
    state = init_db(opts)
    {:ok, :ok, state}
  end

  def handle_call(:get_all_logs, %State{db: db} = state) do
    reply = :esqlite3.map(&to_log/1, 'select * from elixir_logs', db)
    {:ok, reply, state}
  end

  def handle_call(:count_all_logs, state) do
    {:ok, do_count(state), state}
  end

  def handle_call(:stat, %State{dbname: ':memory:'} = state) do
    {:ok, :memory, state}
  end

  def handle_call(:stat, %State{dbname: name} = state) do
    {:ok, File.stat!(name), state}
  end

  def handle_call(:get_state, state), do: {:ok, state, state}

  @impl :gen_event
  def handle_event(:flush, state) do
    {:ok, state}
  end

  @impl :gen_event
  def handle_event({level, gl, {Logger, iodata, {{yr, m, d}, {hr, min, sec, _}}, meta}}, state) do
    utc? = Application.get_env(:logger, :utc_log, false)
    ndt = %NaiveDateTime{year: yr, month: m, day: d, minute: min, second: sec, hour: hr}
    {:ok, dt} = DateTime.from_naive(ndt, "Etc/UTC")

    try do
      %Log{
        message: to_string(iodata),
        group_leader_node: to_string(node(gl)),
        level: to_string(level),
        logged_at_ndt: ndt,
        logged_at_dt: if(utc?, do: dt)
      }
      |> update_log_meta(meta)
      |> insert_log(state)

      {:ok, state}
    rescue
      ex ->
        IO.warn(
          ["Failed to insert log into sqlite: ", Exception.message(ex)],
          System.stacktrace()
        )

        {:ok, state}
    end
  end

  @impl :gen_event
  def handle_info(:max_logs_checkup, %State{max_logs: max_logs} = state) do
    case do_count(state) do
      count when count >= max_logs ->
        IO.puts("trimming #{state.trim_amount} logs from LoggerBackendSqlite")
        do_trim(state)
        {:ok, %State{state | timer: start_timer(self())}}

      _ ->
        {:ok, %State{state | timer: start_timer(self())}}
    end
  end

  def handle_info(_, state), do: {:ok, state}

  @impl :gen_event
  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  @impl :gen_event
  def terminate(_reason, %State{db: db}) do
    :esqlite3.close(db)
    :ok
  end

  defp start_timer(pid, timeoutms \\ 30_000) do
    Process.send_after(pid, :max_logs_checkup, timeoutms)
  end

  defp init_db(opts) do
    create =
    'CREATE TABLE IF NOT EXISTS "elixir_logs" ("id" INTEGER PRIMARY KEY, "level" ' ++
      'TEXT, "group_leader_node" TEXT, "message" TEXT, "logged_at_ndt" ' ++
      'NAIVE_DATETIME, "logged_at_dt" UTC_DATETIME, "application" TEXT, ' ++
      '"module" TEXT, "function" TEXT, "file" TEXT, "line" INTEGER, "registered_name" ' ++
      'TEXT, "inserted_at" NAIVE_DATETIME NOT NULL, "updated_at" NAIVE_DATETIME NOT NULL)'

    # Collect default opts.
    dbname = Keyword.get(opts, :database, ':memory:')
    max_logs = Keyword.get(opts, :max_logs, 1000)
    trim_amount = Keyword.get(opts, :trim_amount, max_logs / 4)

    # Open and setup db.
    {:ok, db} = :esqlite3.open(to_charlist(dbname))
    :ok = :esqlite3.exec(create, db)

    # Insert statement for teh speedz.
    insert =
      'insert into elixir_logs values(' ++
        '?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14' ++ ')'

    {:ok, stmt} = :esqlite3.prepare(insert, db)
    %State{
      db: db,
      dbname: dbname,
      stmt: stmt,
      timer: start_timer(self(), 0),
      trim_amount: round(trim_amount),
      max_logs: max_logs
    }
  end

  defp insert_log(%Log{} = log, %State{stmt: stmt}) do
    :ok =
      :esqlite3.bind(stmt, [
        # id 
        :undefined,
        log.level || :undefined,
        log.group_leader_node || :undefined,
        log.message || :undefined,
        (log.logged_at_ndt && to_string(log.logged_at_ndt)) || :undefined,
        (log.logged_at_dt && to_string(log.logged_at_dt)) || :undefined,
        log.application || :undefined,
        log.module || :undefined,
        log.function || :undefined,
        log.file || :undefined,
        log.line || :undefined,
        log.registered_name || :undefined,
        to_string(NaiveDateTime.utc_now()),
        to_string(NaiveDateTime.utc_now())
      ])

    :"$done" = :esqlite3.step(stmt)
  end

  defp do_count(state) do
    [{count}] = :esqlite3.q('select count(*) from elixir_logs', state.db)
    count
  end

  defp do_trim(%State{db: db, trim_amount: amount}) do
    # SQL injection lol
    q =
      'DELETE FROM elixir_logs WHERE id IN ' ++
        '(SELECT id FROM elixir_logs ORDER BY id ASC LIMIT #{amount})'

    :ok = :esqlite3.exec(q, db)
  end

  defp to_log(log) when tuple_size(log) == 14 do
    %{
      id: elem(log, 0),
      level: elem(log, 1),
      group_leader_node: elem(log, 2),
      message: elem(log, 3),
      logged_at_ndt: elem(log, 4),
      logged_at_dt: elem(log, 5),
      application: elem(log, 6),
      module: elem(log, 7),
      function: elem(log, 8),
      file: elem(log, 9),
      line: elem(log, 10),
      registered_name: elem(log, 11),
      inserted_at: elem(log, 12),
      updated_at: elem(log, 13)
    }
    |> Map.new(&undefined_to_nil/1)
    |> (fn data -> struct(Log, data) end).()
  end

  defp undefined_to_nil({key, :undefined}), do: {key, nil}
  defp undefined_to_nil({key, val}), do: {key, val}

  defp update_log_meta(log, meta) do
    Enum.reduce(meta, log, &do_update_log_meta/2)
  end

  defp do_update_log_meta({_key, nil}, log), do: log

  for {key, type} <- @default_meta do
    defp do_update_log_meta({unquote(key), value}, log) do
      case unquote(type) do
        :string -> %{log | unquote(key) => to_string(value)}
        :integer when is_integer(value) -> %{log | unquote(key) => value}
      end
    end
  end

  defp do_update_log_meta({_k, _v}, log), do: log
end
