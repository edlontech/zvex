defmodule Zvex.Query.Result do
  @moduledoc """
  Result returned by `Zvex.Query.execute/2`.

  Fields are stored as `%{"field_name" => {type_atom, value}}` — the same
  typed-tuple representation used by `Zvex.Document` internally.
  """

  defstruct pk: nil, score: 0.0, doc_id: 0, fields: %{}

  @type t :: %__MODULE__{
          pk: String.t() | nil,
          score: float(),
          doc_id: non_neg_integer(),
          fields: %{String.t() => {atom(), term()}}
        }
end
