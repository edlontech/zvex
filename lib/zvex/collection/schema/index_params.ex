defmodule Zvex.Collection.Schema.IndexParams do
  @moduledoc """
  Index configuration for a schema field.
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

  @doc "Builds an IndexParams struct from a keyword list."
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
