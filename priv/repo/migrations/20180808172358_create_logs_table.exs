defmodule LoggerBackendEcto.Repo.Migrations.CreateLogsTable do
  use Ecto.Migration

  @default_meta [
    {:application, :string},
    {:module, :string},
    {:function, :string},
    {:file, :string},
    {:line, :integer},
    {:registered_name, :string},
  ]

  def change do
    create table("elixir_logs") do
      add :level, :string
      add :group_leader_node, :string
      add :message, :string
      add :logged_at_ndt, :naive_datetime
      add :logged_at_dt, :utc_datetime
      for {key, type} <- @default_meta do
        add key, type
      end
      timestamps()
    end
  end
end
