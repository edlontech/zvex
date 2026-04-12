defmodule Zvex.Error.Invalid do
  use Splode.ErrorClass, class: :invalid

  defmodule Argument do
    use Splode.Error, fields: [:message], class: :invalid

    def message(%{message: message}), do: message
  end

  defmodule FailedPrecondition do
    use Splode.Error, fields: [:message], class: :invalid

    def message(%{message: message}), do: message
  end
end
