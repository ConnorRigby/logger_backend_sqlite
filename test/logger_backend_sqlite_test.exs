defmodule LoggerBackendSqliteTest do
  use ExUnit.Case, async: false
  doctest LoggerBackendSqlite
  require Logger

  setup_all do
    _ = Logger.remove_backend(LoggerBackendSqlite)
    File.rm_rf("test_artifacts")
    :ok
  end

  setup do
    _ = Logger.remove_backend(LoggerBackendSqlite)
    :ok = Application.delete_env(Logger, LoggerBackendSqlite)
    File.mkdir_p("test_artifacts")
    filename = Path.join(["test_artifacts", "#{DateTime.utc_now()}.sqlite"])
    {:ok, filename: filename}
  end

  test "configures db from Mix.Config" do
    filename = "test_artifacts/mix.config.sqlite"
    Application.put_env(:logger, LoggerBackendSqlite, database: filename)
    Logger.add_backend(LoggerBackendSqlite)
    Logger.debug(inspect(__ENV__.function))
    Logger.flush()
    assert File.stat(filename)
  end

  test "configures db at runtime", %{filename: filename} do
    Application.put_env(:logger, LoggerBackendSqlite, database: ":memory:")
    Logger.add_backend(LoggerBackendSqlite)
    Logger.debug(inspect(__ENV__.function))
    Logger.flush()
    assert LoggerBackendSqlite.stat() == :memory
    Logger.configure_backend(LoggerBackendSqlite, database: filename)
    Logger.debug(inspect(__ENV__.function))
    Logger.flush()
    assert File.stat(filename)
  end

  test "reconfigures db at runtime, copies old db", %{filename: filename} do
    Application.put_env(:logger, LoggerBackendSqlite, database: filename)
    Logger.add_backend(LoggerBackendSqlite)
    Logger.debug("important string")
    Logger.flush()

    assert Enum.find(LoggerBackendSqlite.all_logs(), fn %{message: m} ->
             m == "important string"
           end)

    Logger.configure_backend(LoggerBackendSqlite, database: "moved_db.sqlite")

    assert Enum.find(LoggerBackendSqlite.all_logs(), fn %{message: m} ->
             m == "important string"
           end)
  end

  test "stats db", %{filename: filename} do
    Logger.add_backend(LoggerBackendSqlite)
    Logger.configure_backend(LoggerBackendSqlite, database: filename)
    Logger.debug(inspect(__ENV__.function))
    Logger.flush()
    assert File.stat!(filename) == LoggerBackendSqlite.stat()

    Logger.configure_backend(LoggerBackendSqlite, database: ":memory:")
    assert LoggerBackendSqlite.stat() == :memory
  end
end
