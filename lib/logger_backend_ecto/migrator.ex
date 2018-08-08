defmodule LoggerBackendEcto.Migrator do
  @moduledoc false
  def migrate do
    repo = LoggerBackendEcto.Repo
    repo_ = Module.split(repo) |> List.last() |> Macro.underscore() |> to_string()
    otp_app = :code.priv_dir(:logger_backend_ecto)
    migrations_path = Path.join([to_string(otp_app), repo_, "migrations"])
    opts = [all: true, log: :debug]
    migrator = &Ecto.Migrator.run/4
    migrator.(repo, migrations_path, :up, opts)
  end
end
