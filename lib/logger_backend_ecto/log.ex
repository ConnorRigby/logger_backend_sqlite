defmodule LoggerBackendEcto.Log do
  @moduledoc false
  use Ecto.Schema

  @default_meta [
    {:application, :string},
    {:module, :string},
    {:function, :string},
    {:file, :string},
    {:line, :integer},
    {:registered_name, :string},
  ]

  schema "elixir_logs" do
    field :level, :string
    field :group_leader_node, :string
    field :message, :string
    field :logged_at_ndt, :naive_datetime
    field :logged_at_dt, :utc_datetime

    for {key, type} <- @default_meta do
      field key, type
    end

    timestamps()
  end
end
