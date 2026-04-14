defmodule Zvex do
  @moduledoc """
  Elixir bindings for zvec, an in-process vector database.
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

  # -- Collection lifecycle --------------------------------------------------

  def create(path, schema), do: Zvex.Collection.create(path, schema)
  defdelegate create(path, schema, opts), to: Zvex.Collection

  def create!(path, schema), do: Zvex.Collection.create!(path, schema)
  defdelegate create!(path, schema, opts), to: Zvex.Collection

  def open(path), do: Zvex.Collection.open(path)
  defdelegate open(path, opts), to: Zvex.Collection

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

  def field_names(collection), do: Zvex.Collection.field_names(collection)
  defdelegate field_names(collection, category), to: Zvex.Collection

  def field_names!(collection), do: Zvex.Collection.field_names!(collection)
  defdelegate field_names!(collection, category), to: Zvex.Collection

  # -- Index management (DDL) ------------------------------------------------

  defdelegate create_index(collection, field_name, opts), to: Zvex.Collection
  defdelegate create_index!(collection, field_name, opts), to: Zvex.Collection
  defdelegate drop_index(collection, field_name), to: Zvex.Collection
  defdelegate drop_index!(collection, field_name), to: Zvex.Collection

  # -- Column management (DDL) -----------------------------------------------

  def add_column(collection, name, data_type),
    do: Zvex.Collection.add_column(collection, name, data_type)

  defdelegate add_column(collection, name, data_type, opts), to: Zvex.Collection

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
