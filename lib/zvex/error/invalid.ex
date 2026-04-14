defmodule Zvex.Error.Invalid do
  @moduledoc "Error class for invalid input errors."
  use Splode.ErrorClass, class: :invalid

  defmodule Argument do
    @moduledoc "An argument provided to the operation was invalid."
    use Splode.Error, fields: [:message], class: :invalid

    def message(%{message: message}), do: message
  end

  defmodule FailedPrecondition do
    @moduledoc "A precondition for the operation was not met."
    use Splode.Error, fields: [:message], class: :invalid

    def message(%{message: message}), do: message
  end
end
