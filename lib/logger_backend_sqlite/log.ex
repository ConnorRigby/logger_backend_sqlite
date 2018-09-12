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
end
