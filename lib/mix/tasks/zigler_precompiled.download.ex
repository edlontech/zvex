defmodule Mix.Tasks.ZiglerPrecompiled.Download do
  @shortdoc "Download precompiled NIFs and generate checksums"

  @moduledoc false

  use Mix.Task

  @switches [
    all: :boolean,
    only_local: :boolean,
    print: :boolean,
    no_config: :boolean,
    ignore_unavailable: :boolean
  ]

  @impl true
  def run([module_name | flags]) do
    module = String.to_atom("Elixir.#{module_name}")
    {options, _args, _invalid} = OptionParser.parse(flags, strict: @switches)

    unless options[:no_config] do
      Mix.Task.run("app.config", [])
    end

    case Code.ensure_compiled(module) do
      {:module, _} ->
        :ok

      {:error, error} ->
        Mix.shell().error("Could not compile module #{module_name}: #{inspect(error)}")
    end

    nifs_with_urls =
      cond do
        options[:all] ->
          ZiglerPrecompiled.available_nifs(module)

        options[:only_local] ->
          ZiglerPrecompiled.current_target_nifs(module)

        true ->
          Mix.raise("specify either --all or --only-local")
      end

    result =
      ZiglerPrecompiled.download_nif_artifacts_with_checksums!(nifs_with_urls, options)

    if Keyword.get(options, :print, true) do
      result
      |> Enum.map(fn map ->
        {Path.basename(Map.fetch!(map, :path)), Map.fetch!(map, :checksum)}
      end)
      |> Enum.sort()
      |> Enum.map_join("\n", fn {file, checksum} -> "#{checksum}  #{file}" end)
      |> Mix.shell().info()
    end

    ZiglerPrecompiled.write_checksum!(module, result)
  end

  @impl true
  def run([]) do
    Mix.raise("usage: mix zigler_precompiled.download MODULE --all|--only-local")
  end
end
