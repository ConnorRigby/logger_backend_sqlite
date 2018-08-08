defmodule LoggerBackendEcto.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :logger_backend_ecto,
    loggers: []
end
