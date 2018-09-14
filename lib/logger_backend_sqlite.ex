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

  defstruct [
    :dbname,
    :db,
    :insert_stmt,
    :delete_stmt,
    :max_logs,
    :trim_amount,
    :trim_frequency,
    :timer
  ]

  @opaque db :: {:connection, reference(), reference()}
  @opaque stmt :: {:statement, reference(), db}

  @type uninitialized() :: %__MODULE__{
          dbname: charlist(),
          max_logs: pos_integer(),
          trim_amount: pos_integer(),
          trim_frequency: pos_integer(),
          db: nil,
          insert_stmt: nil,
          delete_stmt: nil,
          timer: nil
        }

  @type initialized :: %__MODULE__{
          db: db(),
          insert_stmt: stmt(),
          delete_stmt: stmt(),
          dbname: charlist(),
          max_logs: pos_integer(),
          trim_amount: pos_integer(),
          trim_frequency: pos_integer(),
          timer: reference()
        }

  @type log :: Log.t()

  alias __MODULE__, as: State
  @behaviour :gen_event

  @doc "Counts every log in the database."
  @spec count_logs() :: 0 | pos_integer
  def count_logs(),
    do: :gen_event.call(Logger, LoggerBackendSqlite, :count_all_logs, :infinity)

  @doc "Returns all logs."
  @spec all_logs() :: [log]
  def all_logs(),
    do: :gen_event.call(Logger, LoggerBackendSqlite, :get_all_logs, :infinity)

  @doc "Returns a File.Stat of the database, or :memory if not backed by file."
  @spec stat() :: :memory | File.Stat.t()
  def stat(),
    do: :gen_event.call(Logger, LoggerBackendSqlite, :stat, :infinity)

  @doc false
  def get_state(),
    do: :gen_event.call(Logger, LoggerBackendSqlite, :get_state, :infinity)

  @impl :gen_event
  @spec init(LoggerBackendSqlite | {LoggerBackendSqlite, keyword()}) :: {:ok, uninitialized()}
  def init(__MODULE__) do
    init({__MODULE__, []})
  end

  @impl :gen_event
  def init({__MODULE__, opts}) when is_list(opts) do
    env = Application.get_env(:logger, __MODULE__, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, __MODULE__, opts)
    send(self(), {:configure, opts})
    # Pretty much a noop. handle_info({:configure, _}, state)
    # Does this again.
    state = extract_opts(opts)
    {:ok, state}
  end

  @impl :gen_event

  def handle_call(_, %State{db: nil} = state) do
    {:ok, {:error, :uniinitialized}, state}
  end

  # Must complete in 5000 ms.
  def handle_call({:configure, opts}, %State{} = state) do
    env = Application.get_env(:logger, __MODULE__, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, __MODULE__, opts)
    send(self(), {:configure, opts})
    {:ok, :ok, state}
  end

  # :infinity timeout.
  def handle_call(:get_all_logs, %State{db: db} = state) do
    reply = :esqlite3.map(&to_log/1, 'select * from elixir_logs', db)
    {:ok, reply, state}
  end

  # :infinity timeout.
  def handle_call(:count_all_logs, state) do
    {:ok, do_count(state), state}
  end

  # :infinity timeout.
  def handle_call(:stat, %State{dbname: ':memory:'} = state) do
    {:ok, :memory, state}
  end

  # :infinity timeout.
  def handle_call(:stat, %State{dbname: name} = state) do
    {:ok, File.stat!(name), state}
  end

  # :infinity timeout. (debug)
  def handle_call(:get_state, state), do: {:ok, state, state}

  @impl :gen_event
  # Ignore events when state is uninitialized.
  def handle_event(_, %State{db: nil} = state) do
    # TODO(Connor) - Buffer events when db is not init?
    {:ok, state}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  @impl :gen_event
  def handle_event({level, gl, {Logger, iodata, {{yr, m, d}, {hr, min, sec, _}}, meta}}, state) do
    utc? = Application.get_env(:logger, :utc_log, false)
    ndt = %NaiveDateTime{year: yr, month: m, day: d, minute: min, second: sec, hour: hr}
    {:ok, dt} = DateTime.from_naive(ndt, "Etc/UTC")

    do_insert = fn ->
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
          Logger.warn(["Failed to insert log into sqlite: ", Exception.message(ex)], store: false)

          {:ok, state}
      end
    end

    if Keyword.get(meta, :store, true) do
      do_insert.()
    else
      {:ok, state}
    end
  end

  @impl :gen_event
  # only configure if db is initialized
  def handle_info({:configure, opts}, %State{db: nil} = _uninitialized_state) do
    state = extract_opts(opts)
    {:ok, init_db(state)}
  end

  def handle_info({:configure, opts}, %State{dbname: old_name} = old_state) do
    _noop_state = close_db(old_state)
    %State{dbname: new_name} = new_state = extract_opts(opts)
    File.exists?(old_name) && new_name != ':memory:' && File.cp(old_name, new_name)
    {:ok, init_db(new_state)}
  end

  def handle_info(:max_logs_checkup, %State{max_logs: max_logs, trim_frequency: freq} = state) do
    case do_count(state) do
      count when count >= max_logs ->
        Logger.debug("trimming #{state.trim_amount} logs from LoggerBackendSqlite", store: false)
        do_trim(state)
        new_count = do_count(state)

        msg = [
          to_string(count - new_count),
          " logs trimmed from LoggerBackendSqlite ",
          to_string(new_count),
          " remaining."
        ]

        Logger.debug(msg, store: false)
        {:ok, %State{state | timer: start_timer(self(), freq)}}

      _ ->
        {:ok, %State{state | timer: start_timer(self(), freq)}}
    end
  end

  def handle_info(_, state), do: {:ok, state}

  @impl :gen_event
  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  @impl :gen_event
  def terminate(_reason, %State{} = state) do
    _state = close_db(state)
    :ok
  end

  defp start_timer(pid, timeoutms) do
    Process.send_after(pid, :max_logs_checkup, timeoutms)
  end

  @spec extract_opts(Keyword.t()) :: uninitialized()
  defp extract_opts(opts) do
    # Collect default opts.
    dbname = Keyword.get(opts, :database, ':memory:') |> to_charlist()
    max_logs = Keyword.get(opts, :max_logs, 1000)
    trim_amount = Keyword.get(opts, :trim_amount, max_logs / 4)
    trim_frequency = Keyword.get(opts, :trim_frequencey, 30_000)

    %State{
      dbname: dbname,
      trim_amount: round(trim_amount),
      trim_frequency: trim_frequency,
      max_logs: max_logs
    }
  end

  @spec init_db(uninitialized()) :: initialized()
  defp init_db(%State{} = state) do
    create =
      'CREATE TABLE IF NOT EXISTS "elixir_logs" ("id" INTEGER PRIMARY KEY, "level" ' ++
        'TEXT, "group_leader_node" TEXT, "message" TEXT, "logged_at_ndt" ' ++
        'NAIVE_DATETIME, "logged_at_dt" UTC_DATETIME, "application" TEXT, ' ++
        '"module" TEXT, "function" TEXT, "file" TEXT, "line" INTEGER, "registered_name" ' ++
        'TEXT, "inserted_at" NAIVE_DATETIME NOT NULL, "updated_at" NAIVE_DATETIME NOT NULL)'

    # Open and setup db.
    {:ok, db} = :esqlite3.open(state.dbname)
    :ok = :esqlite3.exec(create, db)

    # Insert statement for teh speedz.
    insert =
      'insert into elixir_logs values(' ++
        '?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14' ++ ')'

    delete =
      'DELETE FROM elixir_logs WHERE id IN (' ++
        'SELECT id FROM elixir_logs ORDER BY id ASC LIMIT ?1' ++ ')'

    {:ok, insert_stmt} = :esqlite3.prepare(insert, db)
    {:ok, delete_stmt} = :esqlite3.prepare(delete, db)

    %State{
      state
      | db: db,
        insert_stmt: insert_stmt,
        delete_stmt: delete_stmt,
        timer: start_timer(self(), 0)
    }
  end

  @spec close_db(initialized()) :: uninitialized()
  defp close_db(%State{} = state) do
    :esqlite3.close(state.db)
    state.timer && Process.cancel_timer(state.timer)
    %State{state | db: nil, delete_stmt: nil, insert_stmt: nil, timer: nil}
  end

  @spec insert_log(log(), initialized()) :: :ok
  defp insert_log(%Log{} = log, %State{insert_stmt: stmt}) do
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
    :ok
  end

  @spec do_count(initialized()) :: 0 | pos_integer()
  defp do_count(%State{db: db}) do
    [{count}] = :esqlite3.q('select count(*) from elixir_logs', db)
    count
  end

  @spec do_trim(initialized()) :: :ok
  defp do_trim(%State{trim_amount: amount, delete_stmt: stmt}) do
    :ok = :esqlite3.bind(stmt, [amount])
    :"$done" = :esqlite3.step(stmt, :infinity)
    :ok
  end

  @spec to_log(tuple()) :: log()
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

  defp do_update_log_meta({:application, value}, log), do: %{log | application: to_string(value)}
  defp do_update_log_meta({:module, value}, log), do: %{log | application: to_string(value)}
  defp do_update_log_meta({:function, value}, log), do: %{log | application: to_string(value)}
  defp do_update_log_meta({:file, value}, log), do: %{log | application: to_string(value)}

  defp do_update_log_meta({:line, value}, log) when is_integer(value),
    do: %{log | application: value}

  defp do_update_log_meta({:registered_name, value}, log),
    do: %{log | application: to_string(value)}

  defp do_update_log_meta({_k, _v}, log), do: log
end
