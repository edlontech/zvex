defmodule Zvex.Error.NotFound do
  @moduledoc "Error class for not-found errors."
  use Splode.ErrorClass, class: :not_found

  defmodule NotFound do
    @moduledoc "The requested resource was not found."
    use Splode.Error, fields: [:message], class: :not_found

    def message(%{message: message}), do: message
  end
end
