defmodule Zvex.Collection do
  @moduledoc """
  Collection lifecycle management for zvec.

  ## Example

      alias Zvex.Collection
      alias Zvex.Collection.Schema

      schema =
        Schema.new("my_collection")
        |> Schema.add_field("id", :string, primary_key: true)
        |> Schema.add_field("embedding", :vector_fp32,
             dimension: 768,
             index: [type: :hnsw, metric: :cosine])

      {:ok, collection} = Collection.create("/tmp/my_collection", schema)
      {:ok, stats} = Collection.stats(collection)
      :ok = Collection.close(collection)
  """

  alias Zvex.Collection.Schema
  alias Zvex.Collection.Schema.IndexParams
  alias Zvex.Collection.Stats

  defstruct [:ref, :path, closed: false]

  @type t :: %__MODULE__{
          ref: reference(),
          path: String.t(),
          closed: boolean()
        }

  @spec create(String.t(), Schema.t(), keyword()) :: {:ok, t()} | {:error, Zvex.Error.t()}
  def create(path, %Schema{} = schema, opts \\ []) do
    with :ok <- Schema.validate(schema) do
      schema_map = schema_to_native_map(schema)
      opts_map = Map.new(opts)

      case Zvex.Native.collection_create_and_open(path, schema_map, opts_map) do
        {:ok, ref} -> {:ok, %__MODULE__{ref: ref, path: path}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec create!(String.t(), Schema.t(), keyword()) :: t()
  def create!(path, schema, opts \\ []) do
    create(path, schema, opts)
    |> Zvex.Error.unwrap!()
  end

  @spec open(String.t(), keyword()) :: {:ok, t()} | {:error, Zvex.Error.t()}
  def open(path, opts \\ []) do
    opts_map = Map.new(opts)

    case Zvex.Native.collection_open(path, opts_map) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, path: path}}
      {:error, _} = err -> Zvex.Error.from_native(err)
    end
  end

  @spec open!(String.t(), keyword()) :: t()
  def open!(path, opts \\ []) do
    open(path, opts)
    |> Zvex.Error.unwrap!()
  end

  @spec close(t()) :: :ok | {:error, Zvex.Error.t()}
  def close(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      Zvex.Native.collection_close(collection.ref)
      |> Zvex.Error.from_native()
    end
  end

  @spec close!(t()) :: :ok
  def close!(%__MODULE__{} = collection) do
    close(collection)
    |> Zvex.Error.unwrap!()
  end

  @spec drop(t()) :: :ok | {:error, Zvex.Error.t()}
  def drop(%__MODULE__{} = collection) do
    unless collection.closed do
      case close(collection) do
        :ok -> :ok
        {:error, _} -> :ok
      end
    end

    File.rm_rf!(collection.path)
    :ok
  end

  @spec drop!(t()) :: :ok
  def drop!(%__MODULE__{} = collection) do
    drop(collection)
    |> Zvex.Error.unwrap!()
  end

  @spec flush(t()) :: :ok | {:error, Zvex.Error.t()}
  def flush(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      Zvex.Native.collection_flush(collection.ref)
      |> Zvex.Error.from_native()
    end
  end

  @spec flush!(t()) :: :ok
  def flush!(%__MODULE__{} = collection) do
    flush(collection)
    |> Zvex.Error.unwrap!()
  end

  @spec optimize(t()) :: :ok | {:error, Zvex.Error.t()}
  def optimize(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      Zvex.Native.collection_optimize(collection.ref)
      |> Zvex.Error.from_native()
    end
  end

  @spec optimize!(t()) :: :ok
  def optimize!(%__MODULE__{} = collection) do
    optimize(collection)
    |> Zvex.Error.unwrap!()
  end

  @spec stats(t()) :: {:ok, Stats.t()} | {:error, Zvex.Error.t()}
  def stats(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_get_stats(collection.ref) do
        {:ok, stats_map} ->
          {:ok,
           %Stats{
             doc_count: Map.get(stats_map, :doc_count, 0),
             indexes: Map.get(stats_map, :indexes, [])
           }}

        {:error, _} = err ->
          Zvex.Error.from_native(err)
      end
    end
  end

  @spec stats!(t()) :: Stats.t()
  def stats!(%__MODULE__{} = collection) do
    stats(collection)
    |> Zvex.Error.unwrap!()
  end

  @spec schema(t()) :: {:ok, Schema.t()} | {:error, Zvex.Error.t()}
  def schema(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_get_schema(collection.ref) do
        {:ok, schema_map} -> {:ok, native_map_to_schema(schema_map)}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @spec schema!(t()) :: Schema.t()
  def schema!(%__MODULE__{} = collection) do
    schema(collection)
    |> Zvex.Error.unwrap!()
  end

  defp check_open(%__MODULE__{closed: true}),
    do: {:error, Zvex.Error.Invalid.Argument.exception(message: "collection is closed")}

  defp check_open(%__MODULE__{closed: false}), do: :ok

  defp schema_to_native_map(%Schema{} = schema) do
    %{
      name: schema.name,
      max_doc_count_per_segment: schema.max_doc_count_per_segment,
      fields:
        Enum.map(schema.fields, fn field ->
          base = %{
            name: field.name,
            data_type: field.data_type,
            nullable: field.nullable,
            dimension: field.dimension
          }

          case field.index do
            nil -> base
            %IndexParams{} = idx -> Map.put(base, :index, index_params_to_map(idx))
          end
        end)
    }
  end

  defp index_params_to_map(%IndexParams{} = idx) do
    idx
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp native_map_to_schema(schema_map) do
    fields =
      schema_map
      |> Map.get(:fields, [])
      |> Enum.map(fn field_map ->
        index =
          case Map.get(field_map, :index) do
            nil ->
              nil

            idx_map when is_map(idx_map) ->
              %IndexParams{
                type: Map.get(idx_map, :type),
                metric: Map.get(idx_map, :metric),
                quantize: Map.get(idx_map, :quantize),
                m: Map.get(idx_map, :m),
                ef_construction: Map.get(idx_map, :ef_construction),
                n_list: Map.get(idx_map, :n_list),
                n_iters: Map.get(idx_map, :n_iters),
                use_soar: Map.get(idx_map, :use_soar),
                enable_range_opt: Map.get(idx_map, :enable_range_opt),
                enable_wildcard: Map.get(idx_map, :enable_wildcard)
              }
          end

        %{
          name: Map.fetch!(field_map, :name),
          data_type: Map.fetch!(field_map, :data_type),
          primary_key: Map.get(field_map, :primary_key, false),
          nullable: Map.get(field_map, :nullable, false),
          dimension: Map.get(field_map, :dimension, 0),
          index: index
        }
      end)

    %Schema{
      name: Map.get(schema_map, :name),
      fields: fields,
      max_doc_count_per_segment: Map.get(schema_map, :max_doc_count_per_segment)
    }
  end
end
