defmodule Mix.Tasks.ZiglerPrecompiled.Build do
  @shortdoc "Builds one ZiglerPrecompiled NIF artifact for a target"

  @moduledoc false

  use Mix.Task

  @requirements ["loadpaths"]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("deps.compile", [])

    {opts, positional, invalid} =
      OptionParser.parse(args,
        strict: [target: :string, out: :string, basename: :string, version: :string],
        aliases: [t: :target, o: :out]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    source_file =
      case positional do
        [file] ->
          file

        [] ->
          Mix.raise(
            "expected source file, e.g. mix zigler_precompiled.build lib/my_app/native.ex --target aarch64-linux-gnu"
          )

        _ ->
          Mix.raise("expected exactly one source file, got: #{Enum.join(positional, " ")}")
      end

    target = Keyword.get(opts, :target) || Mix.raise("--target is required")
    out_dir = Keyword.get(opts, :out, "artifacts")
    version = Keyword.get(opts, :version, Mix.Project.config()[:version])

    unless is_binary(version) and version != "" do
      Mix.raise("--version is required when Mix.Project.config() has no version")
    end

    File.mkdir_p!(out_dir)

    previous_precompiling = Application.get_env(:zigler, :precompiling)
    previous_force_build_all = Application.get_env(:zigler_precompiled, :force_build_all)

    try do
      Mix.Task.run("app.config", [])
      ensure_app_loaded!(:zigler, Zig)
      ensure_project_app_loaded!()
      Code.ensure_loaded!(ZiglerPrecompiled)
      Application.put_env(:zigler_precompiled, :force_build_all, true)

      {module, built_file} = build_nif(source_file, target)
      basename = Keyword.get(opts, :basename, to_string(module))
      artifact_name = artifact_name(basename, version, target)
      artifact_path = Path.join(out_dir, artifact_name)

      create_tar_gz!(artifact_path, built_file)

      Mix.shell().info("Built #{artifact_path}")
      artifact_path
    after
      restore_env(:zigler, :precompiling, previous_precompiling)
      restore_env(:zigler_precompiled, :force_build_all, previous_force_build_all)
    end
  end

  defp build_nif(source_file, target) do
    if target == ZiglerPrecompiled.current_target_triple() do
      Application.delete_env(:zigler, :precompiling)
      module = compile_source_file!(source_file)
      {module, find_native_built_file!(module)}
    else
      {arch, os, abi} = parse_target!(target)
      parent = self()
      callback = fn file -> send(parent, {:zigler_precompiled_built, file}) end
      Application.put_env(:zigler, :precompiling, {arch, os, abi, callback})

      module = compile_source_file!(source_file)
      {module, receive_built_file!()}
    end
  end

  defp compile_source_file!(source_file) do
    case Code.compile_file(source_file) do
      [{module, _} | _] -> module
      [] -> Mix.raise("#{source_file} did not compile any modules")
    end
  end

  defp find_native_built_file!(module) do
    app =
      Mix.Project.config()[:app] || Mix.raise("Mix project :app is required for native builds")

    native_dir = Application.app_dir(app, "priv/lib")
    module_name = to_string(module)

    native_dir
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.filter(fn path ->
      file = Path.basename(path)
      String.contains?(file, module_name) and String.ends_with?(file, [".so", ".dylib", ".dll"])
    end)
    |> Enum.reject(&File.dir?/1)
    |> Enum.max_by(&File.stat!(&1).mtime, fn ->
      Mix.raise("could not find built NIF for #{inspect(module)} in #{native_dir}")
    end)
  end

  defp ensure_project_app_loaded! do
    app = Mix.Project.config()[:app]

    if app do
      Mix.Project.compile_path()
      |> to_charlist()
      |> Code.prepend_path()

      case Application.load(app) do
        :ok -> :ok
        {:error, {:already_loaded, ^app}} -> :ok
        {:error, reason} -> Mix.raise("failed to load #{inspect(app)}: #{inspect(reason)}")
      end
    end
  end

  defp ensure_app_loaded!(app, module) do
    ebin = Path.join([Mix.Project.build_path(), "lib", Atom.to_string(app), "ebin"])
    Code.prepend_path(String.to_charlist(ebin))

    case Application.load(app) do
      :ok -> :ok
      {:error, {:already_loaded, ^app}} -> :ok
      {:error, reason} -> Mix.raise("failed to load #{inspect(app)}: #{inspect(reason)}")
    end

    Code.ensure_loaded!(module)
  end

  defp parse_target!(target) do
    case String.split(target, "-") do
      [arch, os, abi] -> {String.to_atom(arch), String.to_atom(os), String.to_atom(abi)}
      _ -> Mix.raise("--target must be an ARCH-OS-ABI triple, got: #{inspect(target)}")
    end
  end

  defp receive_built_file! do
    receive do
      {:zigler_precompiled_built, file} -> file
    after
      120_000 -> Mix.raise("timed out waiting for Zigler precompile output")
    end
  end

  defp artifact_name(basename, version, target) do
    lib_name = ZiglerPrecompiled.lib_name(basename, version, target)
    ZiglerPrecompiled.lib_name_with_ext(target, lib_name)
  end

  defp create_tar_gz!(artifact_path, built_file) do
    cwd = Path.dirname(built_file)
    basename = Path.basename(built_file)

    case System.cmd("tar", ["czf", artifact_path, "-C", cwd, basename], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, code} -> Mix.raise("failed to create #{artifact_path} (exit #{code}): #{output}")
    end
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
