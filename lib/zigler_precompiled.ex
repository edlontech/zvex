defmodule ZiglerPrecompiled do
  @moduledoc false

  # Vendored from https://github.com/dannote/zigler_precompiled (MIT).
  # See NOTICE for the upstream copyright.

  alias ZiglerPrecompiled.Config
  require Logger

  @checksum_algo :sha256
  @native_dir "priv/lib"

  defmacro __using__(opts) do
    zig_available? = Code.ensure_loaded?(Zig)

    quote do
      require Logger

      opts = unquote(opts)
      otp_app = Keyword.fetch!(opts, :otp_app)

      opts =
        if Application.compile_env(
             :zigler_precompiled,
             :force_build_all,
             System.get_env("ZIGLER_PRECOMPILED_FORCE_BUILD_ALL") in ["1", "true"]
           ) do
          Keyword.put(opts, :force_build, true)
        else
          Keyword.put_new(
            opts,
            :force_build,
            Application.compile_env(:zigler_precompiled, [:force_build, otp_app])
          )
        end

      case ZiglerPrecompiled.__using__(__MODULE__, opts) do
        {:force_build, zigler_opts} ->
          if unquote(zig_available?) do
            escaped = Macro.escape(zigler_opts)
            Code.eval_quoted_with_env(quote(do: use(Zig, unquote(escaped))), [], __ENV__)
          else
            raise "Zigler dependency is needed to force the build. " <>
                    "Add it to your `mix.exs` file: `{:zigler, \">= 0.0.0\", optional: true}`"
          end

        {:metadata_only, _} ->
          unquote(ZiglerPrecompiled.generate_nif_stubs(opts[:nifs]))

        {:ok, config} ->
          @on_load :__load_zigler_precompiled__
          @zigler_precompiled_load_from config.load_from
          @zigler_precompiled_load_data config.load_data

          @doc false
          def __load_zigler_precompiled__ do
            :code.purge(__MODULE__)
            {otp_app, path} = @zigler_precompiled_load_from

            load_path =
              otp_app
              |> Application.app_dir(path)
              |> to_charlist()

            :erlang.load_nif(load_path, @zigler_precompiled_load_data)
          end

          unquote(ZiglerPrecompiled.generate_nif_stubs(opts[:nifs]))

        {:error, precomp_error} ->
          raise precomp_error
      end
    end
  end

  @doc false
  def generate_nif_stubs(nil) do
    raise ArgumentError, ":nifs option is required for ZiglerPrecompiled"
  end

  def generate_nif_stubs(nifs) when is_list(nifs) do
    for {name, arity_or_opts} <- nifs do
      arity = nif_arity(arity_or_opts)
      args = Macro.generate_arguments(arity, __MODULE__)
      marshalled_name = :"marshalled-#{name}"

      quote do
        @doc false
        def unquote(marshalled_name)(unquote_splicing(args)) do
          :erlang.nif_error(:nif_not_loaded)
        end

        def unquote(name)(unquote_splicing(args)) do
          unquote(marshalled_name)(unquote_splicing(args))
        end
      end
    end
  end

  defp nif_arity(arity) when is_integer(arity), do: arity
  defp nif_arity(opts) when is_list(opts), do: Keyword.fetch!(opts, :arity)

  @doc false
  def normalize_nifs_for_zigler(nifs) do
    Enum.map(nifs, fn
      {name, arity} when is_integer(arity) ->
        {name, []}

      {name, opts} when is_list(opts) ->
        {name, Enum.reject(opts, &match?({:arity, _}, &1))}
    end)
  end

  @doc false
  def __using__(module, opts) do
    config =
      opts
      |> Keyword.put_new(:module, module)
      |> Config.new()

    case build_metadata(config) do
      {:ok, metadata} ->
        maybe_warn_metadata_write(module, metadata)

        if metadata_only?() do
          {:metadata_only, opts[:nifs]}
        else
          build_or_download(config, metadata, opts)
        end

      {:error, _} = error ->
        error
    end
  end

  defp metadata_only? do
    System.get_env("ZIGLER_PRECOMPILED_METADATA_ONLY") in ["1", "true"]
  end

  defp maybe_warn_metadata_write(module, metadata) do
    with {:error, error} <- write_metadata(module, metadata) do
      Logger.warning(
        "Cannot write metadata for #{inspect(module)}: #{inspect(error)}. " <>
          "This is only an issue if you need the zigler_precompiled mix tasks."
      )
    end
  end

  defp build_or_download(%{force_build?: true}, _metadata, opts) do
    {:force_build, zigler_force_build_opts(opts)}
  end

  defp build_or_download(config, metadata, opts) do
    case download_or_reuse_nif_file(config, metadata) do
      {:ok, _} = result ->
        result

      {:error, precomp_error} ->
        if Code.ensure_loaded?(Zig) do
          Logger.warning(
            "Precompiled NIF download failed: #{precomp_error}. Falling back to source build."
          )

          {:force_build, zigler_force_build_opts(opts)}
        else
          {:error, force_build_message(config, precomp_error)}
        end
    end
  end

  defp zigler_force_build_opts(opts) do
    opts
    |> Keyword.drop([
      :base_url,
      :version,
      :force_build,
      :targets,
      :max_retries,
      :variants,
      :module_name
    ])
    |> Keyword.update(:nifs, [], &normalize_nifs_for_zigler/1)
  end

  defp force_build_message(config, precomp_error) do
    """
    Error downloading precompiled NIF: #{precomp_error}.

    You can force the project to build from scratch with:

        config :zigler_precompiled, :force_build, #{config.otp_app}: true

    You also need Zigler as a dependency:

        {:zigler, ">= 0.0.0", optional: true}
    """
  end

  @doc false
  def target(available_targets \\ Config.default_targets()) do
    triple = current_target_triple()

    if triple in available_targets do
      {:ok, triple}
    else
      {:error,
       "precompiled NIF is not available for this target: #{inspect(triple)}.\n" <>
         "The available targets are:\n - #{Enum.join(available_targets, "\n - ")}"}
    end
  end

  @doc false
  def current_target_triple do
    base = system_arch()
    overridden = maybe_override_with_env_vars(base)
    normalize_triple(overridden)
  end

  defp system_arch do
    parts =
      :erlang.system_info(:system_architecture)
      |> List.to_string()
      |> String.split("-")

    case parts do
      [arch, vendor, os, abi] -> %{arch: arch, vendor: vendor, os: os, abi: abi}
      [arch, vendor, os] -> %{arch: arch, vendor: vendor, os: os, abi: nil}
      _ -> %{arch: "unknown", vendor: "unknown", os: "unknown", abi: nil}
    end
  end

  @doc false
  def maybe_override_with_env_vars(sys_arch, get_env \\ &System.get_env/1) do
    envs = [arch: "TARGET_ARCH", os: "TARGET_OS", abi: "TARGET_ABI"]

    Enum.reduce(envs, sys_arch, fn {key, env_key}, acc ->
      if env_value = get_env.(env_key) do
        Map.put(acc, key, env_value)
      else
        acc
      end
    end)
  end

  defp normalize_triple(sys) do
    {arch, os, abi} = triple_parts(sys, to_string(sys.os))
    "#{arch}-#{os}-#{abi}"
  end

  defp triple_parts(sys, os_str) do
    cond do
      os_str =~ "darwin" -> darwin_triple(sys)
      os_str =~ "freebsd" -> {sys.arch, "freebsd", "none"}
      os_str =~ "linux" -> linux_triple(sys)
      match?({:win32, _}, :os.type()) -> windows_triple(sys)
      true -> {sys.arch, os_str, sys.abi || "none"}
    end
  end

  defp darwin_triple(sys) do
    arch = if sys.arch == "arm", do: "aarch64", else: sys.arch
    {arch, "macos", "none"}
  end

  defp linux_triple(sys) do
    {normalize_arch(sys.arch), "linux", sys.abi || "gnu"}
  end

  defp windows_triple(_sys) do
    arch =
      case :erlang.system_info(:wordsize) do
        8 -> "x86_64"
        4 -> "x86"
      end

    {arch, "windows", "gnu"}
  end

  defp normalize_arch("i386"), do: "x86"
  defp normalize_arch("i686"), do: "x86"
  defp normalize_arch("amd64"), do: "x86_64"
  defp normalize_arch("arm"), do: "arm"
  defp normalize_arch(arch), do: arch

  @doc false
  def lib_name(basename, version, target_triple) do
    "#{basename}-v#{version}-#{target_triple}"
  end

  @doc false
  def lib_name_with_ext(target_triple, lib_name) do
    ext = if String.contains?(target_triple, "windows"), do: ".dll", else: ".so"
    "#{lib_name}#{ext}.tar.gz"
  end

  @doc false
  def tar_gz_file_url(base_url, lib_name_with_ext) do
    case base_url do
      {url, headers} when is_binary(url) ->
        {"#{url}/#{lib_name_with_ext}", headers}

      {module, function} when is_atom(module) and is_atom(function) ->
        apply(module, function, [lib_name_with_ext])

      url when is_binary(url) ->
        {"#{url}/#{lib_name_with_ext}", []}
    end
  end

  @doc false
  def download_or_reuse_nif_file(config, metadata) do
    cache_dir = cache_dir(config)

    lib_name =
      lib_name(
        metadata.basename,
        config.version,
        metadata.target
      )

    lib_name_with_ext = lib_name_with_ext(metadata.target, lib_name)
    cached_tar_gz = Path.join(cache_dir, lib_name_with_ext)
    checksum_map = read_checksum_map(config.module)

    result =
      if File.exists?(cached_tar_gz) do
        case verify_checksum(cached_tar_gz, checksum_map) do
          :ok ->
            Logger.debug("Using cached NIF: #{cached_tar_gz}")
            {:ok, cached_tar_gz}

          {:error, _} ->
            File.rm(cached_tar_gz)
            download_nif_artifact(cached_tar_gz, config, lib_name_with_ext, checksum_map)
        end
      else
        download_nif_artifact(cached_tar_gz, config, lib_name_with_ext, checksum_map)
      end

    with {:ok, tar_gz_path} <- result do
      install_nif(tar_gz_path, config)
    end
  end

  defp download_nif_artifact(dest_path, config, lib_name_with_ext, checksum_map) do
    {url, headers} = tar_gz_file_url(config.base_url, lib_name_with_ext)

    File.mkdir_p!(Path.dirname(dest_path))

    case download_with_retries(url, headers, config.max_retries) do
      {:ok, body} ->
        File.write!(dest_path, body)

        case verify_checksum(dest_path, checksum_map) do
          :ok -> {:ok, dest_path}
          {:error, _} = err -> err
        end

      {:error, reason} ->
        {:error, "download failed: #{inspect(reason)}"}
    end
  end

  defp download_with_retries(url, headers, retries_left) do
    ensure_httpc!()

    http_options = ZiglerPrecompiled.HTTP.http_options()

    request_headers =
      Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    Logger.debug("Downloading NIF from #{url}")

    case :httpc.request(:get, {String.to_charlist(url), request_headers}, http_options,
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _resp_headers, body}} ->
        {:ok, body}

      {:ok, {{_, status, _}, _, _}} when retries_left > 0 ->
        Logger.warning("Download returned HTTP #{status}, retrying (#{retries_left} left)...")
        Process.sleep(500)
        download_with_retries(url, headers, retries_left - 1)

      {:ok, {{_, status, _}, _, _}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} when retries_left > 0 ->
        Logger.warning("Download error: #{inspect(reason)}, retrying (#{retries_left} left)...")
        Process.sleep(500)
        download_with_retries(url, headers, retries_left - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_httpc! do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
    {:ok, _} = Application.ensure_all_started(:public_key)
  end

  defp install_nif(tar_gz_path, config) do
    native_dir = app_native_dir(config)
    File.mkdir_p!(native_dir)

    case :erl_tar.extract(String.to_charlist(tar_gz_path), [
           :compressed,
           {:cwd, String.to_charlist(native_dir)}
         ]) do
      :ok ->
        lib_file = find_installed_lib(native_dir, config.module)

        if lib_file do
          load_path = Path.join(@native_dir, Path.basename(lib_file, Path.extname(lib_file)))

          {:ok,
           %{
             load_from: {config.otp_app, load_path},
             load_data: config.load_data
           }}
        else
          {:error, "extracted archive but could not find NIF library in #{native_dir}"}
        end

      {:error, reason} ->
        {:error, "failed to extract tar.gz: #{inspect(reason)}"}
    end
  end

  defp find_installed_lib(dir, module) do
    module_str = "#{module}"
    files = File.ls!(dir)

    nif_entry =
      Enum.find(files, fn file ->
        file == "#{module_str}.so" or file == "#{module_str}.dll"
      end)

    nif_entry ||
      Enum.find(files, fn file ->
        String.contains?(file, module_str) and
          (String.ends_with?(file, ".so") or String.ends_with?(file, ".dll") or
             String.ends_with?(file, ".dylib"))
      end)
  end

  @doc false
  def download_nif_artifacts_with_checksums!(nifs_with_urls, opts \\ []) do
    ignore_unavailable = Keyword.get(opts, :ignore_unavailable, false)
    Enum.flat_map(nifs_with_urls, &download_nif_artifact_with_checksum(&1, ignore_unavailable))
  end

  defp download_nif_artifact_with_checksum({lib_name, {url, headers}}, ignore_unavailable) do
    case download_with_retries(url, headers, 3) do
      {:ok, body} ->
        path = Path.join(System.tmp_dir!(), lib_name)
        File.write!(path, body)
        checksum = compute_checksum(body)
        [%{path: path, checksum: "sha256:#{checksum}", checksum_algo: @checksum_algo}]

      {:error, reason} ->
        handle_unavailable_nif(lib_name, url, reason, ignore_unavailable)
    end
  end

  defp handle_unavailable_nif(lib_name, _url, reason, true) do
    Logger.warning("Skipping unavailable NIF #{lib_name}: #{inspect(reason)}")
    []
  end

  defp handle_unavailable_nif(lib_name, url, reason, false) do
    raise "failed to download #{lib_name} from #{url}: #{inspect(reason)}"
  end

  @doc false
  def available_nifs(nif_module) when is_atom(nif_module) do
    nif_module
    |> metadata_file()
    |> read_metadata_file()
    |> nifs_from_metadata()
    |> case do
      {:ok, nifs} ->
        nifs

      {:error, wrong_meta} ->
        raise "metadata for #{inspect(nif_module)} is not available. " <>
                "Recompile with: `mix compile --force`. " <>
                "Metadata found: #{inspect(wrong_meta, limit: :infinity, pretty: true)}"
    end
  end

  @doc false
  def current_target_nifs(nif_module) when is_atom(nif_module) do
    metadata =
      nif_module
      |> metadata_file()
      |> read_metadata_file()

    case metadata do
      %{base_url: base_url, target: target_triple, basename: basename, version: version} ->
        lib = lib_name(basename, version, target_triple)
        lib_ext = lib_name_with_ext(target_triple, lib)

        [{lib_ext, tar_gz_file_url(base_url, lib_ext)}]

      _ ->
        raise "metadata for #{inspect(nif_module)} is not available. Recompile with: `mix compile --force`"
    end
  end

  @doc false
  def nifs_from_metadata(metadata) do
    case metadata do
      %{targets: targets, base_url: base_url, basename: basename, version: version} ->
        all =
          for target <- targets do
            lib = lib_name(basename, version, target)
            lib_ext = lib_name_with_ext(target, lib)
            {lib_ext, tar_gz_file_url(base_url, lib_ext)}
          end

        {:ok, all}

      wrong_meta ->
        {:error, wrong_meta}
    end
  end

  @doc false
  def write_checksum!(module, checksums) do
    file = checksum_file(module)
    pairs = Enum.map(checksums, fn %{path: p, checksum: c} -> {Path.basename(p), c} end)
    content = inspect(pairs, limit: :infinity, pretty: true, width: 80)
    File.write!(file, content)
    Logger.info("Wrote checksum file: #{file}")
    file
  end

  @doc false
  def checksum_file(module) do
    "checksum-#{inspect(module)}.exs"
  end

  defp compute_checksum(data) when is_binary(data) do
    :crypto.hash(@checksum_algo, data) |> Base.encode16(case: :lower)
  end

  defp verify_checksum(_path, {:error, :not_found}) do
    Logger.debug("No checksum file found, skipping verification")
    :ok
  end

  defp verify_checksum(path, {:ok, checksum_map}) do
    filename = Path.basename(path)

    case Map.get(checksum_map, filename) do
      nil ->
        Logger.debug("No checksum entry for #{filename}, skipping verification")
        :ok

      expected_checksum ->
        actual = path |> File.read!() |> compute_checksum()
        expected = String.replace_leading(expected_checksum, "sha256:", "")

        if actual == expected do
          :ok
        else
          {:error, "checksum mismatch for #{filename}: expected #{expected}, got #{actual}"}
        end
    end
  end

  defp read_checksum_map(module) do
    file = checksum_file(module)

    if File.exists?(file) do
      {pairs, _} = Code.eval_file(file)
      {:ok, Map.new(pairs)}
    else
      {:error, :not_found}
    end
  end

  defp build_metadata(config) do
    case target(config.targets) do
      {:ok, target_triple} ->
        {:ok,
         %{
           target: target_triple,
           targets: config.targets,
           base_url: config.base_url,
           basename: config.module_name || default_basename(config.module),
           version: config.version
         }}

      {:error, _} = error ->
        error
    end
  end

  defp default_basename(module), do: "#{module}"

  @doc false
  def metadata_file(module) do
    Path.join(
      Mix.Project.build_path(),
      "zigler_precompiled_#{inspect(module)}.meta"
    )
  end

  defp write_metadata(module, metadata) do
    file = metadata_file(module)

    case File.mkdir_p(Path.dirname(file)) do
      :ok -> File.write(file, :erlang.term_to_binary(metadata))
      error -> error
    end
  end

  @doc false
  def read_metadata_file(path) do
    case File.read(path) do
      {:ok, content} -> :erlang.binary_to_term(content, [:safe])
      {:error, _} -> %{}
    end
  end

  defp cache_dir(config) do
    case System.get_env("ZIGLER_PRECOMPILED_GLOBAL_CACHE_PATH") do
      nil ->
        base = config.base_cache_dir || default_cache_dir()
        Path.join([base, "zigler_precompiled", "#{config.otp_app}-#{config.version}"])

      path ->
        path
    end
  end

  defp default_cache_dir do
    os =
      case :os.type() do
        {:unix, :darwin} -> :macos
        {:win32, _} -> :windows
        _ -> :linux
      end

    :filename.basedir(:user_cache, "zigler_precompiled", %{os: os})
    |> to_string()
  end

  defp app_native_dir(config) do
    Application.app_dir(config.otp_app, @native_dir)
  end
end
