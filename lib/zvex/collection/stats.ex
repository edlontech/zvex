defmodule Zvex.Collection.Stats do
  @moduledoc """
  Collection statistics returned by `Zvex.Collection.stats/1`.
  """

  defstruct [:doc_count, indexes: []]

  @type t :: %__MODULE__{
          doc_count: non_neg_integer(),
          indexes: [%{name: String.t(), completeness: float()}]
        }
end
