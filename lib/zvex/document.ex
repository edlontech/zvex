defmodule Zvex.Document do
  @moduledoc """
  Pure Elixir document struct with type-tagged fields for zvec collections.

  Fields are stored as `%{"field_name" => {type_atom, value}}` to preserve
  type information through NIF marshaling boundaries.

  ## Example

      alias Zvex.Document
      alias Zvex.Vector

      doc =
        Document.new()
        |> Document.put_pk("doc-1")
        |> Document.put("title", "Hello world")
        |> Document.put("embedding", Vector.from_list([1.0, 2.0, 3.0], :fp32))

      Document.to_map(doc)
      #=> %{"title" => "Hello world", "embedding" => <<...>>}
  """

  alias Zvex.Collection
  alias Zvex.Collection.Schema
  alias Zvex.Vector

  defstruct fields: %{}, pk: nil

  @type t :: %__MODULE__{
          fields: %{String.t() => {atom(), term()}},
          pk: String.t() | nil
        }

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec put(t(), String.t(), term()) :: t()
  def put(%__MODULE__{} = doc, field, %Vector{type: type, data: data}) do
    %{doc | fields: Map.put(doc.fields, field, {type, data})}
  end

  def put(%__MODULE__{} = doc, field, value) when is_boolean(value) do
    %{doc | fields: Map.put(doc.fields, field, {:bool, value})}
  end

  def put(%__MODULE__{} = doc, field, value) when is_binary(value) do
    %{doc | fields: Map.put(doc.fields, field, {:string, value})}
  end

  def put(%__MODULE__{} = doc, field, value) when is_integer(value) do
    %{doc | fields: Map.put(doc.fields, field, {:int64, value})}
  end

  def put(%__MODULE__{} = doc, field, value) when is_float(value) do
    %{doc | fields: Map.put(doc.fields, field, {:double, value})}
  end

  def put(%__MODULE__{}, _field, value) do
    raise ArgumentError, "unsupported type for value: #{inspect(value)}"
  end

  @spec put(t(), String.t(), term(), atom()) :: t()
  def put(%__MODULE__{} = doc, field, value, type) when is_atom(type) do
    %{doc | fields: Map.put(doc.fields, field, {type, value})}
  end

  @spec put_null(t(), String.t()) :: t()
  def put_null(%__MODULE__{} = doc, field) do
    %{doc | fields: Map.put(doc.fields, field, {:null, nil})}
  end

  @spec put_pk(t(), String.t()) :: t()
  def put_pk(%__MODULE__{} = doc, pk) when is_binary(pk) do
    %{doc | pk: pk}
  end

  @spec from_map(map(), Schema.t()) :: t()
  def from_map(map, %Schema{} = schema) when is_map(map) do
    field_defs = Map.new(schema.fields, fn f -> {f.name, f} end)

    Enum.reduce(map, new(), fn {key, value}, doc ->
      case Map.fetch(field_defs, key) do
        {:ok, field_def} ->
          doc = if field_def.primary_key, do: put_pk(doc, value), else: doc
          coerced = coerce_value(value, field_def.data_type)
          %{doc | fields: Map.put(doc.fields, key, {field_def.data_type, coerced})}

        :error ->
          doc
      end
    end)
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{fields: fields}) do
    Map.new(fields, fn {key, {_type, value}} -> {key, value} end)
  end

  @spec validate(t(), Schema.t()) :: :ok | {:error, Zvex.Error.Invalid.Argument.t()}
  def validate(%__MODULE__{} = doc, %Schema{} = schema) do
    with :ok <- validate_pk(doc, schema),
         :ok <- validate_required_fields(doc, schema),
         :ok <- validate_field_types(doc, schema),
         :ok <- validate_dimensions(doc, schema) do
      :ok
    end
  end

  @spec to_native_map(t()) :: map()
  def to_native_map(%__MODULE__{} = doc) do
    fields =
      Enum.map(doc.fields, fn {name, {type, value}} ->
        {name, type, value}
      end)

    %{pk: doc.pk, fields: fields}
  end

  @spec from_native_map(map()) :: t()
  def from_native_map(%{pk: pk, fields: fields}) do
    field_map =
      Map.new(fields, fn {name, type, value} ->
        {name, {type, value}}
      end)

    %__MODULE__{pk: pk, fields: field_map}
  end

  @spec to_native_maps(t() | [t()]) :: [map()]
  def to_native_maps(%__MODULE__{} = doc), do: [to_native_map(doc)]
  def to_native_maps(docs) when is_list(docs), do: Enum.map(docs, &to_native_map/1)

  # -- CRUD operations --------------------------------------------------------

  @spec insert(Collection.t(), t() | [t()]) ::
          {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, Zvex.Error.t()}
  def insert(%Collection{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = to_native_maps(doc_or_docs)

      case Zvex.Native.collection_insert(collection.ref, native_maps) do
        {:ok, {success, errors}} -> {:ok, %{success: success, errors: errors}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec insert!(Collection.t(), t() | [t()]) ::
          %{success: non_neg_integer(), errors: non_neg_integer()}
  def insert!(collection, doc_or_docs) do
    insert(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @spec insert_with_results(Collection.t(), t() | [t()]) ::
          {:ok, [map()]} | {:error, Zvex.Error.t()}
  def insert_with_results(%Collection{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = to_native_maps(doc_or_docs)

      case Zvex.Native.collection_insert_with_results(collection.ref, native_maps) do
        {:ok, results} -> {:ok, results}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec insert_with_results!(Collection.t(), t() | [t()]) :: [map()]
  def insert_with_results!(collection, doc_or_docs) do
    insert_with_results(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @spec update(Collection.t(), t() | [t()]) ::
          {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, Zvex.Error.t()}
  def update(%Collection{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = to_native_maps(doc_or_docs)

      case Zvex.Native.collection_update(collection.ref, native_maps) do
        {:ok, {success, errors}} -> {:ok, %{success: success, errors: errors}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec update!(Collection.t(), t() | [t()]) ::
          %{success: non_neg_integer(), errors: non_neg_integer()}
  def update!(collection, doc_or_docs) do
    update(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @spec update_with_results(Collection.t(), t() | [t()]) ::
          {:ok, [map()]} | {:error, Zvex.Error.t()}
  def update_with_results(%Collection{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = to_native_maps(doc_or_docs)

      case Zvex.Native.collection_update_with_results(collection.ref, native_maps) do
        {:ok, results} -> {:ok, results}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec update_with_results!(Collection.t(), t() | [t()]) :: [map()]
  def update_with_results!(collection, doc_or_docs) do
    update_with_results(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @spec upsert(Collection.t(), t() | [t()]) ::
          {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, Zvex.Error.t()}
  def upsert(%Collection{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = to_native_maps(doc_or_docs)

      case Zvex.Native.collection_upsert(collection.ref, native_maps) do
        {:ok, {success, errors}} -> {:ok, %{success: success, errors: errors}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec upsert!(Collection.t(), t() | [t()]) ::
          %{success: non_neg_integer(), errors: non_neg_integer()}
  def upsert!(collection, doc_or_docs) do
    upsert(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @spec upsert_with_results(Collection.t(), t() | [t()]) ::
          {:ok, [map()]} | {:error, Zvex.Error.t()}
  def upsert_with_results(%Collection{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = to_native_maps(doc_or_docs)

      case Zvex.Native.collection_upsert_with_results(collection.ref, native_maps) do
        {:ok, results} -> {:ok, results}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec upsert_with_results!(Collection.t(), t() | [t()]) :: [map()]
  def upsert_with_results!(collection, doc_or_docs) do
    upsert_with_results(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @spec delete(Collection.t(), [String.t()]) ::
          {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, Zvex.Error.t()}
  def delete(%Collection{} = collection, primary_keys) when is_list(primary_keys) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_delete(collection.ref, primary_keys) do
        {:ok, {success, errors}} -> {:ok, %{success: success, errors: errors}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec delete!(Collection.t(), [String.t()]) ::
          %{success: non_neg_integer(), errors: non_neg_integer()}
  def delete!(collection, primary_keys) do
    delete(collection, primary_keys) |> Zvex.Error.unwrap!()
  end

  @spec delete_with_results(Collection.t(), [String.t()]) ::
          {:ok, [map()]} | {:error, Zvex.Error.t()}
  def delete_with_results(%Collection{} = collection, primary_keys) when is_list(primary_keys) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_delete_with_results(collection.ref, primary_keys) do
        {:ok, results} -> {:ok, results}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec delete_with_results!(Collection.t(), [String.t()]) :: [map()]
  def delete_with_results!(collection, primary_keys) do
    delete_with_results(collection, primary_keys) |> Zvex.Error.unwrap!()
  end

  @spec delete_by_filter(Collection.t(), String.t()) :: :ok | {:error, Zvex.Error.t()}
  def delete_by_filter(%Collection{} = collection, filter) when is_binary(filter) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_delete_by_filter(collection.ref, filter) do
        :ok -> :ok
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec delete_by_filter!(Collection.t(), String.t()) :: :ok
  def delete_by_filter!(collection, filter) do
    delete_by_filter(collection, filter) |> Zvex.Error.unwrap!()
  end

  @spec fetch(Collection.t(), [String.t()]) ::
          {:ok, [t()]} | {:error, Zvex.Error.t()}
  def fetch(%Collection{} = collection, primary_keys) when is_list(primary_keys) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_fetch(collection.ref, primary_keys) do
        {:ok, native_docs} -> {:ok, Enum.map(native_docs, &from_native_map/1)}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec fetch!(Collection.t(), [String.t()]) :: [t()]
  def fetch!(collection, primary_keys) do
    fetch(collection, primary_keys) |> Zvex.Error.unwrap!()
  end

  # -- Private helpers -------------------------------------------------------

  defp check_open(%Collection{closed: true}),
    do: {:error, Zvex.Error.Invalid.Argument.exception(message: "collection is closed")}

  defp check_open(%Collection{closed: false}), do: :ok

  defp coerce_value(%Vector{type: _type, data: data}, _data_type), do: data

  defp coerce_value(list, data_type) when is_list(list) do
    if data_type in Schema.vector_types() do
      shorthand = vector_shorthand(data_type)
      vec = Vector.from_list(list, shorthand)
      vec.data
    else
      list
    end
  end

  defp coerce_value(value, _data_type), do: value

  defp vector_shorthand(:vector_fp16), do: :fp16
  defp vector_shorthand(:vector_fp32), do: :fp32
  defp vector_shorthand(:vector_fp64), do: :fp64
  defp vector_shorthand(:vector_int4), do: :int4
  defp vector_shorthand(:vector_int8), do: :int8
  defp vector_shorthand(:vector_int16), do: :int16
  defp vector_shorthand(:vector_binary32), do: :binary32
  defp vector_shorthand(:vector_binary64), do: :binary64

  defp validate_pk(%__MODULE__{pk: nil}, schema) do
    if Enum.any?(schema.fields, & &1.primary_key) do
      {:error, Zvex.Error.Invalid.Argument.exception(message: "primary key must be set")}
    else
      :ok
    end
  end

  defp validate_pk(%__MODULE__{}, _schema), do: :ok

  defp validate_required_fields(%__MODULE__{} = doc, %Schema{} = schema) do
    missing =
      Enum.find(schema.fields, fn field ->
        not field.nullable and not field.primary_key and
          not Map.has_key?(doc.fields, field.name)
      end)

    case missing do
      nil -> :ok
      field -> validation_error("required field '#{field.name}' is missing")
    end
  end

  defp validate_field_types(%__MODULE__{} = doc, %Schema{} = schema) do
    field_defs = Map.new(schema.fields, fn f -> {f.name, f.data_type} end)

    invalid =
      Enum.find(doc.fields, fn {name, {type, _value}} ->
        case Map.fetch(field_defs, name) do
          {:ok, expected} -> type != :null and type != expected
          :error -> false
        end
      end)

    case invalid do
      nil ->
        :ok

      {name, {type, _value}} ->
        expected = Map.fetch!(field_defs, name)
        validation_error("field '#{name}' has type #{type}, expected #{expected}")
    end
  end

  defp validate_dimensions(%__MODULE__{} = doc, %Schema{} = schema) do
    vector_fields =
      Enum.filter(schema.fields, fn f -> f.data_type in Schema.vector_types() end)

    invalid =
      Enum.find(vector_fields, fn field ->
        case Map.fetch(doc.fields, field.name) do
          {:ok, {type, data}} when is_binary(data) ->
            actual_dim = compute_dimension(data, type)
            actual_dim != field.dimension

          _ ->
            false
        end
      end)

    case invalid do
      nil ->
        :ok

      field ->
        {_type, data} = Map.fetch!(doc.fields, field.name)
        actual = compute_dimension(data, field.data_type)

        validation_error(
          "vector field '#{field.name}' has dimension #{actual}, expected #{field.dimension}"
        )
    end
  end

  defp compute_dimension(data, type) do
    shorthand = vector_shorthand(type)
    vec = Vector.from_binary(data, shorthand)
    Vector.dimension(vec)
  end

  defp validation_error(message),
    do: {:error, Zvex.Error.Invalid.Argument.exception(message: message)}
end
