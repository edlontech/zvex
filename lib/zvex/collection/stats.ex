defmodule Zvex.Collection.Stats do
  @moduledoc """
  Collection statistics returned by `Zvex.Collection.stats/1`.

  ## Fields

  - `:doc_count` — total number of documents in the collection.
  - `:indexes` — list of index status maps, each containing:
    - `:name` — the indexed field name.
    - `:completeness` — a float between `0.0` and `1.0` indicating how
      much of the data has been indexed (reaches `1.0` after `optimize/1`).
  """

  defstruct [:doc_count, indexes: []]

  @typedoc "Collection statistics snapshot."
  @type t :: %__MODULE__{
          doc_count: non_neg_integer(),
          indexes: [%{name: String.t(), completeness: float()}]
        }
end
