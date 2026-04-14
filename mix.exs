defmodule Zvex.MixProject do
  use Mix.Project

  def project do
    [
      app: :zvex,
      description: description(),
      package: package(),
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      docs: docs(),
      dialyzer: [
        plt_core_path: "_plts/core"
      ],
      deps: deps(),
      aliases: aliases()
    ]
  end

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

  defp docs do
    benchmark_extras =
      "bench/output/*.md"
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(fn path ->
        name =
          path
          |> Path.basename(".md")
          |> String.replace("_", " ")
          |> String.split()
          |> Enum.map_join(" ", &String.capitalize/1)

        {path, title: name}
      end)

    [
      main: "readme",
      source_url: "https://github.com/edlontech/zvex",
      extras:
        [
          {"README.md", title: "Overview"},
          {"LICENSE", title: "License"}
        ] ++ benchmark_extras,
      groups_for_extras: [
        Benchmarks: ~r/bench\/output\/.+/,
        About: [
          "LICENSE"
        ]
      ],
      groups_for_modules: [
        "Core API": [
          Zvex,
          Zvex.Collection,
          Zvex.Collection.Schema,
          Zvex.Collection.Schema.IndexParams,
          Zvex.Collection.Stats
        ],
        Documents: [
          Zvex.Document,
          Zvex.Vector
        ],
        Search: [
          Zvex.Query,
          Zvex.Query.Result
        ],
        Configuration: [
          Zvex.Application,
          Zvex.Config
        ],
        Types: [
          Zvex.Types
        ],
        Errors: [
          Zvex.Error,
          ~r/Zvex\.Error\./
        ],
        Internal: [
          Zvex.Native
        ]
      ],
      nest_modules_by_prefix: [
        Zvex.Error,
        Zvex.Collection,
        Zvex.Query
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  defp description() do
    "An Elixir Library wrapping the ZVEC Vector Database Engine"
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/edlontech/zvec"},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end
end
