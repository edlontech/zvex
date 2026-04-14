defmodule Zvex.Query do
  @moduledoc """
  Fluent builder for zvec vector queries.

  ## Example

      alias Zvex.Query
      alias Zvex.Vector

      vec = Vector.from_list([0.1, 0.2, 0.3, 0.4], :fp32)

      Query.new()
      |> Query.field("embedding")
      |> Query.vector(vec)
      |> Query.top_k(5)
      |> Query.hnsw(ef: 100)
      |> Query.execute(collection)
      # {:ok, [%Zvex.Query.Result{pk: _, score: _, doc_id: _, fields: %{}}]}
  """

  alias Zvex.Vector

  defstruct field: nil,
            vector: nil,
            top_k: 10,
            filter: nil,
            output_fields: [],
            include_vector: false,
            include_doc_id: false,
            params: nil

  @typedoc "A vector similarity search query built with the fluent API."
  @type t :: %__MODULE__{
          field: String.t() | nil,
          vector: binary() | nil,
          top_k: pos_integer(),
          filter: String.t() | nil,
          output_fields: [String.t()],
          include_vector: boolean(),
          include_doc_id: boolean(),
          params: nil | {:hnsw, keyword()} | {:ivf, keyword()} | {:flat, keyword()}
        }

  @doc "Creates a new query with default values (`top_k: 10`, no filter, no output fields)."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Sets the vector field to search against. Required before executing."
  @spec field(t(), String.t()) :: t()
  def field(%__MODULE__{} = query, name) when is_binary(name) do
    %{query | field: name}
  end

  @sparse_types [:sparse_vector_fp16, :sparse_vector_fp32]

  @doc """
  Sets the query vector for similarity search. Required before executing.

  Accepts a `Zvex.Vector` struct or a plain list of numbers (auto-converted
  to `:fp32`). Sparse vectors are not supported as query vectors.
  """
  @spec vector(t(), Vector.t() | [number()]) :: t()
  def vector(%__MODULE__{}, %Vector{type: type}) when type in @sparse_types do
    raise ArgumentError,
          "sparse vector types are not supported as query vectors; use a dense type"
  end

  def vector(%__MODULE__{} = query, %Vector{data: data}) do
    %{query | vector: data}
  end

  def vector(%__MODULE__{} = query, list) when is_list(list) do
    vec = Vector.from_list(list, :fp32)
    %{query | vector: vec.data}
  end

  @doc "Sets the maximum number of nearest neighbors to return (default `10`)."
  @spec top_k(t(), pos_integer()) :: t()
  def top_k(%__MODULE__{} = query, k) when is_integer(k) and k > 0 do
    %{query | top_k: k}
  end

  @doc """
  Applies a filter expression to pre-filter candidates before vector search.

  The expression uses zvec's filter syntax (e.g. `"category == 'books'"`).
  """
  @spec filter(t(), String.t()) :: t()
  def filter(%__MODULE__{} = query, expr) when is_binary(expr) do
    %{query | filter: expr}
  end

  @doc "Specifies which scalar fields to include in the results. Defaults to none."
  @spec output_fields(t(), [String.t()]) :: t()
  def output_fields(%__MODULE__{} = query, fields) when is_list(fields) do
    %{query | output_fields: fields}
  end

  @doc "When `true`, includes the matched vector data in each result (default `false`)."
  @spec include_vector(t(), boolean()) :: t()
  def include_vector(%__MODULE__{} = query, bool) when is_boolean(bool) do
    %{query | include_vector: bool}
  end

  @doc "When `true`, includes the internal document ID in each result (default `false`)."
  @spec include_doc_id(t(), boolean()) :: t()
  def include_doc_id(%__MODULE__{} = query, bool) when is_boolean(bool) do
    %{query | include_doc_id: bool}
  end

  @doc """
  Selects HNSW as the search algorithm.

  ## Options

  - `:ef` — search-time expansion factor (higher = better recall, slower search).
  """
  @spec hnsw(t(), keyword()) :: t()
  def hnsw(%__MODULE__{} = query, opts \\ []) do
    %{query | params: {:hnsw, opts}}
  end

  @doc """
  Selects IVF as the search algorithm.

  ## Options

  - `:n_probe` — number of partitions to scan (higher = better recall, slower search).
  """
  @spec ivf(t(), keyword()) :: t()
  def ivf(%__MODULE__{} = query, opts \\ []) do
    %{query | params: {:ivf, opts}}
  end

  @doc "Selects brute-force flat scan. Guarantees exact results at the cost of speed."
  @spec flat(t(), keyword()) :: t()
  def flat(%__MODULE__{} = query, opts \\ []) do
    %{query | params: {:flat, opts}}
  end

  @doc """
  Executes the query against the given collection.

  Both `field/2` and `vector/2` must be set before calling this function.
  Returns a list of `Zvex.Query.Result` structs sorted by score (closest first).
  """
  @spec execute(t(), Zvex.Collection.t()) ::
          {:ok, [Zvex.Query.Result.t()]} | {:error, Zvex.Error.t()}
  def execute(%__MODULE__{} = query, %Zvex.Collection{} = collection) do
    with :ok <- validate(query),
         :ok <- check_collection_open(collection) do
      native_map = to_native_map(query)

      case Zvex.Native.collection_query(collection.ref, native_map) do
        {:ok, results} -> {:ok, Enum.map(results, &from_native_result/1)}
        {:error, _} = err -> Zvex.Error.from_native(err)
      end
    end
  end

  @doc "Like `execute/2` but raises on error."
  @spec execute!(t(), Zvex.Collection.t()) :: [Zvex.Query.Result.t()]
  def execute!(query, collection) do
    execute(query, collection) |> Zvex.Error.unwrap!()
  end

  # -- Private ---------------------------------------------------------------

  defp validate(%__MODULE__{field: nil}) do
    {:error, Zvex.Error.Invalid.Argument.exception(message: "query field must be set")}
  end

  defp validate(%__MODULE__{vector: nil}) do
    {:error, Zvex.Error.Invalid.Argument.exception(message: "query vector must be set")}
  end

  defp validate(%__MODULE__{}), do: :ok

  defp check_collection_open(%Zvex.Collection{closed: true}) do
    {:error, Zvex.Error.Invalid.Argument.exception(message: "collection is closed")}
  end

  defp check_collection_open(%Zvex.Collection{}), do: :ok

  defp to_native_map(%__MODULE__{} = query) do
    %{
      field: query.field,
      vector: query.vector,
      top_k: query.top_k,
      filter: query.filter,
      output_fields: query.output_fields,
      include_vector: query.include_vector,
      include_doc_id: query.include_doc_id,
      params: convert_params(query.params)
    }
  end

  defp convert_params(nil), do: nil
  defp convert_params({type, opts}), do: {type, Map.new(opts)}

  defp from_native_result(%{pk: pk, score: score, doc_id: doc_id, fields: fields}) do
    field_map = Map.new(fields, fn {name, type, value} -> {name, {type, value}} end)
    %Zvex.Query.Result{pk: pk, score: score, doc_id: doc_id, fields: field_map}
  end
end
