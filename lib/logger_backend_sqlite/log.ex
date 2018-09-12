defmodule LoggerBackendSqlite.Log do
  @moduledoc false

  @default_meta [
    :application,
    :module,
    :function,
    :file,
    :line,
    :registered_name
  ]

  defstruct [
              :id,
              :level,
              :group_leader_node,
              :message,
              :logged_at_ndt,
              :logged_at_dt,
              :inserted_at,
              :updated_at
            ] ++ @default_meta

  @type t :: %__MODULE__{
          id: 0 | pos_integer(),
          level: String.t(),
          group_leader_node: nil | String.t(),
          message: String.t(),
          logged_at_ndt: nil | NaiveDateTime.t(),
          logged_at_dt: nil | DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          application: nil | String.t(),
          module: nil | String.t(),
          function: nil | String.t(),
          file: nil | Path.t(),
          line: nil | pos_integer(),
          registered_name: nil | String.t()
        }
end
