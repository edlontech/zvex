defmodule Zvex.Error.Internal do
  use Splode.ErrorClass, class: :internal

  defmodule InternalError do
    use Splode.Error, fields: [:message], class: :internal

    def message(%{message: message}), do: message
  end
end
