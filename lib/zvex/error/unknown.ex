defmodule Zvex.Error.Unknown do
  use Splode.ErrorClass, class: :unknown

  defmodule Unknown do
    use Splode.Error, fields: [:message], class: :unknown

    def message(%{message: message}) when is_binary(message), do: message
    def message(_), do: "unknown zvec error"
  end
end
