defmodule Zvex.Collection do
  @moduledoc """
  Collection lifecycle management for zvec.

  A collection is the fundamental storage unit — it holds typed documents
  organized by a `Zvex.Collection.Schema`. Once created and opened, you can
  insert, update, upsert, delete, and fetch documents, as well as manage
  indexes and columns at runtime.

  Every function that can fail returns `{:ok, result} | {:error, Zvex.Error.t()}`
  and has a bang (`!`) variant that unwraps or raises.

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

  @typedoc """
  An open collection handle.

  - `:ref` — opaque NIF resource reference to the underlying zvec collection.
  - `:path` — filesystem path where the collection data is stored.
  - `:closed` — whether `close/1` has been called on this handle.
  """
  @type t :: %__MODULE__{
          ref: reference(),
          path: String.t(),
          closed: boolean()
        }

  @doc """
  Creates a new collection on disk and opens it.

  The `schema` is validated before being sent to the native layer. `opts` are
  forwarded as collection-level options (e.g. segment configuration).

  Returns `{:ok, collection}` on success.
  """
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

  @doc "Like `create/3` but raises on error."
  @spec create!(String.t(), Schema.t(), keyword()) :: t()
  def create!(path, schema, opts \\ []) do
    create(path, schema, opts)
    |> Zvex.Error.unwrap!()
  end

  @doc """
  Opens an existing collection from `path`.

  The collection must have been previously created with `create/3`. Accepts
  the same `opts` as `create/3` for overriding collection-level options.
  """
  @spec open(String.t(), keyword()) :: {:ok, t()} | {:error, Zvex.Error.t()}
  def open(path, opts \\ []) do
    opts_map = Map.new(opts)

    case Zvex.Native.collection_open(path, opts_map) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, path: path}}
      {:error, _} = err -> Zvex.Error.from_native(err)
    end
  end

  @doc "Like `open/2` but raises on error."
  @spec open!(String.t(), keyword()) :: t()
  def open!(path, opts \\ []) do
    open(path, opts)
    |> Zvex.Error.unwrap!()
  end

  @doc """
  Closes the collection, releasing its native resources.

  After closing, all operations on this handle will return an error.
  """
  @spec close(t()) :: :ok | {:error, Zvex.Error.t()}
  def close(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      Zvex.Native.collection_close(collection.ref)
      |> Zvex.Error.from_native()
    end
  end

  @doc "Like `close/1` but raises on error."
  @spec close!(t()) :: :ok
  def close!(%__MODULE__{} = collection) do
    close(collection)
    |> Zvex.Error.unwrap!()
  end

  @doc """
  Closes the collection (if open) and deletes its data directory from disk.

  This is a destructive, irreversible operation.
  """
  @spec drop(t()) :: :ok | {:error, Zvex.Error.t()}
  def drop(%__MODULE__{} = collection) do
    unless collection.closed do
      close(collection)
    end

    File.rm_rf!(collection.path)
    :ok
  end

  @doc "Like `drop/1` but raises on error."
  @spec drop!(t()) :: :ok
  def drop!(%__MODULE__{} = collection) do
    drop(collection)
    |> Zvex.Error.unwrap!()
  end

  @doc "Flushes buffered writes to persistent storage."
  @spec flush(t()) :: :ok | {:error, Zvex.Error.t()}
  def flush(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      Zvex.Native.collection_flush(collection.ref)
      |> Zvex.Error.from_native()
    end
  end

  @doc "Like `flush/1` but raises on error."
  @spec flush!(t()) :: :ok
  def flush!(%__MODULE__{} = collection) do
    flush(collection)
    |> Zvex.Error.unwrap!()
  end

  @doc """
  Triggers index optimization on the collection.

  This merges segments and rebuilds indexes for better query performance.
  Can be a long-running operation on large collections.
  """
  @spec optimize(t()) :: :ok | {:error, Zvex.Error.t()}
  def optimize(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      Zvex.Native.collection_optimize(collection.ref)
      |> Zvex.Error.from_native()
    end
  end

  @doc "Like `optimize/1` but raises on error."
  @spec optimize!(t()) :: :ok
  def optimize!(%__MODULE__{} = collection) do
    optimize(collection)
    |> Zvex.Error.unwrap!()
  end

  @doc "Returns a `Zvex.Collection.Stats` struct with the document count and index information."
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

  @doc "Like `stats/1` but raises on error."
  @spec stats!(t()) :: Stats.t()
  def stats!(%__MODULE__{} = collection) do
    stats(collection)
    |> Zvex.Error.unwrap!()
  end

  @doc "Returns the `Zvex.Collection.Schema` of the open collection."
  @spec schema(t()) :: {:ok, Schema.t()} | {:error, Zvex.Error.t()}
  def schema(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_get_schema(collection.ref) do
        {:ok, schema_map} -> {:ok, native_map_to_schema(schema_map)}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `schema/1` but raises on error."
  @spec schema!(t()) :: Schema.t()
  def schema!(%__MODULE__{} = collection) do
    schema(collection)
    |> Zvex.Error.unwrap!()
  end

  # -- Options introspection ---------------------------------------------------

  @doc "Returns the collection-level options as a map."
  @spec options(t()) :: {:ok, map()} | {:error, Zvex.Error.t()}
  def options(%__MODULE__{} = collection) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_get_options(collection.ref) do
        {:ok, opts_map} -> {:ok, opts_map}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `options/1` but raises on error."
  @spec options!(t()) :: map()
  def options!(%__MODULE__{} = collection) do
    options(collection) |> Zvex.Error.unwrap!()
  end

  # -- Schema introspection ---------------------------------------------------

  @doc "Returns `true` if the collection schema contains a field named `field_name`."
  @spec has_field?(t(), String.t()) :: boolean()
  def has_field?(%__MODULE__{} = collection, field_name) when is_binary(field_name) do
    case Zvex.Native.collection_has_field(collection.ref, field_name) do
      {:ok, result} -> result
      _ -> false
    end
  end

  @doc "Returns `true` if the field `field_name` has an index."
  @spec has_index?(t(), String.t()) :: boolean()
  def has_index?(%__MODULE__{} = collection, field_name) when is_binary(field_name) do
    case Zvex.Native.collection_has_index(collection.ref, field_name) do
      {:ok, result} -> result
      _ -> false
    end
  end

  @doc "Returns the names of all fields. Shorthand for `field_names(collection, :all)`."
  @spec field_names(t()) :: {:ok, [String.t()]} | {:error, Zvex.Error.t()}
  def field_names(%__MODULE__{} = collection) do
    field_names(collection, :all)
  end

  @doc """
  Returns the names of fields matching `category`.

  Categories:
  - `:all` — every field in the schema
  - `:forward` — scalar/forward-stored fields
  - `:vector` — vector fields (dense and sparse)
  - `:indexed` — fields that have an index
  """
  @spec field_names(t(), :all | :forward | :vector | :indexed) ::
          {:ok, [String.t()]} | {:error, Zvex.Error.t()}
  def field_names(%__MODULE__{} = collection, category)
      when category in [:all, :forward, :vector, :indexed] do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_field_names(collection.ref, category) do
        {:ok, names} -> {:ok, names}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `field_names/1` but raises on error."
  @spec field_names!(t()) :: [String.t()]
  def field_names!(%__MODULE__{} = collection) do
    field_names(collection) |> Zvex.Error.unwrap!()
  end

  @doc "Like `field_names/2` but raises on error."
  @spec field_names!(t(), :all | :forward | :vector | :indexed) :: [String.t()]
  def field_names!(%__MODULE__{} = collection, category) do
    field_names(collection, category) |> Zvex.Error.unwrap!()
  end

  # -- Index management (DDL) -------------------------------------------------

  @doc """
  Creates an index on `field_name`.

  `opts` are index-specific parameters (e.g. `type`, `metric`, `m`,
  `ef_construction`). See `Zvex.Collection.Schema.IndexParams` for the
  full list of supported options.
  """
  @spec create_index(t(), String.t(), keyword()) :: :ok | {:error, Zvex.Error.t()}
  def create_index(%__MODULE__{} = collection, field_name, opts)
      when is_binary(field_name) and is_list(opts) do
    with :ok <- check_open(collection) do
      index_map = Map.new(opts)

      case Zvex.Native.collection_create_index(collection.ref, field_name, index_map) do
        :ok -> :ok
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `create_index/3` but raises on error."
  @spec create_index!(t(), String.t(), keyword()) :: :ok
  def create_index!(collection, field_name, opts) do
    create_index(collection, field_name, opts) |> Zvex.Error.unwrap!()
  end

  @doc "Removes the index from `field_name`."
  @spec drop_index(t(), String.t()) :: :ok | {:error, Zvex.Error.t()}
  def drop_index(%__MODULE__{} = collection, field_name) when is_binary(field_name) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_drop_index(collection.ref, field_name) do
        :ok -> :ok
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `drop_index/2` but raises on error."
  @spec drop_index!(t(), String.t()) :: :ok
  def drop_index!(collection, field_name) do
    drop_index(collection, field_name) |> Zvex.Error.unwrap!()
  end

  # -- Column management (DDL) ------------------------------------------------

  @doc """
  Adds a new column to the collection schema at runtime.

  ## Options

  - `:nullable` — whether the column allows null values (default `false`)
  - `:dimension` — vector dimension, required for vector types (default `0`)
  - `:index` — keyword list of index parameters (e.g. `[type: :invert]`)
  - `:default` — default expression string applied to existing documents
  """
  @spec add_column(t(), String.t(), atom(), keyword()) :: :ok | {:error, Zvex.Error.t()}
  def add_column(%__MODULE__{} = collection, name, data_type, opts \\ [])
      when is_binary(name) and is_atom(data_type) do
    with :ok <- check_open(collection) do
      field_map = %{
        name: name,
        data_type: data_type,
        nullable: Keyword.get(opts, :nullable, false),
        dimension: Keyword.get(opts, :dimension, 0)
      }

      field_map =
        case Keyword.get(opts, :index) do
          nil -> field_map
          idx_opts when is_list(idx_opts) -> Map.put(field_map, :index, Map.new(idx_opts))
        end

      expression = Keyword.get(opts, :default)

      case Zvex.Native.collection_add_column(collection.ref, field_map, expression) do
        :ok -> :ok
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `add_column/4` but raises on error."
  @spec add_column!(t(), String.t(), atom(), keyword()) :: :ok
  def add_column!(collection, name, data_type, opts \\ []) do
    add_column(collection, name, data_type, opts) |> Zvex.Error.unwrap!()
  end

  @doc "Removes a column from the collection schema. Existing data for this column is discarded."
  @spec drop_column(t(), String.t()) :: :ok | {:error, Zvex.Error.t()}
  def drop_column(%__MODULE__{} = collection, column_name) when is_binary(column_name) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_drop_column(collection.ref, column_name) do
        :ok -> :ok
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `drop_column/2` but raises on error."
  @spec drop_column!(t(), String.t()) :: :ok
  def drop_column!(collection, column_name) do
    drop_column(collection, column_name) |> Zvex.Error.unwrap!()
  end

  @doc """
  Alters an existing column.

  ## Options

  - `:new_name` — rename the column
  - `:schema` — keyword list with the new field definition (`:name`, `:data_type`,
    `:nullable`, `:dimension`)
  """
  @spec alter_column(t(), String.t(), keyword()) :: :ok | {:error, Zvex.Error.t()}
  def alter_column(%__MODULE__{} = collection, column_name, opts)
      when is_binary(column_name) and is_list(opts) do
    with :ok <- check_open(collection) do
      new_name = Keyword.get(opts, :new_name)

      new_schema =
        case Keyword.get(opts, :schema) do
          nil ->
            nil

          schema_opts when is_list(schema_opts) ->
            %{
              name: Keyword.get(schema_opts, :name, column_name),
              data_type: Keyword.fetch!(schema_opts, :data_type),
              nullable: Keyword.get(schema_opts, :nullable, false),
              dimension: Keyword.get(schema_opts, :dimension, 0)
            }
        end

      case Zvex.Native.collection_alter_column(collection.ref, column_name, new_name, new_schema) do
        :ok -> :ok
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `alter_column/3` but raises on error."
  @spec alter_column!(t(), String.t(), keyword()) :: :ok
  def alter_column!(collection, column_name, opts) do
    alter_column(collection, column_name, opts) |> Zvex.Error.unwrap!()
  end

  # -- CRUD operations --------------------------------------------------------

  @doc """
  Inserts one or more documents into the collection.

  Accepts a single `Zvex.Document` or a list. Returns a summary map with
  `:success` and `:errors` counts. Documents whose primary key already exists
  will be counted as errors.
  """
  @spec insert(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, Zvex.Error.t()}
  def insert(%__MODULE__{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = Zvex.Document.to_native_maps(doc_or_docs)

      case Zvex.Native.collection_insert(collection.ref, native_maps) do
        {:ok, {success, errors}} -> {:ok, %{success: success, errors: errors}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `insert/2` but raises on error."
  @spec insert!(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          %{success: non_neg_integer(), errors: non_neg_integer()}
  def insert!(collection, doc_or_docs) do
    insert(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @doc """
  Inserts documents and returns per-document result details.

  Unlike `insert/2` which returns aggregate counts, this returns a list of
  result maps — one per document — with individual status information.
  """
  @spec insert_with_results(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          {:ok, [map()]} | {:error, Zvex.Error.t()}
  def insert_with_results(%__MODULE__{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = Zvex.Document.to_native_maps(doc_or_docs)

      Zvex.Native.collection_insert_with_results(collection.ref, native_maps)
      |> Zvex.Error.from_native()
    end
  end

  @doc "Like `insert_with_results/2` but raises on error."
  @spec insert_with_results!(t(), Zvex.Document.t() | [Zvex.Document.t()]) :: [map()]
  def insert_with_results!(collection, doc_or_docs) do
    insert_with_results(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @doc """
  Updates existing documents in the collection.

  Documents are matched by primary key. Returns a summary with `:success`
  and `:errors` counts. Documents whose primary key does not exist will be
  counted as errors.
  """
  @spec update(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, Zvex.Error.t()}
  def update(%__MODULE__{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = Zvex.Document.to_native_maps(doc_or_docs)

      case Zvex.Native.collection_update(collection.ref, native_maps) do
        {:ok, {success, errors}} -> {:ok, %{success: success, errors: errors}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `update/2` but raises on error."
  @spec update!(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          %{success: non_neg_integer(), errors: non_neg_integer()}
  def update!(collection, doc_or_docs) do
    update(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @doc "Updates documents and returns per-document result details. See `insert_with_results/2`."
  @spec update_with_results(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          {:ok, [map()]} | {:error, Zvex.Error.t()}
  def update_with_results(%__MODULE__{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = Zvex.Document.to_native_maps(doc_or_docs)

      Zvex.Native.collection_update_with_results(collection.ref, native_maps)
      |> Zvex.Error.from_native()
    end
  end

  @doc "Like `update_with_results/2` but raises on error."
  @spec update_with_results!(t(), Zvex.Document.t() | [Zvex.Document.t()]) :: [map()]
  def update_with_results!(collection, doc_or_docs) do
    update_with_results(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @doc """
  Inserts or updates documents, depending on whether their primary key exists.

  Combines the semantics of `insert/2` and `update/2`. Returns a summary
  with `:success` and `:errors` counts.
  """
  @spec upsert(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, Zvex.Error.t()}
  def upsert(%__MODULE__{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = Zvex.Document.to_native_maps(doc_or_docs)

      case Zvex.Native.collection_upsert(collection.ref, native_maps) do
        {:ok, {success, errors}} -> {:ok, %{success: success, errors: errors}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `upsert/2` but raises on error."
  @spec upsert!(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          %{success: non_neg_integer(), errors: non_neg_integer()}
  def upsert!(collection, doc_or_docs) do
    upsert(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @doc "Upserts documents and returns per-document result details. See `insert_with_results/2`."
  @spec upsert_with_results(t(), Zvex.Document.t() | [Zvex.Document.t()]) ::
          {:ok, [map()]} | {:error, Zvex.Error.t()}
  def upsert_with_results(%__MODULE__{} = collection, doc_or_docs) do
    with :ok <- check_open(collection) do
      native_maps = Zvex.Document.to_native_maps(doc_or_docs)

      Zvex.Native.collection_upsert_with_results(collection.ref, native_maps)
      |> Zvex.Error.from_native()
    end
  end

  @doc "Like `upsert_with_results/2` but raises on error."
  @spec upsert_with_results!(t(), Zvex.Document.t() | [Zvex.Document.t()]) :: [map()]
  def upsert_with_results!(collection, doc_or_docs) do
    upsert_with_results(collection, doc_or_docs) |> Zvex.Error.unwrap!()
  end

  @doc """
  Deletes documents by their primary keys.

  Returns a summary with `:success` and `:errors` counts.
  """
  @spec delete(t(), [String.t()]) ::
          {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
          | {:error, Zvex.Error.t()}
  def delete(%__MODULE__{} = collection, primary_keys) when is_list(primary_keys) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_delete(collection.ref, primary_keys) do
        {:ok, {success, errors}} -> {:ok, %{success: success, errors: errors}}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `delete/2` but raises on error."
  @spec delete!(t(), [String.t()]) ::
          %{success: non_neg_integer(), errors: non_neg_integer()}
  def delete!(collection, primary_keys) do
    delete(collection, primary_keys) |> Zvex.Error.unwrap!()
  end

  @doc "Deletes documents and returns per-document result details. See `insert_with_results/2`."
  @spec delete_with_results(t(), [String.t()]) ::
          {:ok, [map()]} | {:error, Zvex.Error.t()}
  def delete_with_results(%__MODULE__{} = collection, primary_keys) when is_list(primary_keys) do
    with :ok <- check_open(collection) do
      Zvex.Native.collection_delete_with_results(collection.ref, primary_keys)
      |> Zvex.Error.from_native()
    end
  end

  @doc "Like `delete_with_results/2` but raises on error."
  @spec delete_with_results!(t(), [String.t()]) :: [map()]
  def delete_with_results!(collection, primary_keys) do
    delete_with_results(collection, primary_keys) |> Zvex.Error.unwrap!()
  end

  @doc """
  Deletes all documents matching a filter expression.

  The `filter` is a zvec filter expression string (same syntax as
  `Zvex.Query.filter/2`).
  """
  @spec delete_by_filter(t(), String.t()) :: :ok | {:error, Zvex.Error.t()}
  def delete_by_filter(%__MODULE__{} = collection, filter) when is_binary(filter) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_delete_by_filter(collection.ref, filter) do
        :ok -> :ok
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `delete_by_filter/2` but raises on error."
  @spec delete_by_filter!(t(), String.t()) :: :ok
  def delete_by_filter!(collection, filter) do
    delete_by_filter(collection, filter) |> Zvex.Error.unwrap!()
  end

  @doc """
  Fetches documents by their primary keys.

  Returns a list of `Zvex.Document` structs in the same order as the requested
  keys. Missing keys are silently skipped.
  """
  @spec fetch(t(), [String.t()]) :: {:ok, [Zvex.Document.t()]} | {:error, Zvex.Error.t()}
  def fetch(%__MODULE__{} = collection, primary_keys) when is_list(primary_keys) do
    with :ok <- check_open(collection) do
      case Zvex.Native.collection_fetch(collection.ref, primary_keys) do
        {:ok, native_docs} -> {:ok, Enum.map(native_docs, &Zvex.Document.from_native_map/1)}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `fetch/2` but raises on error."
  @spec fetch!(t(), [String.t()]) :: [Zvex.Document.t()]
  def fetch!(collection, primary_keys) do
    fetch(collection, primary_keys) |> Zvex.Error.unwrap!()
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
