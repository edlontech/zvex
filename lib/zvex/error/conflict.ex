defmodule Zvex.Error.Conflict do
  use Splode.ErrorClass, class: :conflict

  defmodule AlreadyExists do
    use Splode.Error, fields: [:message], class: :conflict

    def message(%{message: message}), do: message
  end
end
