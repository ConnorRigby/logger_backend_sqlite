defmodule LoggerBackendEcto do
  @moduledoc """
  Logger backend for saving log data into a Ecto Repo.

  ## Usage
  {:ok, _} = Logger.add_backend(LoggerBackendEcto)
  require Logger
  Logger.info "hello, world"
  Logger.remove_backend(LoggerBackendEcto)
  """

  alias LoggerBackendEcto.{Log, Repo}
  @behaviour :gen_event

  @default_meta [
    {:application, :string},
    {:module, :string},
    {:function, :string},
    {:file, :string},
    {:line, :integer},
    {:registered_name, :string},
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
    {:ok, pid} = Repo.start_link()
    LoggerBackendEcto.Migrator.migrate()
    {:ok, %{repo: pid}}
  rescue
    ex -> {:error, ex}
  end

  @impl :gen_event
  def handle_call({:configure, opts}, state) do
    env = Application.get_env(:logger, __MODULE__, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, __MODULE__, opts)
    {:ok, :ok, state}
  end

  @impl :gen_event
  def handle_event(:flush, state) do
    {:ok, state}
  end

  @impl :gen_event
  def handle_event({level, gl, {Logger, text, {{yr, m, d}, {hr, min, sec, _}}, meta}}, state) do
    utc? = Application.get_env(:logger, :utc_log, false)
    ndt = %NaiveDateTime{year: yr, month: m, day: d, minute: min, second: sec, hour: hr}
    {:ok, dt} = DateTime.from_naive(ndt, "Etc/UTC")

    %Log{
      group_leader_node: to_string(node(gl)),
      level: to_string(level),
      logged_at_ndt: ndt,
      logged_at_dt: if(utc?, do: dt),
      message: to_string(text)
    }
    |> update_meta(meta)
    |> Repo.insert!()
    {:ok, state}
  end

  @impl :gen_event
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @impl :gen_event
  def terminate(_reason, state) do
    Repo.stop(state.repo)
    :ok
  end

  defp update_meta(log, meta) do
    Enum.reduce(meta, log, &do_update_meta/2)
  end

  defp do_update_meta({_key, nil}, log), do: log

  for {key, type} <- @default_meta do
    defp do_update_meta({unquote(key), value}, log) do
      case unquote(type) do
        :string ->  %{log | unquote(key) => to_string(value)}
        :integer when is_integer(value) -> %{log | unquote(key) => value}
      end
    end
  end

  defp do_update_meta({_k, _v}, log), do: log
end
