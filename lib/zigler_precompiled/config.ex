defmodule ZiglerPrecompiled.Config do
  @moduledoc false

  defstruct [
    :otp_app,
    :module,
    :base_url,
    :version,
    :module_name,
    :base_cache_dir,
    :load_data,
    :force_build?,
    :targets,
    :nifs,
    variants: %{},
    max_retries: 3
  ]

  @default_targets ~w(
    aarch64-linux-gnu
    aarch64-linux-musl
    aarch64-macos-none
    arm-linux-gnueabihf
    arm-linux-musleabihf
    riscv64-linux-gnu
    x86_64-linux-gnu
    x86_64-linux-musl
    x86_64-macos-none
    x86_64-windows-gnu
    x86-linux-gnu
    x86-windows-gnu
  )

  def default_targets, do: @default_targets

  def new(opts) do
    version = Keyword.fetch!(opts, :version)
    otp_app = opts |> Keyword.fetch!(:otp_app) |> validate_otp_app!()
    base_url = opts |> Keyword.fetch!(:base_url) |> validate_base_url!()

    targets =
      opts
      |> Keyword.get(:targets, @default_targets)
      |> validate_targets!()

    nifs = validate_nifs!(Keyword.get(opts, :nifs))

    %__MODULE__{
      otp_app: otp_app,
      base_url: base_url,
      module: Keyword.fetch!(opts, :module),
      version: version,
      force_build?: pre_release?(version) or Keyword.get(opts, :force_build, false),
      module_name: opts[:module_name],
      load_data: opts[:load_data] || 0,
      base_cache_dir: opts[:base_cache_dir],
      targets: targets,
      nifs: nifs,
      variants: validate_variants!(targets, Keyword.get(opts, :variants, %{})),
      max_retries: validate_max_retries!(Keyword.get(opts, :max_retries, 3))
    }
  end

  defp validate_otp_app!(nil), do: raise("`:otp_app` is required for ZiglerPrecompiled")

  defp validate_otp_app!(otp_app) when is_atom(otp_app), do: otp_app

  defp validate_otp_app!(_),
    do: raise("`:otp_app` must be an atom for ZiglerPrecompiled")

  defp validate_base_url!(nil), do: raise("`:base_url` is required for ZiglerPrecompiled")

  defp validate_base_url!(url) when is_binary(url), do: validate_base_url!({url, []})

  defp validate_base_url!({url, headers}) when is_binary(url) and is_list(headers) do
    case :uri_string.parse(url) do
      %{} ->
        if Enum.all?(headers, &match?({k, v} when is_binary(k) and is_binary(v), &1)) do
          {url, headers}
        else
          raise "`:base_url` headers must be a list of `{String.t(), String.t()}`"
        end

      {:error, :invalid_uri, error} ->
        raise "`:base_url` is invalid: #{inspect(to_string(error))}"
    end
  end

  defp validate_base_url!({module, function}) when is_atom(module) and is_atom(function) do
    Code.ensure_compiled!(module)

    if function_exported?(module, function, 1) do
      {module, function}
    else
      raise "`:base_url` function does not exist: `#{inspect(module)}.#{function}/1`"
    end
  end

  defp validate_targets!(targets) when is_list(targets) do
    Enum.uniq(targets)
  end

  defp validate_targets!(_), do: raise("`:targets` must be a list")

  defp validate_nifs!(nil),
    do:
      raise("`:nifs` is required for ZiglerPrecompiled — list all NIF function name/arity pairs")

  defp validate_nifs!(nifs) when is_list(nifs) do
    for {name, arity_or_opts} = pair <- nifs do
      arity = nif_arity(arity_or_opts)

      unless is_atom(name) and is_integer(arity) and arity >= 0 do
        raise "`:nifs` entries must be `{atom, non_neg_integer}` or `{atom, keyword}` with `:arity`, got: #{inspect(pair)}"
      end
    end

    nifs
  end

  defp validate_nifs!(other), do: raise("`:nifs` must be a keyword list, got: #{inspect(other)}")

  defp nif_arity(arity) when is_integer(arity), do: arity
  defp nif_arity(opts) when is_list(opts), do: Keyword.get(opts, :arity, -1)
  defp nif_arity(_), do: -1

  defp validate_max_retries!(num) when is_integer(num) and num >= 0 and num <= 15, do: num

  defp validate_max_retries!(other),
    do: raise("`:max_retries` must be an integer between 0 and 15, got: #{inspect(other)}")

  defp pre_release?(version), do: "dev" in Version.parse!(version).pre

  defp validate_variants!(_targets, nil), do: %{}

  defp validate_variants!(targets, variants) when is_map(variants) do
    for {target, possibilities} <- variants do
      unless target in targets do
        raise "`:variants` contains target not in targets list: #{inspect(target)}"
      end

      for {name, fun} <- possibilities do
        unless is_atom(name) do
          raise "`:variants` keys must be atoms, got: #{inspect(name)}"
        end

        unless is_function(fun, 0) or is_function(fun, 1) do
          raise "`:variants` values must be 0- or 1-arity functions"
        end
      end
    end

    variants
  end
end
