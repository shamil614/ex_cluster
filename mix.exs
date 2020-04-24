defmodule ExCluster.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :ex_cluster,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExCluster.Application, []}
    ]
  end

  defp aliases() do
    [
      test: "test --no-start"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:horde, "~> 0.7.1"},
      {:libcluster, "~> 3.2.0"},
      {:local_cluster, "~> 1.1", only: [:test]}
    ]
  end
end
