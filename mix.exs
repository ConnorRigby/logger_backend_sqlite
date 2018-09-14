defmodule LoggerBackendSqlite.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_backend_sqlite,
      version: "2.1.0",
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
      {:esqlite, "~> 0.2.4"},
      {:dialyxir, "1.0.0-rc.3", runtime: false, only: [:dev, :test]},
      {:ex_doc, "~> 0.19", runtime: false, only: :docs}
    ]
  end

  defp description, do: "Logger backend for saving logs in an sqlite3 database."

  defp package do
    [
      maintainers: ["Connor Rigby"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/connorrigby/logger_backend_sqlite"}
    ]
  end
end
