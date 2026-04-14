defmodule Zvex.Query.Result do
  @moduledoc """
  A single result returned by `Zvex.Query.execute/2`.

  ## Fields

  - `:pk` — the primary key of the matched document, or `nil` if not available.
  - `:score` — the distance/similarity score (interpretation depends on the metric).
  - `:doc_id` — internal document identifier (only populated when
    `Zvex.Query.include_doc_id/2` is `true`).
  - `:fields` — requested output fields as `%{"name" => {type_atom, value}}`,
    using the same typed-tuple format as `Zvex.Document`.
  """

  defstruct pk: nil, score: 0.0, doc_id: 0, fields: %{}

  @typedoc "A single query result with score and optional field data."
  @type t :: %__MODULE__{
          pk: String.t() | nil,
          score: float(),
          doc_id: non_neg_integer(),
          fields: %{String.t() => {atom(), term()}}
        }
end
