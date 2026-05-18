defmodule Zvex.MixProject do
  use Mix.Project

  # x-release-please-version
  @zvec_version "0.4.0"

  @supported_targets ~w(x86_64-linux-gnu aarch64-linux-gnu aarch64-macos-none)

  # When invoked via `mix zigler_precompiled.download`, the project compile
  # that Mix runs to load the task should emit NIF stubs only — no download,
  # no source build. Setting the env here happens before any project source
  # is compiled. The task itself re-sets this as a belt-and-suspenders.
  if List.first(System.argv()) == "zigler_precompiled.download" do
    System.put_env("ZIGLER_PRECOMPILED_METADATA_ONLY", "true")
  end

  def project do
    use_precompiled = precompiled_available?()

    [
      app: :zvex,
      zvec_version: @zvec_version,
      zvex_use_precompiled: use_precompiled,
      description: description(),
      package: package(),
      version: "0.4.3",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: compilers(use_precompiled),
      make_targets: ["all"],
      make_clean: ["clean"],
      make_env: %{"ZVEX_VERSION" => @zvec_version},
      docs: docs(),
      dialyzer: [
        plt_core_path: "_plts/core",
        plt_add_apps: [:mix]
      ],
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :crypto, :public_key],
      mod: {Zvex.Application, []}
    ]
  end

  defp compilers(true), do: Mix.compilers()
  defp compilers(false), do: [:elixir_make] ++ Mix.compilers()

  defp precompiled_available? do
    case :persistent_term.get({__MODULE__, :precompiled_available?}, :__unset__) do
      :__unset__ ->
        result = compute_precompiled_available?()
        :persistent_term.put({__MODULE__, :precompiled_available?}, result)
        result

      value ->
        value
    end
  end

  defp compute_precompiled_available? do
    cond do
      force_build?() -> false
      current_target_triple() not in @supported_targets -> false
      true -> precompiled_url_reachable?()
    end
  end

  defp force_build?, do: System.get_env("ZVEX_BUILD") in ["1", "true"]

  defp precompiled_url_reachable? do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
    {:ok, _} = Application.ensure_all_started(:public_key)

    url = String.to_charlist(precompiled_url())
    headers = [{~c"user-agent", ~c"zvex-mix"}]

    http_options = [
      {:ssl,
       [
         verify: :verify_peer,
         cacerts: :public_key.cacerts_get(),
         depth: 4,
         customize_hostname_check: [
           match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
         ]
       ]},
      {:connect_timeout, 2000},
      {:timeout, 3000}
    ]

    case :httpc.request(:head, {url, headers}, http_options, []) do
      {:ok, {{_, status, _}, _, _}} when status in [200, 301, 302, 303, 307, 308] -> true
      _ -> false
    end
  end

  defp precompiled_url do
    version = project_version()
    triple = current_target_triple()

    "https://github.com/edlontech/zvex/releases/download/zvex-v#{version}/" <>
      "Elixir.Zvex.Native-v#{version}-#{triple}.so.tar.gz"
  end

  defp project_version do
    case Regex.run(~r/version:\s*"([^"]+)"/, File.read!("mix.exs")) do
      [_, v] -> v
      _ -> raise "could not determine zvex version from mix.exs"
    end
  end

  defp current_target_triple do
    arch_str = :erlang.system_info(:system_architecture) |> List.to_string()

    case :os.type() do
      {:unix, :darwin} ->
        arch = if String.starts_with?(arch_str, ["aarch64", "arm"]), do: "aarch64", else: "x86_64"
        "#{arch}-macos-none"

      {:unix, _} ->
        arch =
          cond do
            String.starts_with?(arch_str, "aarch64") -> "aarch64"
            String.starts_with?(arch_str, "x86_64") -> "x86_64"
            String.starts_with?(arch_str, "amd64") -> "x86_64"
            true -> "unknown"
          end

        "#{arch}-linux-gnu"

      {:win32, _} ->
        "x86_64-windows-gnu"
    end
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
      {:castore, "~> 0.1 or ~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: :dev},
      {:elixir_make, "~> 0.9", optional: true, runtime: false},
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
      {:zigler, "~> 0.15.2", optional: true, runtime: false},
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
      links: %{"GitHub" => "https://github.com/edlontech/zvex"},
      files:
        ~w(lib mix.exs Makefile README.md CHANGELOG.md LICENSE NOTICE .formatter.exs checksum-*.exs),
      exclude_patterns: [~r/\.Elixir\..*\.Native\.zig$/]
    ]
  end
end
