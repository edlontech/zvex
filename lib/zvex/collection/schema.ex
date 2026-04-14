defmodule Zvex.Collection.Schema do
  @moduledoc """
  Schema builder for zvec collections.

  Pure Elixir struct -- no NIF resources held during building.
  Materialized into C objects at `Zvex.Collection.create/3` time.

  ## Example

      Zvex.Collection.Schema.new("my_collection")
      |> Zvex.Collection.Schema.add_field("id", :string, primary_key: true)
      |> Zvex.Collection.Schema.add_field("embedding", :vector_fp32,
           dimension: 768,
           index: [type: :hnsw, metric: :cosine, m: 16, ef_construction: 200])
      |> Zvex.Collection.Schema.add_field("category", :string,
           nullable: true, index: [type: :invert])
  """

  alias Zvex.Collection.Schema.IndexParams

  defstruct [:name, fields: [], max_doc_count_per_segment: nil]

  @type t :: %__MODULE__{
          name: String.t(),
          fields: [field()],
          max_doc_count_per_segment: pos_integer() | nil
        }

  @type field :: %{
          name: String.t(),
          data_type: atom(),
          primary_key: boolean(),
          nullable: boolean(),
          dimension: non_neg_integer(),
          index: IndexParams.t() | nil
        }

  @vector_types ~w(vector_fp32 vector_fp16 vector_fp64 vector_int4 vector_int8
                    vector_int16 vector_binary32 vector_binary64
                    sparse_vector_fp16 sparse_vector_fp32)a

  @scalar_types ~w(string int32 int64 uint32 uint64 float double bool binary
                    array_string array_int32 array_int64 array_uint32 array_uint64
                    array_float array_double array_bool array_binary)a

  @all_types @vector_types ++ @scalar_types

  @vector_index_types ~w(hnsw ivf flat)a
  @scalar_index_types ~w(invert)a

  @spec new(String.t()) :: t()
  def new(name) when is_binary(name), do: %__MODULE__{name: name}

  @spec add_field(t(), String.t(), atom(), keyword()) :: t()
  def add_field(%__MODULE__{} = schema, name, data_type, opts \\ []) do
    primary_key = Keyword.get(opts, :primary_key, false)
    nullable = if primary_key, do: false, else: Keyword.get(opts, :nullable, false)
    dimension = Keyword.get(opts, :dimension, 0)

    index =
      case Keyword.get(opts, :index) do
        nil -> nil
        index_opts -> IndexParams.from_opts(index_opts)
      end

    field = %{
      name: name,
      data_type: data_type,
      primary_key: primary_key,
      nullable: nullable,
      dimension: dimension,
      index: index
    }

    %{schema | fields: schema.fields ++ [field]}
  end

  @spec max_doc_count_per_segment(t(), pos_integer()) :: t()
  def max_doc_count_per_segment(%__MODULE__{} = schema, count),
    do: %{schema | max_doc_count_per_segment: count}

  @spec validate(t()) :: :ok | {:error, Zvex.Error.t()}
  def validate(%__MODULE__{} = schema) do
    with :ok <- validate_name(schema.name),
         :ok <- validate_fields_present(schema.fields),
         :ok <- validate_primary_key(schema.fields),
         :ok <- validate_field_names_unique(schema.fields),
         :ok <- validate_data_types(schema.fields),
         :ok <- validate_vector_dimensions(schema.fields),
         :ok <- validate_index_compatibility(schema.fields) do
      validate_max_doc_count(schema.max_doc_count_per_segment)
    end
  end

  @doc false
  def vector_types, do: @vector_types
  @doc false
  def scalar_types, do: @scalar_types

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
  defp validate_name(_), do: validation_error("collection name must be a non-empty string")

  defp validate_fields_present([_ | _]), do: :ok
  defp validate_fields_present(_), do: validation_error("schema must have at least one field")

  defp validate_primary_key(fields) do
    pk_fields = Enum.filter(fields, & &1.primary_key)

    case length(pk_fields) do
      0 ->
        validation_error("schema must have exactly one primary key field")

      1 ->
        [pk] = pk_fields

        if pk.data_type == :string,
          do: :ok,
          else: validation_error("primary key field must be of type :string")

      _ ->
        validation_error("schema must have exactly one primary key field")
    end
  end

  defp validate_field_names_unique(fields) do
    names = Enum.map(fields, & &1.name)

    if length(names) == length(Enum.uniq(names)),
      do: :ok,
      else: validation_error("field names must be unique")
  end

  defp validate_data_types(fields) do
    invalid = Enum.find(fields, fn f -> f.data_type not in @all_types end)

    if invalid,
      do: validation_error("unknown data type: #{inspect(invalid.data_type)}"),
      else: :ok
  end

  defp validate_vector_dimensions(fields) do
    invalid =
      Enum.find(fields, fn f ->
        f.data_type in @vector_types and f.dimension <= 0
      end)

    if invalid,
      do: validation_error("vector field '#{invalid.name}' must have dimension > 0"),
      else: :ok
  end

  defp validate_index_compatibility(fields) do
    invalid =
      Enum.find(fields, fn f ->
        f.index != nil and not index_compatible?(f.data_type, f.index.type)
      end)

    if invalid,
      do:
        validation_error(
          "index type :#{invalid.index.type} is incompatible with data type :#{invalid.data_type} on field '#{invalid.name}'"
        ),
      else: :ok
  end

  defp validate_max_doc_count(nil), do: :ok
  defp validate_max_doc_count(n) when is_integer(n) and n > 0, do: :ok

  defp validate_max_doc_count(_),
    do: validation_error("max_doc_count_per_segment must be a positive integer")

  defp index_compatible?(data_type, index_type) when data_type in @vector_types,
    do: index_type in @vector_index_types

  defp index_compatible?(data_type, index_type) when data_type in @scalar_types,
    do: index_type in @scalar_index_types

  defp validation_error(message),
    do: {:error, Zvex.Error.Invalid.Argument.exception(message: message)}
end
