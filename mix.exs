defmodule LoggerBackendEcto.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_backend_ecto,
      version: "1.0.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 2.2"},
      {:sqlite_ecto2, "~> 2.2.4-rc.0", optional: true}
    ]
  end

  defp description, do: "Logger backend for saving logs in an Ecto repo."

  defp package do
    [maintainers: ["Connor Rigby"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/connorrigby/logger_backend_ecto"}]
  end
end
