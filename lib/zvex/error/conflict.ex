defmodule Zvex.Error.Conflict do
  @moduledoc "Error class for conflict errors."
  use Splode.ErrorClass, class: :conflict

  defmodule AlreadyExists do
    @moduledoc "The resource already exists."
    use Splode.Error, fields: [:message], class: :conflict

    def message(%{message: message}), do: message
  end
end
