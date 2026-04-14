defmodule Zvex do
  @moduledoc """
  Elixir bindings for **zvec**, an in-process vector database.

  This module manages the zvec library lifecycle: initialization,
  shutdown, and version introspection. For collection operations, use
  the dedicated modules:

  | Module | Purpose |
  |---|---|
  | `Zvex.Collection` | Collection lifecycle and CRUD |
  | `Zvex.Collection.Schema` | Schema builder |
  | `Zvex.Document` | Typed document construction |
  | `Zvex.Query` | Fluent vector query builder |
  | `Zvex.Vector` | Vector packing/unpacking |
  | `Zvex.Config` | Library configuration |

  ## Quick Start

      alias Zvex.{Collection, Document, Query, Vector}
      alias Zvex.Collection.Schema

      # Initialize the library
      :ok = Zvex.initialize()

      # Define a schema
      schema =
        Schema.new("products")
        |> Schema.add_field("id", :string, primary_key: true)
        |> Schema.add_field("embedding", :vector_fp32,
             dimension: 128,
             index: [type: :hnsw, metric: :cosine])
        |> Schema.add_field("name", :string)

      # Create a collection and insert a document
      {:ok, coll} = Collection.create("/tmp/products", schema)

      doc =
        Document.new()
        |> Document.put_pk("prod-1")
        |> Document.put("name", "Widget")
        |> Document.put("embedding", Vector.from_list(List.duplicate(0.1, 128), :fp32))

      {:ok, _} = Collection.insert(coll, doc)

      # Query nearest neighbors
      query_vec = Vector.from_list(List.duplicate(0.1, 128), :fp32)

      {:ok, results} =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector(query_vec)
        |> Query.top_k(5)
        |> Query.execute(coll)

      :ok = Collection.close(coll)
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
end
