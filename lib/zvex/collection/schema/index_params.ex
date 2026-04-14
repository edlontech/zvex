defmodule Zvex.Collection.Schema.IndexParams do
  @moduledoc """
  Index configuration for a schema field.

  Used by `Zvex.Collection.Schema.add_field/4` when the `:index` option is
  provided, and by `Zvex.Collection.create_index/3` for runtime index creation.

  ## Fields

  | Field | Applies to | Description |
  |---|---|---|
  | `:type` | all | **Required.** Index algorithm: `:hnsw`, `:ivf`, `:flat`, or `:invert`. |
  | `:metric` | vector | Distance metric: `:l2`, `:ip`, `:cosine`, or `:mipsl2`. |
  | `:quantize` | vector | Quantization: `:fp16`, `:int8`, or `:int4`. |
  | `:m` | HNSW | Max connections per node (higher = better recall, more memory). |
  | `:ef_construction` | HNSW | Build-time search width (higher = better index, slower build). |
  | `:n_list` | IVF | Number of inverted-file partitions. |
  | `:n_iters` | IVF | K-means training iterations. |
  | `:use_soar` | HNSW | Enable SOAR graph optimization. |
  | `:enable_range_opt` | invert | Enable range query optimization. |
  | `:enable_wildcard` | invert | Enable wildcard/prefix matching. |
  """

  defstruct [
    :type,
    :metric,
    :quantize,
    :m,
    :ef_construction,
    :n_list,
    :n_iters,
    :use_soar,
    :enable_range_opt,
    :enable_wildcard
  ]

  @typedoc "Index configuration struct. See module documentation for field details."
  @type t :: %__MODULE__{
          type: :hnsw | :ivf | :flat | :invert,
          metric: :l2 | :ip | :cosine | :mipsl2 | nil,
          quantize: :fp16 | :int8 | :int4 | nil,
          m: pos_integer() | nil,
          ef_construction: pos_integer() | nil,
          n_list: pos_integer() | nil,
          n_iters: pos_integer() | nil,
          use_soar: boolean() | nil,
          enable_range_opt: boolean() | nil,
          enable_wildcard: boolean() | nil
        }

  @doc """
  Builds an `IndexParams` struct from a keyword list.

  The `:type` key is required; all others are optional and default to `nil`
  (which lets zvec use its own defaults).
  """
  @spec from_opts(keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    %__MODULE__{
      type: Keyword.fetch!(opts, :type),
      metric: Keyword.get(opts, :metric),
      quantize: Keyword.get(opts, :quantize),
      m: Keyword.get(opts, :m),
      ef_construction: Keyword.get(opts, :ef_construction),
      n_list: Keyword.get(opts, :n_list),
      n_iters: Keyword.get(opts, :n_iters),
      use_soar: Keyword.get(opts, :use_soar),
      enable_range_opt: Keyword.get(opts, :enable_range_opt),
      enable_wildcard: Keyword.get(opts, :enable_wildcard)
    }
  end
end
