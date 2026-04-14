defmodule Zvex.MixProject do
  use Mix.Project

  def project do
    [
      app: :zvex,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Zvex.Application, []}
    ]
  end

  defp aliases do
    [
      "bench.vector": ["run bench/vector_bench.exs"],
      "bench.document": ["run bench/document_bench.exs"],
      "bench.collection": ["run bench/collection_bench.exs"],
      "bench.query": ["run bench/query_bench.exs"],
      "bench.all": [
        "bench.vector",
        "bench.document",
        "bench.collection",
        "bench.query"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8", only: :dev, runtime: false},
      {:benchee, "~> 1.0", only: :dev},
      {:benchee_markdown, "~> 0.3", only: :dev},
      {:benchee_json, "~> 1.0", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: :dev},
      {:elixir_make, "~> 0.9", runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:assert_eventually, "~> 1.0", only: :test},
      {:mimic, "~> 2.0", only: :test},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:recode, "~> 0.8", only: [:dev], runtime: false},
      {:splode, "~> 0.3"},
      {:telemetry, "~> 1.3"},
      {:tidewave, "~> 0.5", only: :dev, runtime: false},
      {:zigler, "~> 0.15.2", runtime: false},
      {:zoi, "~> 0.11"}
    ]
  end
end
