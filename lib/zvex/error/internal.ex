defmodule Zvex.Error.Internal do
  @moduledoc "Error class for internal/system errors."
  use Splode.ErrorClass, class: :internal

  defmodule InternalError do
    @moduledoc "An unexpected internal error occurred in the native layer."
    use Splode.Error, fields: [:message], class: :internal

    def message(%{message: message}), do: message
  end
end
