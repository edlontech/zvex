defmodule Zvex.Types do
  @moduledoc """
  Type conversion utilities for zvec data types, index types, and metric types.

  Converts between the atoms used in the Elixir API and human-readable strings
  matching the zvec C API's `zvec_*_to_string` functions.
  """

  @data_type_strings %{
    string: "STRING",
    int32: "INT32",
    int64: "INT64",
    uint32: "UINT32",
    uint64: "UINT64",
    float: "FLOAT",
    double: "DOUBLE",
    bool: "BOOL",
    binary: "BINARY",
    vector_fp32: "VECTOR_FP32",
    vector_fp16: "VECTOR_FP16",
    vector_fp64: "VECTOR_FP64",
    vector_int4: "VECTOR_INT4",
    vector_int8: "VECTOR_INT8",
    vector_int16: "VECTOR_INT16",
    vector_binary32: "VECTOR_BINARY32",
    vector_binary64: "VECTOR_BINARY64",
    sparse_vector_fp16: "SPARSE_VECTOR_FP16",
    sparse_vector_fp32: "SPARSE_VECTOR_FP32",
    array_string: "ARRAY_STRING",
    array_int32: "ARRAY_INT32",
    array_int64: "ARRAY_INT64",
    array_uint32: "ARRAY_UINT32",
    array_uint64: "ARRAY_UINT64",
    array_float: "ARRAY_FLOAT",
    array_double: "ARRAY_DOUBLE",
    array_bool: "ARRAY_BOOL",
    array_binary: "ARRAY_BINARY"
  }

  @index_type_strings %{
    hnsw: "HNSW",
    ivf: "IVF",
    flat: "FLAT",
    invert: "INVERT"
  }

  @metric_type_strings %{
    l2: "L2",
    ip: "IP",
    cosine: "COSINE",
    mipsl2: "MIPSL2"
  }

  @string_to_data_type Map.new(@data_type_strings, fn {k, v} -> {v, k} end)
  @string_to_index_type Map.new(@index_type_strings, fn {k, v} -> {v, k} end)
  @string_to_metric_type Map.new(@metric_type_strings, fn {k, v} -> {v, k} end)

  @type data_type ::
          :string
          | :int32
          | :int64
          | :uint32
          | :uint64
          | :float
          | :double
          | :bool
          | :binary
          | :vector_fp32
          | :vector_fp16
          | :vector_fp64
          | :vector_int4
          | :vector_int8
          | :vector_int16
          | :vector_binary32
          | :vector_binary64
          | :sparse_vector_fp16
          | :sparse_vector_fp32
          | :array_string
          | :array_int32
          | :array_int64
          | :array_uint32
          | :array_uint64
          | :array_float
          | :array_double
          | :array_bool
          | :array_binary

  @type index_type :: :hnsw | :ivf | :flat | :invert

  @type metric_type :: :l2 | :ip | :cosine | :mipsl2

  @doc """
  Returns the list of all known data type atoms.
  """
  @spec data_types() :: [data_type()]
  def data_types, do: Map.keys(@data_type_strings)

  @doc """
  Returns the list of all known index type atoms.
  """
  @spec index_types() :: [index_type()]
  def index_types, do: Map.keys(@index_type_strings)

  @doc """
  Returns the list of all known metric type atoms.
  """
  @spec metric_types() :: [metric_type()]
  def metric_types, do: Map.keys(@metric_type_strings)

  @doc """
  Converts a data type atom to its string representation.

  ## Examples

      iex> Zvex.Types.data_type_to_string(:vector_fp32)
      {:ok, "VECTOR_FP32"}

      iex> Zvex.Types.data_type_to_string(:nope)
      :error
  """
  @spec data_type_to_string(data_type()) :: {:ok, String.t()} | :error
  def data_type_to_string(atom) when is_atom(atom) do
    case Map.fetch(@data_type_strings, atom) do
      {:ok, _} = ok -> ok
      :error -> :error
    end
  end

  @doc """
  Converts a string to its data type atom.

  ## Examples

      iex> Zvex.Types.string_to_data_type("VECTOR_FP32")
      {:ok, :vector_fp32}

      iex> Zvex.Types.string_to_data_type("NOPE")
      :error
  """
  @spec string_to_data_type(String.t()) :: {:ok, data_type()} | :error
  def string_to_data_type(string) when is_binary(string) do
    case Map.fetch(@string_to_data_type, string) do
      {:ok, _} = ok -> ok
      :error -> :error
    end
  end

  @doc """
  Converts an index type atom to its string representation.

  ## Examples

      iex> Zvex.Types.index_type_to_string(:hnsw)
      {:ok, "HNSW"}

      iex> Zvex.Types.index_type_to_string(:nope)
      :error
  """
  @spec index_type_to_string(index_type()) :: {:ok, String.t()} | :error
  def index_type_to_string(atom) when is_atom(atom) do
    case Map.fetch(@index_type_strings, atom) do
      {:ok, _} = ok -> ok
      :error -> :error
    end
  end

  @doc """
  Converts a string to its index type atom.

  ## Examples

      iex> Zvex.Types.string_to_index_type("HNSW")
      {:ok, :hnsw}

      iex> Zvex.Types.string_to_index_type("NOPE")
      :error
  """
  @spec string_to_index_type(String.t()) :: {:ok, index_type()} | :error
  def string_to_index_type(string) when is_binary(string) do
    case Map.fetch(@string_to_index_type, string) do
      {:ok, _} = ok -> ok
      :error -> :error
    end
  end

  @doc """
  Converts a metric type atom to its string representation.

  ## Examples

      iex> Zvex.Types.metric_type_to_string(:cosine)
      {:ok, "COSINE"}

      iex> Zvex.Types.metric_type_to_string(:nope)
      :error
  """
  @spec metric_type_to_string(metric_type()) :: {:ok, String.t()} | :error
  def metric_type_to_string(atom) when is_atom(atom) do
    case Map.fetch(@metric_type_strings, atom) do
      {:ok, _} = ok -> ok
      :error -> :error
    end
  end

  @doc """
  Converts a string to its metric type atom.

  ## Examples

      iex> Zvex.Types.string_to_metric_type("COSINE")
      {:ok, :cosine}

      iex> Zvex.Types.string_to_metric_type("NOPE")
      :error
  """
  @spec string_to_metric_type(String.t()) :: {:ok, metric_type()} | :error
  def string_to_metric_type(string) when is_binary(string) do
    case Map.fetch(@string_to_metric_type, string) do
      {:ok, _} = ok -> ok
      :error -> :error
    end
  end
end
