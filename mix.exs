defmodule Zvex.MixProject do
  use Mix.Project

  # x-release-please-version
  @zvec_version "0.4.0"
  @sentinel ".zvex_precompiled"
  @manifest_vsn 1

  def project do
    [
      app: :zvex,
      zvec_version: @zvec_version,
      description: description(),
      package: package(),
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:zvex_precompiled, :elixir_make] ++ Mix.compilers(),
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
      "compile.zvex_precompiled": &precompiled/1,
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
      files: ~w(lib mix.exs Makefile README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp precompiled(_args) do
    cond do
      System.get_env("ZVEX_BUILD") == "true" ->
        Mix.shell().info("[zvex] ZVEX_BUILD=true — skipping precompiled download")
        {:noop, []}

      true ->
        case detect_target() do
          {:ok, target} ->
            fetch_precompiled(target)
            {:ok, []}

          :unsupported ->
            Mix.shell().info(
              "[zvex] no precompiled binary for this target — building from source " <>
                "(requires c_src/zvec submodule and a working toolchain)"
            )

            {:noop, []}
        end
    end
  end

  defp fetch_precompiled(target) do
    version = @zvec_version
    cache_dir = Path.join([cache_root(), version, target])
    tarball = Path.join(cache_dir, "zvec-v#{version}-#{target}.tar.gz")
    sha_file = tarball <> ".sha256"

    File.mkdir_p!(cache_dir)

    unless sentinel_valid?(version, target) do
      unless File.exists?(tarball) and File.exists?(sha_file) do
        download!(url(version, target), tarball)
        download!(url(version, target) <> ".sha256", sha_file)
      end

      verify_sha256!(tarball, sha_file)
      wipe_priv()
      extract!(tarball, priv_dir())
      write_sentinel(version, target)
    end
  end

  defp cache_root do
    :user_cache |> :filename.basedir(~c"zvex") |> to_string()
  end

  defp priv_dir do
    Path.join(Mix.Project.app_path(), "priv")
  end

  defp url(version, target) do
    prefix =
      System.get_env("ZVEX_BUILD_URL") ||
        "https://github.com/edlontech/zvex/releases/download"

    "#{String.trim_trailing(prefix, "/")}/zvec-v#{version}/zvec-v#{version}-#{target}.tar.gz"
  end

  defp detect_target do
    :system_architecture
    |> :erlang.system_info()
    |> to_string()
    |> normalize_architecture()
  end

  defp normalize_architecture("x86_64-" <> rest), do: classify(rest, "x86_64")
  defp normalize_architecture("aarch64-" <> rest), do: classify(rest, "aarch64")
  defp normalize_architecture("arm64-" <> rest), do: classify(rest, "aarch64")
  defp normalize_architecture(_other), do: :unsupported

  defp classify(rest, arch) do
    cond do
      String.contains?(rest, "linux-musl") ->
        :unsupported

      String.contains?(rest, "linux-gnu") or String.contains?(rest, "linux") ->
        {:ok, "linux-#{arch}-gnu"}

      String.contains?(rest, "apple-darwin") and arch == "aarch64" ->
        {:ok, "darwin-aarch64"}

      true ->
        :unsupported
    end
  end

  defp download!(url, dest) do
    Mix.shell().info("[zvex] downloading #{url}")
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    request = {String.to_charlist(url), []}
    http_opts = [ssl: [verify: :verify_peer, cacerts: :public_key.cacerts_get()]]
    opts = [stream: String.to_charlist(dest)]

    case :httpc.request(:get, request, http_opts, opts) do
      {:ok, :saved_to_file} ->
        :ok

      {:ok, {{_, status, _}, _, _}} ->
        File.rm(dest)

        Mix.raise(
          "[zvex] download failed (HTTP #{status}) for #{url}. " <>
            "Re-run the release workflow or set ZVEX_BUILD=true to build from source."
        )

      {:error, reason} ->
        File.rm(dest)

        Mix.raise(
          "[zvex] download failed for #{url}: #{inspect(reason)}. " <>
            "Set ZVEX_BUILD_URL=<mirror> or ZVEX_BUILD=true."
        )
    end
  end

  defp verify_sha256!(tarball, sha_file) do
    expected =
      sha_file
      |> File.read!()
      |> String.split(~r/\s+/, trim: true)
      |> List.first()
      |> String.downcase()

    actual =
      tarball
      |> File.read!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    if actual != expected do
      File.rm(tarball)
      File.rm(sha_file)

      Mix.raise(
        "[zvex] checksum mismatch for #{Path.basename(tarball)}. " <>
          "Cache wiped. Retry, or set ZVEX_BUILD=true to build from source."
      )
    end
  end

  defp wipe_priv do
    priv = priv_dir()
    if File.exists?(priv), do: File.rm_rf!(priv)
    File.mkdir_p!(priv)
  end

  defp extract!(tarball, dest) do
    tarball_charlist = String.to_charlist(tarball)

    with {:ok, entries} <- :erl_tar.table(tarball_charlist, [:compressed]),
         :ok <- validate_entries!(entries, tarball),
         :ok <-
           :erl_tar.extract(tarball_charlist, [:compressed, {:cwd, String.to_charlist(dest)}]) do
      :ok
    else
      {:error, reason} ->
        File.rm(tarball)
        Mix.raise("[zvex] failed to extract #{tarball}: #{inspect(reason)}. Cache wiped; retry.")
    end
  end

  defp validate_entries!(entries, tarball) do
    result =
      Enum.reduce_while(entries, :ok, fn entry, :ok ->
        name = to_string(entry)

        cond do
          String.starts_with?(name, "/") -> {:halt, {:unsafe, name}}
          name == ".." or String.contains?(name, "../") -> {:halt, {:unsafe, name}}
          true -> {:cont, :ok}
        end
      end)

    case result do
      :ok ->
        :ok

      {:unsafe, name} ->
        File.rm(tarball)

        Mix.raise(
          "[zvex] tarball #{Path.basename(tarball)} contains unsafe entry path #{inspect(name)}. " <>
            "Cache wiped; set ZVEX_BUILD=true to build from source."
        )
    end
  end

  defp write_sentinel(version, target) do
    File.write!(
      Path.join(priv_dir(), @sentinel),
      "#{@manifest_vsn}\n#{version}\n#{target}\n"
    )
  end

  defp sentinel_valid?(version, target) do
    path = Path.join(priv_dir(), @sentinel)

    with true <- File.exists?(path),
         {:ok, contents} <- File.read(path),
         [vsn, stored_version, stored_target] <- String.split(contents, "\n", trim: true),
         true <- vsn == Integer.to_string(@manifest_vsn),
         true <- stored_version == version,
         true <- stored_target == target,
         true <- File.exists?(Path.join([priv_dir(), "lib", shared_lib()])) do
      true
    else
      _ -> false
    end
  end

  defp shared_lib do
    case :os.type() do
      {:unix, :darwin} -> "libzvec_c_api.dylib"
      _ -> "libzvec_c_api.so"
    end
  end
end
