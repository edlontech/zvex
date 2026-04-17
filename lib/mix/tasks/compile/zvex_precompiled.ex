defmodule Mix.Tasks.Compile.ZvexPrecompiled do
  @moduledoc false
  use Mix.Task.Compiler

  @recursive true
  @manifest_vsn 1
  @sentinel ".zvex_precompiled"

  @impl true
  def run(_args) do
    if System.get_env("ZVEX_BUILD") == "true" do
      Mix.shell().info("[zvex] ZVEX_BUILD=true — skipping precompiled download")
      :noop
    else
      case detect_target() do
        {:ok, target} ->
          fetch(target)

        :unsupported ->
          Mix.shell().info("[zvex] unsupported target — falling through to source build")
          :noop
      end
    end
  end

  @impl true
  def manifests, do: [Path.join(priv_dir(), @sentinel)]

  @impl true
  def clean do
    File.rm_rf!(priv_dir())
    :ok
  end

  defp fetch(target) do
    version = zvec_version()
    cache_dir = Path.join([cache_root(), version, target])
    tarball = Path.join(cache_dir, filename(version, target))
    sha_file = tarball <> ".sha256"

    File.mkdir_p!(cache_dir)

    if sentinel_valid?(version, target) do
      :noop
    else
      unless cache_complete?(tarball, sha_file) do
        download!(url(version, target), tarball)
        download!(url(version, target) <> ".sha256", sha_file)
      end

      verify_sha256!(tarball, sha_file)
      wipe_priv()
      extract!(tarball, priv_dir())
      write_sentinel(version, target)
      :ok
    end
  end

  defp zvec_version do
    Mix.Project.config()[:zvec_version] ||
      Mix.raise("[zvex] :zvec_version not set in mix.exs project config")
  end

  defp cache_root do
    :user_cache |> :filename.basedir(~c"zvex") |> to_string()
  end

  defp priv_dir do
    Path.join(Mix.Project.app_path(), "priv")
  end

  defp filename(version, target), do: "zvec-v#{version}-#{target}.tar.gz"

  defp url(version, target) do
    prefix =
      System.get_env("ZVEX_BUILD_URL") ||
        "https://github.com/edlontech/zvex/releases/download"

    "#{String.trim_trailing(prefix, "/")}/zvec-v#{version}/#{filename(version, target)}"
  end

  @doc false
  def detect_target do
    :system_architecture
    |> :erlang.system_info()
    |> to_string()
    |> normalize_architecture()
  end

  @doc false
  def normalize_architecture("x86_64-" <> rest), do: classify(rest, "x86_64")
  def normalize_architecture("aarch64-" <> rest), do: classify(rest, "aarch64")
  def normalize_architecture("arm64-" <> rest), do: classify(rest, "aarch64")
  def normalize_architecture(_other), do: :unsupported

  defp classify(rest, arch) do
    cond do
      String.contains?(rest, "linux-musl") ->
        {:ok, "linux-#{arch}-musl"}

      String.contains?(rest, "linux-gnu") or String.contains?(rest, "linux") ->
        {:ok, "linux-#{arch}-gnu"}

      String.contains?(rest, "apple-darwin") and arch == "aarch64" ->
        {:ok, "darwin-aarch64"}

      true ->
        :unsupported
    end
  end

  @doc false
  def cache_complete?(tarball, sha_file) do
    File.exists?(tarball) and File.exists?(sha_file)
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

  @doc false
  def verify_sha256!(tarball, sha_file) do
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

    if actual == expected do
      :ok
    else
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

  @doc false
  def extract!(tarball, dest) do
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

  @doc false
  def sentinel_valid?(version, target) do
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
