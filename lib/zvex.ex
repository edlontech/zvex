defmodule Zvex do
  @moduledoc """
  Elixir bindings for **zvec**, an in-process vector database.

  Zvex provides a high-level API for creating and managing vector collections,
  inserting typed documents, and performing similarity search queries. All
  heavy operations are backed by NIF calls to the zvec C library.

  This module acts as a convenience facade that delegates to the underlying
  modules. You can use it directly or reach for the individual modules when
  you need finer control:

  | Module | Purpose |
  |---|---|
  | `Zvex.Collection` | Collection lifecycle and CRUD |
  | `Zvex.Collection.Schema` | Schema builder |
  | `Zvex.Document` | Typed document construction |
  | `Zvex.Query` | Fluent vector query builder |
  | `Zvex.Vector` | Vector packing/unpacking |
  | `Zvex.Config` | Library configuration |

  ## Quick Start

      # Initialize the library
      :ok = Zvex.initialize()

      # Define a schema
      schema =
        Zvex.Collection.Schema.new("products")
        |> Zvex.Collection.Schema.add_field("id", :string, primary_key: true)
        |> Zvex.Collection.Schema.add_field("embedding", :vector_fp32,
             dimension: 128,
             index: [type: :hnsw, metric: :cosine])
        |> Zvex.Collection.Schema.add_field("name", :string)

      # Create a collection and insert a document
      {:ok, coll} = Zvex.create("/tmp/products", schema)

      doc =
        Zvex.Document.new()
        |> Zvex.Document.put_pk("prod-1")
        |> Zvex.Document.put("name", "Widget")
        |> Zvex.Document.put("embedding", Zvex.Vector.from_list(List.duplicate(0.1, 128), :fp32))

      {:ok, _} = Zvex.insert(coll, doc)

      # Query nearest neighbors
      query_vec = Zvex.Vector.from_list(List.duplicate(0.1, 128), :fp32)

      {:ok, results} =
        Zvex.Query.new()
        |> Zvex.Query.field("embedding")
        |> Zvex.Query.vector(query_vec)
        |> Zvex.Query.top_k(5)
        |> Zvex.Query.execute(coll)

      :ok = Zvex.close(coll)
      :ok = Zvex.shutdown()

  ## Error Handling

  Every fallible function comes in two flavours:

  - `fun/n` returns `{:ok, result}` or `{:error, %Zvex.Error{}}`.
  - `fun!/n` returns the unwrapped result or raises.

  See `Zvex.Error` for the full error hierarchy.
  """

  @doc """
  Returns the zvec library version.

  ## Examples

      iex> version = Zvex.version()
      iex> is_integer(version.major) and is_integer(version.minor) and is_integer(version.patch)
      true
  """
  def version do
    %{
      major: Zvex.Native.version_major(),
      minor: Zvex.Native.version_minor(),
      patch: Zvex.Native.version_patch(),
      raw: Zvex.Native.version()
    }
  end

  @doc "Initializes the zvec library with default configuration."
  def initialize do
    Zvex.Native.initialize()
    |> Zvex.Error.from_native()
  end

  @doc "Initializes the zvec library with the given configuration."
  def initialize(%Zvex.Config{} = config) do
    with {:ok, _validated} <- Zvex.Config.validate(config) do
      config
      |> Zvex.Config.to_native_map()
      |> Zvex.Native.initialize_with_config()
      |> Zvex.Error.from_native()
    end
  end

  @doc "Initializes the zvec library. Raises on error."
  def initialize! do
    initialize() |> Zvex.Error.unwrap!()
  end

  @doc "Initializes the zvec library with the given configuration. Raises on error."
  def initialize!(%Zvex.Config{} = config) do
    initialize(config) |> Zvex.Error.unwrap!()
  end

  @doc "Shuts down the zvec library."
  def shutdown do
    Zvex.Native.shutdown() |> Zvex.Error.from_native()
  end

  @doc "Shuts down the zvec library. Raises on error."
  def shutdown! do
    shutdown() |> Zvex.Error.unwrap!()
  end

  @doc "Returns whether the zvec library is initialized."
  def initialized? do
    Zvex.Native.is_initialized()
  end

  @doc """
  Checks if the linked zvec library is compatible with the given version.

  Returns `true` if the library version is >= the requested version.

  ## Examples

      iex> Zvex.compatible?(0, 0, 1)
      true
  """
  @spec compatible?(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: boolean()
  def compatible?(major, minor, patch)
      when is_integer(major) and is_integer(minor) and is_integer(patch) do
    Zvex.Native.check_version(major, minor, patch)
  end

  # -- Collection lifecycle --------------------------------------------------

  @doc "Creates a new collection at `path` with the given `schema`. See `Zvex.Collection.create/3`."
  def create(path, schema), do: Zvex.Collection.create(path, schema)
  defdelegate create(path, schema, opts), to: Zvex.Collection

  @doc "Like `create/2` but raises on error. See `Zvex.Collection.create!/3`."
  def create!(path, schema), do: Zvex.Collection.create!(path, schema)
  defdelegate create!(path, schema, opts), to: Zvex.Collection

  @doc "Opens an existing collection from `path`. See `Zvex.Collection.open/2`."
  def open(path), do: Zvex.Collection.open(path)
  defdelegate open(path, opts), to: Zvex.Collection

  @doc "Like `open/1` but raises on error. See `Zvex.Collection.open!/2`."
  def open!(path), do: Zvex.Collection.open!(path)
  defdelegate open!(path, opts), to: Zvex.Collection

  defdelegate close(collection), to: Zvex.Collection
  defdelegate close!(collection), to: Zvex.Collection
  defdelegate drop(collection), to: Zvex.Collection
  defdelegate drop!(collection), to: Zvex.Collection
  defdelegate flush(collection), to: Zvex.Collection
  defdelegate flush!(collection), to: Zvex.Collection
  defdelegate optimize(collection), to: Zvex.Collection
  defdelegate optimize!(collection), to: Zvex.Collection
  defdelegate stats(collection), to: Zvex.Collection
  defdelegate stats!(collection), to: Zvex.Collection
  defdelegate schema(collection), to: Zvex.Collection
  defdelegate schema!(collection), to: Zvex.Collection

  # -- Options introspection -------------------------------------------------

  defdelegate options(collection), to: Zvex.Collection
  defdelegate options!(collection), to: Zvex.Collection

  # -- Schema introspection -------------------------------------------------

  defdelegate has_field?(collection, field_name), to: Zvex.Collection
  defdelegate has_index?(collection, field_name), to: Zvex.Collection

  @doc "Lists field names in the collection. See `Zvex.Collection.field_names/2`."
  def field_names(collection), do: Zvex.Collection.field_names(collection)
  defdelegate field_names(collection, category), to: Zvex.Collection

  @doc "Like `field_names/1` but raises on error. See `Zvex.Collection.field_names!/2`."
  def field_names!(collection), do: Zvex.Collection.field_names!(collection)
  defdelegate field_names!(collection, category), to: Zvex.Collection

  # -- Index management (DDL) ------------------------------------------------

  defdelegate create_index(collection, field_name, opts), to: Zvex.Collection
  defdelegate create_index!(collection, field_name, opts), to: Zvex.Collection
  defdelegate drop_index(collection, field_name), to: Zvex.Collection
  defdelegate drop_index!(collection, field_name), to: Zvex.Collection

  # -- Column management (DDL) -----------------------------------------------

  @doc "Adds a new column to the collection. See `Zvex.Collection.add_column/4`."
  def add_column(collection, name, data_type),
    do: Zvex.Collection.add_column(collection, name, data_type)

  defdelegate add_column(collection, name, data_type, opts), to: Zvex.Collection

  @doc "Like `add_column/3` but raises on error. See `Zvex.Collection.add_column!/4`."
  def add_column!(collection, name, data_type),
    do: Zvex.Collection.add_column!(collection, name, data_type)

  defdelegate add_column!(collection, name, data_type, opts), to: Zvex.Collection
  defdelegate drop_column(collection, column_name), to: Zvex.Collection
  defdelegate drop_column!(collection, column_name), to: Zvex.Collection
  defdelegate alter_column(collection, column_name, opts), to: Zvex.Collection
  defdelegate alter_column!(collection, column_name, opts), to: Zvex.Collection

  # -- CRUD ------------------------------------------------------------------

  defdelegate insert(collection, doc_or_docs), to: Zvex.Collection
  defdelegate insert!(collection, doc_or_docs), to: Zvex.Collection
  defdelegate insert_with_results(collection, doc_or_docs), to: Zvex.Collection
  defdelegate insert_with_results!(collection, doc_or_docs), to: Zvex.Collection
  defdelegate update(collection, doc_or_docs), to: Zvex.Collection
  defdelegate update!(collection, doc_or_docs), to: Zvex.Collection
  defdelegate update_with_results(collection, doc_or_docs), to: Zvex.Collection
  defdelegate update_with_results!(collection, doc_or_docs), to: Zvex.Collection
  defdelegate upsert(collection, doc_or_docs), to: Zvex.Collection
  defdelegate upsert!(collection, doc_or_docs), to: Zvex.Collection
  defdelegate upsert_with_results(collection, doc_or_docs), to: Zvex.Collection
  defdelegate upsert_with_results!(collection, doc_or_docs), to: Zvex.Collection
  defdelegate delete(collection, primary_keys), to: Zvex.Collection
  defdelegate delete!(collection, primary_keys), to: Zvex.Collection
  defdelegate delete_with_results(collection, primary_keys), to: Zvex.Collection
  defdelegate delete_with_results!(collection, primary_keys), to: Zvex.Collection
  defdelegate delete_by_filter(collection, filter), to: Zvex.Collection
  defdelegate delete_by_filter!(collection, filter), to: Zvex.Collection
  defdelegate fetch(collection, primary_keys), to: Zvex.Collection
  defdelegate fetch!(collection, primary_keys), to: Zvex.Collection

  # -- Query -----------------------------------------------------------------

  defdelegate execute(query, collection), to: Zvex.Query
  defdelegate execute!(query, collection), to: Zvex.Query
end
