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

  alias Zvex.Collection.Schema
  alias Zvex.Vector

  defstruct fields: %{}, pk: nil

  @typedoc """
  A typed document for insertion into a zvec collection.

  - `:fields` — map of `"field_name" => {type_atom, value}` tuples preserving
    type information through NIF boundaries.
  - `:pk` — the primary key value (a string), or `nil` if not yet set.
  """
  @type t :: %__MODULE__{
          fields: %{String.t() => {atom(), term()}},
          pk: String.t() | nil
        }

  @doc "Creates an empty document with no fields and no primary key."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Returns the list of field names present in the document."
  @spec fields(t()) :: [String.t()]
  def fields(%__MODULE__{fields: fields}), do: Map.keys(fields)

  @doc "Returns `true` if the document contains a field named `field`."
  @spec has_field?(t(), String.t()) :: boolean()
  def has_field?(%__MODULE__{fields: fields}, field), do: Map.has_key?(fields, field)

  @doc "Returns `true` if the field exists and its value is `nil`."
  @spec field_null?(t(), String.t()) :: boolean()
  def field_null?(%__MODULE__{fields: fields}, field) do
    case Map.get(fields, field) do
      {_, nil} -> true
      _ -> false
    end
  end

  @doc "Returns `true` if the document has no fields and no primary key set."
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{fields: fields, pk: pk}) do
    map_size(fields) == 0 and is_nil(pk)
  end

  @doc "Removes a field from the document by name. No-op if the field does not exist."
  @spec remove_field(t(), String.t()) :: t()
  def remove_field(%__MODULE__{} = doc, field) do
    %{doc | fields: Map.delete(doc.fields, field)}
  end

  @doc """
  Merges two documents. Fields from `doc2` overwrite those in `doc1`.
  The primary key is taken from `doc2` if set, otherwise from `doc1`.
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = doc1, %__MODULE__{} = doc2) do
    pk = if doc2.pk, do: doc2.pk, else: doc1.pk
    %__MODULE__{pk: pk, fields: Map.merge(doc1.fields, doc2.fields)}
  end

  @doc "Returns a new empty document, discarding all fields and the primary key."
  @spec clear(t()) :: t()
  def clear(%__MODULE__{}), do: %__MODULE__{}

  @doc """
  Sets a field value on the document.

  The type is inferred automatically from the value:

  - `Zvex.Vector` — uses the vector's type
  - `boolean` — `:bool`
  - `binary/string` — `:string`
  - `integer` — `:int64`
  - `float` — `:double`

  Use the 4-arity `put/4` to specify an explicit type atom.
  """
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

  @doc "Sets a field with an explicit `type` atom, bypassing automatic type inference."
  @spec put(t(), String.t(), term(), atom()) :: t()
  def put(%__MODULE__{} = doc, field, value, type) when is_atom(type) do
    %{doc | fields: Map.put(doc.fields, field, {type, value})}
  end

  @doc "Sets a field to null (type `:null`, value `nil`)."
  @spec put_null(t(), String.t()) :: t()
  def put_null(%__MODULE__{} = doc, field) do
    %{doc | fields: Map.put(doc.fields, field, {:null, nil})}
  end

  @doc "Sets the primary key for this document. Must be a string."
  @spec put_pk(t(), String.t()) :: t()
  def put_pk(%__MODULE__{} = doc, pk) when is_binary(pk) do
    %{doc | pk: pk}
  end

  @doc """
  Builds a document from a plain map using the schema for type resolution.

  Keys in `map` that don't match a schema field are silently ignored.
  The primary key field is used to set both the `:pk` and the field entry.
  Vector values can be given as plain lists — they are automatically packed
  into the schema's vector type.
  """
  @spec from_map(map(), Schema.t()) :: t()
  def from_map(map, %Schema{} = schema) when is_map(map) do
    field_defs = Map.new(schema.fields, fn f -> {f.name, f} end)

    Enum.reduce(map, new(), fn {key, value}, doc ->
      case Map.fetch(field_defs, key) do
        {:ok, field_def} -> apply_field(doc, key, value, field_def)
        :error -> doc
      end
    end)
  end

  @doc "Converts the document to a plain map, stripping type information from field values."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{fields: fields}) do
    Map.new(fields, fn {key, {_type, value}} -> {key, value} end)
  end

  @doc """
  Validates the document against a schema.

  Checks that the primary key is set (if required), all non-nullable fields
  are present, field types match, and vector dimensions are correct.
  """
  @spec validate(t(), Schema.t()) :: :ok | {:error, Zvex.Error.t()}
  def validate(%__MODULE__{} = doc, %Schema{} = schema) do
    with :ok <- validate_pk(doc, schema),
         :ok <- validate_required_fields(doc, schema),
         :ok <- validate_field_types(doc, schema) do
      validate_dimensions(doc, schema)
    end
  end

  @doc "Converts the document to the internal map format expected by the NIF layer."
  @spec to_native_map(t()) :: map()
  def to_native_map(%__MODULE__{} = doc) do
    fields =
      Enum.map(doc.fields, fn {name, {type, value}} ->
        {name, type, value}
      end)

    %{pk: doc.pk, fields: fields}
  end

  @doc "Reconstructs a document from the internal NIF map format."
  @spec from_native_map(map()) :: t()
  def from_native_map(%{pk: pk, fields: fields}) do
    field_map =
      Map.new(fields, fn {name, type, value} ->
        {name, {type, value}}
      end)

    %__MODULE__{pk: pk, fields: field_map}
  end

  @doc "Converts one or more documents to a list of NIF-ready maps."
  @spec to_native_maps(t() | [t()]) :: [map()]
  def to_native_maps(%__MODULE__{} = doc), do: [to_native_map(doc)]
  def to_native_maps(docs) when is_list(docs), do: Enum.map(docs, &to_native_map/1)

  # -- Serialization ----------------------------------------------------------

  @doc "Serializes the document to a compact binary representation via the native layer."
  @spec serialize(t()) :: {:ok, binary()} | {:error, Zvex.Error.t()}
  def serialize(%__MODULE__{} = doc) do
    doc |> to_native_map() |> Zvex.Native.doc_serialize() |> Zvex.Error.from_native()
  end

  @doc "Like `serialize/1` but raises on error."
  @spec serialize!(t()) :: binary()
  def serialize!(doc), do: serialize(doc) |> Zvex.Error.unwrap!()

  @doc "Deserializes a binary produced by `serialize/1` back into a document."
  @spec deserialize(binary()) :: {:ok, t()} | {:error, Zvex.Error.t()}
  def deserialize(binary) when is_binary(binary) do
    case Zvex.Native.doc_deserialize(binary) |> Zvex.Error.from_native() do
      {:ok, native_map} -> {:ok, from_native_map(native_map)}
      error -> error
    end
  end

  @doc "Like `deserialize/1` but raises on error."
  @spec deserialize!(binary()) :: t()
  def deserialize!(binary), do: deserialize(binary) |> Zvex.Error.unwrap!()

  @doc "Returns the estimated memory usage of the document in bytes."
  @spec memory_usage(t()) :: {:ok, non_neg_integer()} | {:error, Zvex.Error.t()}
  def memory_usage(%__MODULE__{} = doc) do
    doc |> to_native_map() |> Zvex.Native.doc_memory_usage() |> Zvex.Error.from_native()
  end

  @doc "Like `memory_usage/1` but raises on error."
  @spec memory_usage!(t()) :: non_neg_integer()
  def memory_usage!(doc), do: memory_usage(doc) |> Zvex.Error.unwrap!()

  @doc "Returns a human-readable string describing the document's fields and types."
  @spec detail_string(t()) :: {:ok, String.t()} | {:error, Zvex.Error.t()}
  def detail_string(%__MODULE__{} = doc) do
    doc |> to_native_map() |> Zvex.Native.doc_detail_string() |> Zvex.Error.from_native()
  end

  @doc "Like `detail_string/1` but raises on error."
  @spec detail_string!(t()) :: String.t()
  def detail_string!(doc), do: detail_string(doc) |> Zvex.Error.unwrap!()

  # -- Private helpers -------------------------------------------------------

  defp apply_field(doc, key, value, field_def) do
    doc = if field_def.primary_key, do: put_pk(doc, value), else: doc
    coerced = coerce_value(value, field_def.data_type)
    %{doc | fields: Map.put(doc.fields, key, {field_def.data_type, coerced})}
  end

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

defimpl Inspect, for: Zvex.Document do
  import Inspect.Algebra

  @sparse_types [:sparse_vector_fp16, :sparse_vector_fp32]
  @dense_vector_types [
    :vector_fp32,
    :vector_fp16,
    :vector_fp64,
    :vector_int4,
    :vector_int8,
    :vector_int16,
    :vector_binary32,
    :vector_binary64
  ]

  def inspect(%Zvex.Document{pk: pk, fields: fields}, opts) do
    field_docs =
      fields
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.map(fn {name, {type, value}} ->
        annotation = type_annotation(type, value)

        concat([
          color("\"", :string, opts),
          color(name, :string, opts),
          color("\"", :string, opts),
          " (",
          annotation,
          ")"
        ])
      end)

    pk_doc =
      if pk,
        do:
          concat([
            "pk: ",
            color("\"", :string, opts),
            color(pk, :string, opts),
            color("\"", :string, opts)
          ]),
        else: "pk: nil"

    fields_doc = container_doc("[", field_docs, "]", opts, fn doc, _opts -> doc end)
    concat(["#Zvex.Document<", pk_doc, ", fields: ", fields_doc, ">"])
  end

  defp type_annotation(type, value) when type in @sparse_types do
    nnz = sparse_nnz(value)
    "#{type}, nnz=#{nnz}"
  end

  defp type_annotation(type, value) when type in @dense_vector_types do
    dim = Zvex.Vector.dimension(%Zvex.Vector{type: type, data: value})
    "#{type}, dim=#{dim}"
  end

  defp type_annotation(type, _value), do: to_string(type)

  defp sparse_nnz(data) when is_binary(data) and byte_size(data) >= 8 do
    <<n::unsigned-little-64, _rest::binary>> = data
    n
  end

  defp sparse_nnz(_), do: 0
end
