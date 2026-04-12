defmodule Zvex.Error.Unavailable do
  use Splode.ErrorClass, class: :unavailable

  defmodule PermissionDenied do
    use Splode.Error, fields: [:message], class: :unavailable

    def message(%{message: message}), do: message
  end

  defmodule ResourceExhausted do
    use Splode.Error, fields: [:message], class: :unavailable

    def message(%{message: message}), do: message
  end

  defmodule Unavailable do
    use Splode.Error, fields: [:message], class: :unavailable

    def message(%{message: message}), do: message
  end

  defmodule NotSupported do
    use Splode.Error, fields: [:message], class: :unavailable

    def message(%{message: message}), do: message
  end
end
