defmodule Zvex.Config do
  @moduledoc """
  Configuration builder for zvec initialization.

  All fields are optional. `nil` values use zvec defaults.

  ## Example

      Zvex.Config.new()
      |> Zvex.Config.memory_limit(1_073_741_824)
      |> Zvex.Config.query_threads(4)
      |> Zvex.Config.log(:console, level: :warn)
  """

  @log_levels [:debug, :info, :warn, :error, :fatal]

  @log_level_schema Zoi.enum(@log_levels)

  @console_log_schema Zoi.map(%{
                        level: @log_level_schema |> Zoi.optional()
                      })

  @log_schema Zoi.tuple({Zoi.literal(:console), @console_log_schema})

  @schema Zoi.struct(__MODULE__, %{
            memory_limit: Zoi.integer() |> Zoi.positive() |> Zoi.nullish(),
            query_threads: Zoi.integer() |> Zoi.positive() |> Zoi.nullish(),
            optimize_threads: Zoi.integer() |> Zoi.positive() |> Zoi.nullish(),
            invert_to_forward_scan_ratio: Zoi.float() |> Zoi.positive() |> Zoi.nullish(),
            brute_force_by_keys_ratio: Zoi.float() |> Zoi.positive() |> Zoi.nullish(),
            log: @log_schema |> Zoi.nullish()
          })

  @type t :: unquote(Zoi.type_spec(@schema))
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Creates a new configuration with all fields set to `nil` (zvec defaults)."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Sets the maximum memory usage in bytes for the zvec engine."
  @spec memory_limit(t(), pos_integer()) :: t()
  def memory_limit(%__MODULE__{} = config, bytes),
    do: %{config | memory_limit: bytes}

  @doc "Sets the number of threads used for query execution."
  @spec query_threads(t(), pos_integer()) :: t()
  def query_threads(%__MODULE__{} = config, count),
    do: %{config | query_threads: count}

  @doc "Sets the number of threads used for index optimization."
  @spec optimize_threads(t(), pos_integer()) :: t()
  def optimize_threads(%__MODULE__{} = config, count),
    do: %{config | optimize_threads: count}

  @doc "Sets the ratio threshold for switching from inverted index scan to forward scan."
  @spec invert_to_forward_scan_ratio(t(), float()) :: t()
  def invert_to_forward_scan_ratio(%__MODULE__{} = config, ratio),
    do: %{config | invert_to_forward_scan_ratio: ratio}

  @doc "Sets the key-count ratio threshold for falling back to brute-force search."
  @spec brute_force_by_keys_ratio(t(), float()) :: t()
  def brute_force_by_keys_ratio(%__MODULE__{} = config, ratio),
    do: %{config | brute_force_by_keys_ratio: ratio}

  @doc """
  Configures console logging for the zvec engine.

  ## Options

  - `:level` — minimum log level: `:debug`, `:info`, `:warn`, `:error`, or `:fatal`.
  """
  @spec log(t(), :console, keyword()) :: t()
  def log(%__MODULE__{} = config, :console, opts \\ []),
    do: %{config | log: {:console, Map.new(opts)}}

  @doc "Validates the configuration using the Zoi schema. Returns `{:ok, config}` or an error."
  @spec validate(t()) :: {:ok, t()} | {:error, Zvex.Error.t()}
  def validate(%__MODULE__{} = config) do
    case Zoi.parse(@schema, config) do
      {:ok, _validated} ->
        {:ok, config}

      {:error, errors} ->
        message = errors |> Enum.map_join("; ", & &1.message)
        {:error, Zvex.Error.Invalid.Argument.exception(message: message)}
    end
  end

  @doc "Converts the configuration to the flat map format expected by the NIF layer."
  @spec to_native_map(t()) :: map()
  def to_native_map(%__MODULE__{} = config) do
    config
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn
      {:log, {type, opts}} -> {:log, Map.put(opts, :type, type)}
      pair -> pair
    end)
    |> Map.new()
  end
end
