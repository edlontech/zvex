defmodule Zvex.Error.NotFound do
  use Splode.ErrorClass, class: :not_found

  defmodule NotFound do
    use Splode.Error, fields: [:message], class: :not_found

    def message(%{message: message}), do: message
  end
end
